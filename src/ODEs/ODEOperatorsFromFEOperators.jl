######################
# ODEOpFromFEOpCache #
######################
"""
    struct ODEOpFromFEOpCache <: GridapType

Structure that stores the `TransientFESpace` and cache of a
`TransientFEOperator`, as well as the jacobian matrices and residual if they
are constant.
"""
mutable struct ODEOpFromFEOpCache <: GridapType
  Us
  Uts
  feopcache
  jac_const_mats
  jacvec
  res_const_vec
end

#################
# ODEOpFromFEOp #
#################
"""
    struct ODEOpFromFEOp <: ODEOperator end

Wrapper that transforms a `TransientFEOperator` into an `ODEOperator`, i.e.
takes `residual(t, uh, ∂t(uh), ..., ∂t^N(uh), vh)` and returns
`residual(t, us)`, where `us[k] = ∂t^k(us)` and `uf` represents the free values
of `uh`.
"""
struct ODEOpFromFEOp{C} <: ODEOperator{C}
  feop::TransientFEOperator{C}
end

# ODEOperator interface
Polynomials.get_order(odeop::ODEOpFromFEOp) = get_order(odeop.feop)

function allocate_odeopcache(
  odeop::ODEOpFromFEOp,
  t::Real, us::Tuple{Vararg{AbstractVector}}
)
  order = get_order(odeop)
  is_masslinear = ODEOperatorType(odeop) <: AbstractMassLinearODE

  Ut = get_trial(odeop.feop)
  U = allocate_space(Ut)
  Uts = (Ut,)
  Us = (U,)
  for k in 1:order
    Uts = (Uts..., ∂t(Uts[k]))
    Us = (Us..., allocate_space(Uts[k+1]))
  end
  feopcache = allocate_feopcache(odeop.feop)

  V = get_test(odeop.feop)
  v = get_fe_basis(V)
  uh = _make_uh_from_us(odeop, us, Us)

  jac_const_mats = ()
  use_jacvec = false
  for k in 0:order
    jac_const_mat = nothing
    if is_jacobian_constant(odeop, k)
      matdata = _matdata_jacobian(odeop.feop, t, uh, k, 1)
      jac_const_mat = assemble_matrix(get_assembler(odeop.feop), matdata)

      use_jacvec = true
    end
    jac_const_mats = (jac_const_mats..., jac_const_mat)
  end

  jacvec = nothing
  if is_masslinear && use_jacvec
    res = get_res(odeop.feop)
    vecdata = collect_cell_vector(V, res(t, uh, v))
    jacvec = allocate_vector(get_assembler(odeop.feop), vecdata)
  end

  res_const_vec = nothing
  if is_masslinear && is_residual_constant(odeop)
    res = get_res(odeop.feop)
    vecdata = collect_cell_vector(V, res(t, uh, v))
    res_const_vec = assemble_vector(get_assembler(odeop.feop), vecdata)
  end

  ODEOpFromFEOpCache(Us, Uts, feopcache, jac_const_mats, jacvec, res_const_vec)
end

function update_odeopcache!(odeopcache, odeop::ODEOpFromFEOp, t::Real)
  Us = ()
  for k in 0:get_order(odeop)
    Us = (Us..., evaluate!(odeopcache.Us[k+1], odeopcache.Uts[k+1], t))
  end
  odeopcache.Us = Us
  odeopcache.feopcache = update_feopcache!(odeopcache.feopcache, odeop.feop, t)
  odeopcache
end

function Algebra.allocate_residual(
  odeop::ODEOpFromFEOp,
  t::Real, us::Tuple{Vararg{AbstractVector}},
  odeopcache
)
  uh = _make_uh_from_us(odeop, us, odeopcache.Us)

  V = get_test(odeop.feop)
  v = get_fe_basis(V)
  res = get_res(odeop.feop)
  vecdata = collect_cell_vector(V, res(t, uh, v))
  allocate_vector(get_assembler(odeop.feop), vecdata)
