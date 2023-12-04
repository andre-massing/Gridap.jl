"""
    abstract type TransientFEOperator <: GridapType end

Transient version of `FEOperator` corresponding to a residual of the form
```math
residual(t, u, v) = 0,
```
where `residual` is linear in `v`. Time derivatives of `u` can be included by
using the `∂t` operator.

# Important
For now, the residual and jacobians cannot be directly computed on a
`TransientFEOperator`. They have to be evaluated on the corresponding algebraic
operator, which is an `ODEOperator`. As such, `TransientFEOperator` is not
exactly a subtype of `FEOperator`, but rather at the intersection of
`FEOperator` and `ODEOperator`.

# Mandatory
- [`get_test(feop)`](@ref)
- [`get_trial(feop)`](@ref)
- [`get_order(feop)`](@ref)
- [`get_assembler(feop)`](@ref)
- [`get_res(feop::TransientFEOperator)`](@ref)
- [`get_jacs(feop::TransientFEOperator)`](@ref)
- [`get_mass(feop::TransientFEOperator{MassLinearODE})`](@ref)
- [`get_forms(feop::TransientFEOperator{LinearODE})`](@ref)

# Optional
- [`allocate_feopcache(feop)`](@ref)
- [`update_feopcache!(feopcache, feop, t)`](@ref)
- [`get_algebraic_operator(feop)`](@ref)
- [`is_jacobian_constant(feop, k)`](@ref)
- [`is_residual_constant(feop)`](@ref)
"""
abstract type TransientFEOperator{C<:ODEOperatorType} <: GridapType end

"""
    ODEOperatorType(::Type{<:TransientFEOperator}) -> ODEOperatorType

Return the `ODEOperatorType` of the `TransientFEOperator`.
"""
ODEOperatorType(feop::TransientFEOperator) = ODEOperatorType(typeof(feop))
ODEOperatorType(::Type{<:TransientFEOperator{C}}) where {C} = C

# FEOperator interface
function FESpaces.get_test(feop::TransientFEOperator)
  @abstractmethod
end

function FESpaces.get_trial(feop::TransientFEOperator)
  @abstractmethod
end

function FESpaces.get_algebraic_operator(feop::TransientFEOperator)
  ODEOpFromFEOp(feop)
end

# ODEOperator interface
function Polynomials.get_order(feop::TransientFEOperator)
  @abstractmethod
end

function is_jacobian_constant(feop::TransientFEOperator, k::Integer)
  false
end

function is_residual_constant(feop::TransientFEOperator)
  false
end

# TransientFEOperator interface
"""
    allocate_feopcache(feop::TransientFEOperator)

Allocate the cache of the `TransientFEOperator`.
"""
function allocate_feopcache(feop::TransientFEOperator)
  nothing
end

"""
    update_feopcache!(feopcache, feop::TransientFEOperator, t::Real)

Update the cache of the `TransientFEOperator` at time `t`.
"""
function update_feopcache!(feopcache, feop::TransientFEOperator, t::Real)
  feopcache
end

"""
    get_assembler(feop::TransientFEOperator) -> Assembler

Return the assembler of the `TransientFEOperator`.
"""
function get_assembler(feop::TransientFEOperator)
  @abstractmethod
end

"""
    get_res(feop::TransientFEOperator) -> Function

Return the residual of the `TransientFEOperator`. By convention, if the
`TransientFEOperator` is a subtype of `AbstractMassLinearODE`, the residual
returned by this function excludes the mass term.
"""
function get_res(feop::TransientFEOperator)
  @abstractmethod
end

"""
    get_jacs(feop::TransientFEOperator) -> Tuple{Vararg{Function}}

Return the jacobians of the `TransientFEOperator`.
"""
function get_jacs(feop::TransientFEOperator)
  @abstractmethod
end

"""
    get_mass(feop::TransientFEOperator{MassLinearODE}) -> Function

Return the mass bilinear form of the `TransientFEOperator`.
"""
function get_mass(feop::TransientFEOperator{MassLinearODE})
  @abstractmethod
end

"""
    get_forms(feop::TransientFEOperator{LinearODE}) -> Function

Return the bilinear forms of the `TransientFEOperator`.
"""
function get_forms(feop::TransientFEOperator{LinearODE})
  @abstractmethod
end

# Broken FESpaces interface
const res_jac_on_transient_feop_msg = """
For now, the residual and jacobians cannot be directly computed on a
`TransientFEOperator`. They have to be evaluated on the corresponding
algebraic operator, which is an `ODEOperator`.

This is because the `ODEOperator` works with vectors and it is optimised to
take advantage of constant jacobians.
"""

function Algebra.allocate_residual(
  feop::TransientFEOperator,
  t::Real, uh::TransientCellField,
  feopcache
)
  error(res_jac_on_transient_feop_msg)
end

function Algebra.residual(
  feop::TransientFEOperator,
  t::Real, uh::TransientCellField,
  feopcache
)
  error(res_jac_on_transient_feop_msg)
end

function Algebra.residual!(
  r::AbstractVector, feop::TransientFEOperator,
  t::Real, uh::TransientCellField,
  feopcache
)
  error(res_jac_on_transient_feop_msg)
end

function Algebra.allocate_jacobian(
  feop::TransientFEOperator,
  t::Real, uh::TransientCellField,
  feopcache
)
  error(res_jac_on_transient_feop_msg)
end

function Algebra.jacobian(
  feop::TransientFEOperator,
  t::Real, uh::TransientCellField,
  k::Integer, γ::Real,
  feopcache
)
  error(res_jac_on_transient_feop_msg)
end

function Algebra.jacobian!(
  J::AbstractMatrix, feop::TransientFEOperator,
  t::Real, uh::TransientCellField,
  k::Integer, γ::Real,
  feopcache
)
  error(res_jac_on_transient_feop_msg)
end

function jacobians!(
  J::AbstractMatrix, feop::TransientFEOperator,
  t::Real, uh::TransientCellField,
  γs::Tuple{Vararg{Real}},
  feopcache
)
  error(res_jac_on_transient_feop_msg)
end

###########################
# TransientIMEXFEOperator #
###########################
"""
    struct TransientIMEXFEOperator <: TransientFEOperator end

Implicit-Explicit version of `TransientFEOperator` whose residual can be
decomposed into
```math
residual(t, u, v) = implicit_residual(t, u, v) + explicit_residual(t, u, v),
```
where `implicit_residual` and `explicit_residual` are linear in `v` and the
explicit residual has one order less than the implicit residual.
"""
struct TransientIMEXFEOperator{Cim,Cex} <: TransientFEOperator{Cim}
  im_feop::TransientFEOperator{Cim}
  ex_feop::TransientFEOperator{Cex}

  function TransientIMEXFEOperator(
    im_feop::TransientFEOperator,
    ex_feop::TransientFEOperator
  )
    msg = """
    The explicit `TransientFEOperator` of a `TransientIMEXFEOperator` must have
    one order less than the implicit `TransientFEOperator`.
    """
    @assert get_order(im_feop) == get_order(ex_feop) + 1 msg
    Cim = ODEOperatorType(im_feop)
    Cex = ODEOperatorType(ex_feop)
    new{Cim,Cex}(im_feop, ex_feop)
  end
end

# TransientFEOperator interface
# Only this function needs to be implemented because all other functions of the
# interface are going to be called on the implicit and explicit
# `ODEOpFromFEOp`s within the `IMEXODEOperator` interface, and in turn called
# on the implicit and explicit `TransientFEOperator`s separately
function FESpaces.get_algebraic_operator(feop::TransientIMEXFEOperator)
  im_odeop = ODEOpFromFEOp(feop.im_feop)
  ex_odeop = ODEOpFromFEOp(feop.ex_feop)
  GenericIMEXODEOperator(im_odeop, ex_odeop)
end

#############################
# TransientFEOpFromWeakForm #
#############################
"""
    struct TransientFEOpFromWeakForm <: TransientFEOperator end

Generic `TransientFEOperator` constructed from the weak formulation of a
partial differential equation.
"""
struct TransientFEOpFromWeakForm <: TransientFEOperator{NonlinearODE}
  res::Function
  jacs::Tuple{Vararg{Function}}
  jacs_constant::Tuple{Vararg{Bool}}
  assembler::Assembler
  trial::FESpace
  test::FESpace
  order::Integer
end