end

function Algebra.residual!(
  r::AbstractVector, odeop::ODEOpFromFEOp{NonlinearODE},
  t::Real, us::Tuple{Vararg{AbstractVector}},
  odeopcache;
  filter::Tuple{Vararg{Bool}}=ntuple(_ -> true, get_order(odeop) + 2)
)
  uh = _make_uh_from_us(odeop, us, odeopcache.Us)

  V = get_test(odeop.feop)
  v = get_fe_basis(V)
  res = get_res(odeop.feop)
  vecdata = collect_cell_vector(V, res(t, uh, v))
  assemble_vector!(r, get_assembler(odeop.feop), vecdata)
  r
end

function Algebra.residual!(
  r::AbstractVector, odeop::ODEOpFromFEOp{MassLinearODE},
  t::Real, us::Tuple{Vararg{AbstractVector}},
  odeopcache;
  filter::Tuple{Vararg{Bool}}=ntuple(_ -> true, get_order(odeop) + 2)
)
  mass_const = !isnothing(odeopcache.jac_const_mats[end])
  res_const = !isnothing(odeopcache.res_const_vec)
  if !(mass_const && res_const)
    V = get_test(odeop.feop)
    v = get_fe_basis(V)
    uh = _make_uh_from_us(odeop, us, odeopcache.Us)
  end

  fill!(r, zero(eltype(r)))

  if filter[1] || filter[2]
    if res_const
      axpy!(1, odeopcache.res_const_vec, r)
    else
      res = get_res(odeop.feop)
      vecdata = collect_cell_vector(V, res(t, uh, v))
      assemble_vector_add!(r, get_assembler(odeop.feop), vecdata)
    end
  end

  if filter[3]
    if mass_const
      mul!(odeopcache.jacvec, odeopcache.jac_const_mats[end], us[end])
      axpy!(1, odeopcache.jacvec, r)
    else
      mass = get_mass(odeop.feop)
      vecdata = collect_cell_vector(V, mass(t, uh, v))
      assemble_vector_add!(r, get_assembler(odeop.feop), vecdata)
    end
  end
  r
end

function Algebra.residual!(
  r::AbstractVector, odeop::ODEOpFromFEOp{LinearODE},
  t::Real, us::Tuple{Vararg{AbstractVector}},
  odeopcache;
  filter::Tuple{Vararg{Bool}}=ntuple(_ -> true, get_order(odeop) + 2)
)
  forms_const = !any(isnothing, odeopcache.jac_const_mats)
  res_const = !isnothing(odeopcache.res_const_vec)
  if !(forms_const && res_const)
    V = get_test(odeop.feop)
    v = get_fe_basis(V)
    uh = _make_uh_from_us(odeop, us, odeopcache.Us)
  end

  fill!(r, zero(eltype(r)))

  if filter[1]
    if res_const
      axpy!(1, odeopcache.res_const_vec, r)
    else
      res = get_res(odeop.feop)
      vecdata = collect_cell_vector(V, res(t, uh, v))
      assemble_vector_add!(r, get_assembler(odeop.feop), vecdata)
    end
  end

  for k in 0:get_order(odeop)
    !filter[k+2] && continue

    form_const = !isnothing(odeopcache.jac_const_mats[k+1])
    if form_const
      mul!(odeopcache.jacvec, odeopcache.jac_const_mats[k+1], us[k+1])
      axpy!(1, odeopcache.jacvec, r)
    else
      form = get_forms(odeop.feop)[order+1-k]
      vecdata = collect_cell_vector(V, form(t, uh, v))
      assemble_vector_add!(r, get_assembler(odeop.feop), vecdata)
    end
  end

  r
end

function Algebra.allocate_jacobian(
  odeop::ODEOpFromFEOp,
  t::Real, us::Tuple{Vararg{AbstractVector}},
  odeopcache
)
  uh = _make_uh_from_us(odeop, us, odeopcache.Us)

  _matdata = ()
  for k in 0:get_order(odeop.feop)
    _matdata = (_matdata..., _matdata_jacobian(odeop.feop, t, uh, k, 0))
  end

  matdata = _vcat_matdata(_matdata)
  allocate_matrix(get_assembler(odeop.feop), matdata)