# Constructors
function TransientFEOperator(
  res::Function,
  trial, test;
  order::Integer=1,
  jacs_constant::Tuple{Vararg{Bool}}=ntuple(_ -> false, order + 1)
)
  if trial isa MultiFieldFESpace
    TransientCellFieldType = TransientMultiFieldCellField
  else
    TransientCellFieldType = TransientCellField
  end

  function jac_0(t, u, du, v)
    function res_0(y)
      u0 = TransientCellFieldType(y, u.derivatives)
      res(t, u0, v)
    end
    jacobian(res_0, u.cellfield)
  end
  jacs = (jac_0,)

  for k in 1:order
    function jac_k(t, u, duk, v)
      function res_k(y)
        derivatives = (u.derivatives[1:k-1]..., y, u.derivatives[k+1:end]...)
        uk = TransientCellFieldType(u.cellfield, derivatives)
        res(t, uk, v)
      end
      jacobian(res_k, u.derivatives[k])
    end
    jacs = (jacs..., jac_k)
  end

  TransientFEOperator(res, jacs..., trial, test; jacs_constant)
end

# Order 0
function TransientFEOperator(
  res::Function, jac::Function,
  trial, test;
  jacs_constant::NTuple{1,Bool}=ntuple(_ -> false, 1)
)
  assembler = SparseMatrixAssembler(trial, test)
  TransientFEOpFromWeakForm(
    res, (jac,), jacs_constant,
    assembler, trial, test, 0
  )
end

# Order 1
function TransientFEOperator(
  res::Function,
  jac::Function, jac_t::Function,
  trial, test;
  jacs_constant::NTuple{2,Bool}=ntuple(_ -> false, 2)
)
  assembler = SparseMatrixAssembler(trial, test)
  TransientFEOpFromWeakForm(
    res, (jac, jac_t), jacs_constant,
    assembler, trial, test, 1
  )
end

# Order 2
function TransientFEOperator(
  res::Function,
  jac::Function, jac_t::Function, jac_tt::Function,
  trial, test;
  jacs_constant::NTuple{3,Bool}=ntuple(_ -> false, 3)
)
  assembler = SparseMatrixAssembler(trial, test)
  TransientFEOpFromWeakForm(
    res, (jac, jac_t, jac_tt), jacs_constant,
    assembler, trial, test, 2
  )
end

# TransientFEOperator interface (rest in # Common functions)
get_res(feop::TransientFEOpFromWeakForm) = feop.res

get_jacs(feop::TransientFEOpFromWeakForm) = feop.jacs

#######################################
# TransientMassLinearFEOpFromWeakForm #
#######################################
"""
    struct TransientMassLinearFEOpFromWeakForm <: TransientFEOperator end

Transient `FEOperator` defined by a transient weak form
```math
residual(t, u, v) = mass(t, u, v) + res(t, u, v) = 0.
```
Let `N` be the order of the operator. We impose the following conditions:
* `mass` is linear in the `N`-th-order time derivative of `u`,
* `res` has order `N-1`,
* both `mass` and `res` are linear in `v`.
"""
struct TransientMassLinearFEOpFromWeakForm <: TransientFEOperator{MassLinearODE}
  mass::Function
  res::Function
  jacs::Tuple{Vararg{Function}}
  jacs_constant::Tuple{Vararg{Bool}}
  residual_constant::Bool
  assembler::Assembler
  trial::FESpace
  test::FESpace
  order::Integer
end

# Constructors
function TransientMassLinearFEOperator(
  mass::Function, res::Function,
  trial, test;
  order::Integer=1,
  jacs_constant::Tuple{Vararg{Bool}}=ntuple(_ -> false, order + 1),
  residual_constant::Bool=false
)
  if trial isa MultiFieldFESpace
    TransientCellFieldType = TransientMultiFieldCellField
  else
    TransientCellFieldType = TransientCellField
  end

  function jac_0(t, u, du, v)
    function res_0(y)
      u0 = TransientCellFieldType(y, u.derivatives)
      mass(t, u0, v) + res(t, u0, v)
    end
    jacobian(res_0, u.cellfield)
  end
  jacs = (jac_0,)

  for k in 1:order-1
    function jac_k(t, u, duk, v)
      function res_k(y)
        derivatives = (u.derivatives[1:k-1]..., y, u.derivatives[k+1:end]...)
        uk = TransientCellFieldType(u.cellfield, derivatives)
        mass(t, uk, v) + res(t, uk, v)
      end
      jacobian(res_k, u.derivatives[k])
    end
    jacs = (jacs..., jac_k)
  end

  if order > 0
    function jac_N(t, u, duN, v)
      function res_N(y)
        derivatives = (u.derivatives[1:order-1]..., y)
        uN = TransientCellFieldType(u.cellfield, derivatives)
        mass(t, uN, v)
      end
      jacobian(res_N, u.derivatives[order])
    end
    jacs = (jacs..., jac_N)
  end

  TransientMassLinearFEOperator(
    mass, res, jacs..., trial, test;
    jacs_constant, residual_constant
  )
end

# Order 0
function TransientMassLinearFEOperator(
  mass::Function, res::Function, jac::Function,
  trial, test;
  jacs_constant::NTuple{1,Bool}=ntuple(_ -> false, 1),
  residual_constant::Bool=false
)
  assembler = SparseMatrixAssembler(trial, test)
  TransientMassLinearFEOpFromWeakForm(
    mass, res, (jac,), jacs_constant, residual_constant,
    assembler, trial, test, 0
  )
end

# Order 1
function TransientMassLinearFEOperator(
  mass::Function, res::Function,
  jac::Function, jac_t::Function,
  trial, test;
  jacs_constant::NTuple{2,Bool}=ntuple(_ -> false, 2),
  residual_constant::Bool=false
)
  assembler = SparseMatrixAssembler(trial, test)
  TransientMassLinearFEOpFromWeakForm(
    mass, res, (jac, jac_t), jacs_constant, residual_constant,
    assembler, trial, test, 1
  )
end

# Order 2
function TransientMassLinearFEOperator(
  mass::Function, res::Function,
  jac::Function, jac_t::Function, jac_tt::Function,
  trial, test;
  jacs_constant::NTuple{3,Bool}=ntuple(_ -> false, 3),
  residual_constant::Bool=false
)
  assembler = SparseMatrixAssembler(trial, test)
  TransientMassLinearFEOpFromWeakForm(
    mass, res, (jac, jac_t, jac_tt), jacs_constant, residual_constant,
    assembler, trial, test, 2
  )
end

# TransientFEOperator interface (rest in # Common functions)
get_res(feop::TransientMassLinearFEOpFromWeakForm) = feop.res

get_jacs(feop::TransientMassLinearFEOpFromWeakForm) = feop.jacs

get_mass(feop::TransientMassLinearFEOpFromWeakForm) = feop.mass

###################################
# TransientLinearFEOpFromWeakForm #
###################################
"""
    struct TransientLinearFEOpFromWeakForm <: TransientFEOperator end

Transient `FEOperator` defined by a transient weak form
```math
∑_{0 ≤ k ≤ N} form_k(t, ∂t^k(u), v) + res(t, v) = 0
```, where `N` is the order of the operator, `form_k` is linear in `∂t^k(u)`
and does not depend on the other time derivatives of `u`.
"""
struct TransientLinearFEOpFromWeakForm <: TransientFEOperator{LinearODE}
  forms::Tuple{Vararg{Function}}
  res::Function
  jacs::Tuple{Vararg{Function}}
  jacs_constant::Tuple{Vararg{Bool}}
  residual_constant::Bool
  assembler::Assembler
  trial::FESpace
  test::FESpace
  order::Integer
end

# Constructors
function TransientLinearFEOperator(
  forms::Tuple{Vararg{Function}}, res::Function,
  trial, test;
  order::Integer=1,
  jacs_constant::Tuple{Vararg{Bool}}=ntuple(_ -> false, order + 1),
  residual_constant::Bool=false
)
  if trial isa MultiFieldFESpace
    TransientCellFieldType = TransientMultiFieldCellField
  else
    TransientCellFieldType = TransientCellField
  end

  function jac_0(t, u, du, v)
    function res_0(y)
      u0 = TransientCellFieldType(y, u.derivatives)
      forms[order+1](t, u0, v)
    end
    jacobian(res_0, u.cellfield)
  end
  jacs = (jac_0,)

  for k in 1:order
    function jac_k(t, u, duk, v)
      function res_k(y)
        derivatives = (u.derivatives[1:k-1]..., y, u.derivatives[k+1:end]...)
        uk = TransientCellFieldType(u.cellfield, derivatives)
        forms[order+1-k](t, uk, v)
      end
      jacobian(res_k, u.derivatives[k])
    end
    jacs = (jacs..., jac_k)
  end

  TransientLinearFEOperator(
    forms, res, jacs..., trial, test;
    jacs_constant, residual_constant
  )
end

# Order 0
function TransientLinearFEOperator(
  mass::Function, res::Function, jac::Function,
  trial, test;
  jacs_constant::NTuple{1,Bool}=ntuple(_ -> false, 1),
  residual_constant::Bool=false
)
  TransientLinearFEOperator(
    (mass,), res,
    jac, jac_t, trial, test;
    jacs_constant, residual_constant
  )
end