end

function Algebra.jacobian!(
  J::AbstractMatrix, odeop::ODEOpFromFEOp,
  t::Real, us::Tuple{Vararg{AbstractVector}},
  k::Integer, γ::Real,
  odeopcache
)
  if !isnothing(odeopcache.jac_const_mats[k+1])
    axpy_sparse!(γ, odeopcache.jac_const_mats[k+1], J)
  else
    uh = _make_uh_from_us(odeop, us, odeopcache.Us)
    matdata = _matdata_jacobian(odeop.feop, t, uh, k, γ)
    assemble_matrix_add!(J, get_assembler(odeop.feop), matdata)
  end

  J
end

function jacobians!(
  J::AbstractMatrix, odeop::ODEOpFromFEOp,
  t::Real, us::Tuple{Vararg{AbstractVector}},
  γs::Tuple{Vararg{Real}},
  odeopcache
)
  need_assembly = any(isnothing, odeopcache.jac_const_mats)
  if need_assembly
    uh = _make_uh_from_us(odeop, us, odeopcache.Us)
  end

  _matdata = ()
  for k in 0:get_order(odeop)
    γ = γs[k+1]
    if !iszero(γ)
      if !isnothing(odeopcache.jac_const_mats[k+1])
        axpy_sparse!(γ, odeopcache.jac_const_mats[k+1], J)
      else
        _matdata = (_matdata..., _matdata_jacobian(odeop.feop, t, uh, k, γ))
      end
    end
  end

  if need_assembly
    matdata = _vcat_matdata(_matdata)
    assemble_matrix_add!(J, get_assembler(odeop.feop), matdata)
  end

  J
end

function is_jacobian_constant(odeop::ODEOpFromFEOp, k::Integer)
  is_jacobian_constant(odeop.feop, k)
end

function is_residual_constant(odeop::ODEOpFromFEOp{<:AbstractMassLinearODE})
  is_residual_constant(odeop.feop)
end

#########
# Utils #
#########
function _matdata_jacobian(
  odeop::TransientFEOperatorTypes,
  t::Real, uh::TransientCellField,
  k::Integer, γ::Real
)
  Ut = evaluate(get_trial(odeop), nothing)
  V = get_test(odeop)
  du = get_trial_fe_basis(Ut)
  v = get_fe_basis(V)
  jac = get_jacs(odeop)[k+1]
  collect_cell_matrix(Ut, V, γ * jac(t, uh, du, v))
end

function _vcat_matdata(_matdata)
  term_to_cellmat_j = ()
  term_to_cellidsrows_j = ()
  term_to_cellidscols_j = ()
  for j in 1:length(_matdata)
    term_to_cellmat_j = (term_to_cellmat_j..., _matdata[j][1])
    term_to_cellidsrows_j = (term_to_cellidsrows_j..., _matdata[j][2])
    term_to_cellidscols_j = (term_to_cellidscols_j..., _matdata[j][3])
  end

  term_to_cellmat = vcat(term_to_cellmat_j...)
  term_to_cellidsrows = vcat(term_to_cellidsrows_j...)
  term_to_cellidscols = vcat(term_to_cellidscols_j...)

  (term_to_cellmat, term_to_cellidsrows, term_to_cellidscols)
end

function _make_uh_from_us(odeop, us, Us)
  u = EvaluationFunction(Us[1], us[1])

  dus = ()
  for k in 1:get_order(odeop)
    dus = (dus..., EvaluationFunction(Us[k+1], us[k+1]))
  end

  if first(Us) isa MultiFieldFESpace
    TransientCellFieldType = TransientMultiFieldCellField
  else
    TransientCellFieldType = TransientCellField
  end
  TransientCellFieldType(u, dus)
end