function TransientLinearFEOperator(
  forms::NTuple{1,Function}, res::Function, jac::Function,
  trial, test;
  jacs_constant::NTuple{1,Bool}=ntuple(_ -> false, 1),
  residual_constant::Bool=false
)
  assembler = SparseMatrixAssembler(trial, test)
  TransientLinearFEOpFromWeakForm(
    forms, res, (jac,), jacs_constant, residual_constant,
    assembler, trial, test, 0
  )
end

# Order 1
function TransientLinearFEOperator(
  mass::Function, stiffness::Function, res::Function,
  jac::Function, jac_t::Function,
  trial, test;
  jacs_constant::NTuple{2,Bool}=ntuple(_ -> false, 2),
  residual_constant::Bool=false
)
  TransientLinearFEOperator(
    (mass, stiffness), res,
    jac, jac_t, trial, test;
    jacs_constant, residual_constant
  )
end

function TransientLinearFEOperator(
  forms::NTuple{2,Function}, res::Function,
  jac::Function, jac_t::Function,
  trial, test;
  jacs_constant::NTuple{2,Bool}=ntuple(_ -> false, 2),
  residual_constant::Bool=false
)
  assembler = SparseMatrixAssembler(trial, test)
  TransientLinearFEOpFromWeakForm(
    forms, res, (jac, jac_t), jacs_constant, residual_constant,
    assembler, trial, test, 1
  )
end

# Order 2
function TransientLinearFEOperator(
  mass::Function, stiffness::Function, damping::Function, res::Function,
  jac::Function, jac_t::Function, jac_tt::Function,
  trial, test;
  jacs_constant::NTuple{3,Bool}=ntuple(_ -> false, 3),
  residual_constant::Bool=false
)
  TransientLinearFEOperator(
    (mass, stiffness, damping), res,
    jac, jac_t, jac_tt, trial, test;
    jacs_constant, residual_constant
  )
end

function TransientLinearFEOperator(
  forms::NTuple{3,Function}, res::Function,
  jac::Function, jac_t::Function, jac_tt::Function,
  trial, test;
  jacs_constant::NTuple{3,Bool}=ntuple(_ -> false, 3),
  residual_constant::Bool=false
)
  assembler = SparseMatrixAssembler(trial, test)
  TransientLinearFEOpFromWeakForm(
    forms, res, (jac, jac_t, jac_tt), jacs_constant, residual_constant,
    assembler, trial, test, 2
  )
end

# TransientFEOperator interface (rest in # Common functions)
get_res(feop::TransientLinearFEOpFromWeakForm) = (t, u, v) -> feop.res(t, v)

get_jacs(feop::TransientLinearFEOpFromWeakForm) = feop.jacs

get_forms(feop::TransientLinearFEOpFromWeakForm) = feop.forms

####################
# Common functions #
####################
const TransientFEOperatorTypes = Union{
  TransientFEOpFromWeakForm,
  TransientMassLinearFEOpFromWeakForm,
  TransientLinearFEOpFromWeakForm
}
const TransientAbstractMassLinearFEOperatorTypes = Union{
  TransientMassLinearFEOpFromWeakForm,
  TransientLinearFEOpFromWeakForm
}

# FEOperator interface
FESpaces.get_test(feop::TransientFEOperatorTypes) = feop.test

FESpaces.get_trial(feop::TransientFEOperatorTypes) = feop.trial

# ODEOperator interface
Polynomials.get_order(feop::TransientFEOperatorTypes) = feop.order

# TransientFEOperator interface
get_assembler(feop::TransientFEOperatorTypes) = feop.assembler

function is_jacobian_constant(feop::TransientFEOperatorTypes, k::Integer)
  feop.jacs_constant[k+1]
end

function is_residual_constant(feop::TransientAbstractMassLinearFEOperatorTypes)
  feop.residual_constant
end

########
# Test #
########
"""
    test_transient_fe_operator(
      feop::TransientFEOperator,
      t::Real, uh::TransientCellField
    ) -> Bool

Test the interface of `TransientFEOperator` specializations.
"""
function test_transient_fe_operator(
  feop::TransientFEOperator,
  t::Real, uh::TransientCellField
)
  U = get_trial(feop)
  Ut = U(t)
  @test Ut isa FESpace

  V = get_test(feop)
  @test V isa FESpace

  us = (get_free_dof_values(uh.cellfield),)
  for derivative in uh.derivatives
    us = (us..., get_free_dof_values(derivative))
  end

  odeop = get_algebraic_operator(feop)
  @test odeop isa ODEOperator

  test_ode_operator(odeop, t, us)

  true
end
