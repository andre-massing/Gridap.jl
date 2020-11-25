module RaviartThomasRefFEsTest

using Test
using Gridap.Polynomials
using Gridap.Fields
using Gridap.TensorValues
using Gridap.Fields: MockField
using Gridap.ReferenceFEs
using Gridap.Geometry
using Gridap.CellData
using Gridap.Arrays
using Gridap.Visualization

using GridapGmsh
using Gridap
using Gridap.FESpaces

p = QUAD
D = num_dims(QUAD)
et = Float64
order = 0

reffe = RaviartThomasRefFE(et,p,order)
test_reference_fe(reffe)
@test num_terms(get_prebasis(reffe)) == 4
@test get_order(get_prebasis(reffe)) == 0
@test num_dofs(reffe) == 4
@test Conformity(reffe) == DivConformity()
p = QUAD
D = num_dims(QUAD)
et = Float64
order = 1

reffe = RaviartThomasRefFE(et,p,order)
test_reference_fe(reffe)
@test num_terms(get_prebasis(reffe)) == 12
@test num_dofs(reffe) == 12
@test get_order(get_prebasis(reffe)) == 1

prebasis = get_prebasis(reffe)
dof_basis = get_dof_basis(reffe)

v = VectorValue(3.0,0.0)
field = GenericField(x->v*x[1])

cache = return_cache(dof_basis,field)
r = evaluate!(cache, dof_basis, field)
test_dof_array(dof_basis,field,r)

cache = return_cache(dof_basis,prebasis)
r = evaluate!(cache, dof_basis, prebasis)
test_dof_array(dof_basis,prebasis,r)


p = TET
D = num_dims(TET)
et = Float64
order = 0

reffe = RaviartThomasRefFE(et,p,order)
test_reference_fe(reffe)
@test num_terms(get_prebasis(reffe)) == 4
@test num_dofs(reffe) == 4
@test get_order(get_prebasis(reffe)) == 0
@test Conformity(reffe) == DivConformity()

p = TET
D = num_dims(p)
et = Float64
order = 2

reffe = RaviartThomasRefFE(et,p,order)
test_reference_fe(reffe)
@test num_terms(get_prebasis(reffe)) == 36
@test num_dofs(reffe) == 36
@test get_order(get_prebasis(reffe)) == 2
@test Conformity(reffe) == DivConformity()

prebasis = get_prebasis(reffe)
dof_basis = get_dof_basis(reffe)

v = VectorValue(0.0,3.0,0.0)
field = GenericField(x->v)

cache = return_cache(dof_basis,field)
r = evaluate!(cache, dof_basis, field)
test_dof_array(dof_basis,field,r)

cache = return_cache(dof_basis,prebasis)
r = evaluate!(cache, dof_basis, prebasis)
test_dof_array(dof_basis,prebasis,r)

#=

p = TRI
D = num_dims(p)
et = Float64
order = 1

reffe = RaviartThomasRefFE(et,p,order)

model = GmshDiscreteModel("./mesh_2d.msh")
labels = get_face_labeling(model)
dir_tags = Array{Integer}(undef,0)
trian = Triangulation(model)
#quad = CellQuadrature(trian,2*order+1)
#V = ConformingFESpace([reffe],DivConformity(),model,labels,dir_tags)
V = FESpace(model,reffe,conformity=DivConformity())
free_values = ones(num_free_dofs(V))
#i=0
#free_values[1+i] = 1.0
#free_values[4+i] = 1.0
#free_values[7+i] = 1.0
#free_values[10+i] = 1.0
uh = FEFunction(V,free_values)
v = VectorValue(1.0,0.0)
v2(x) = VectorValue(-0.5*x[1]+1.0,-0.5*x[2])
#v2(x) = VectorValue(-0.5*x[1]+1.0,-0.5*x[2],-0.5*x[3])
vh = interpolate(v2,V)
writevtk(trian,"test",order=3,cellfields=["vh"=>vh, "uh"=>uh])




#cell_map = get_cell_map(trian)
#s,vals = compute_cell_space(expand_cell_data([reffe],[1,1,1,1]),cell_map,ReferenceDomain())
#s,vals = compute_cell_space(expand_cell_data([reffe],[1,1,1,1]),trian)

#h = lazy_map(evaluate!, s, vals)
#h = evaluate(s, vals)

writevtk(strian,"test",cellfields=["nv"=>nv])
@show "int"
I = integrate(uh,quad)
=#
# Factory function
reffe = ReferenceFE(QUAD,:RaviartThomas,0)
@test num_terms(get_prebasis(reffe)) == 4
@test get_order(get_prebasis(reffe)) == 0
@test num_dofs(reffe) == 4
@test Conformity(reffe) == DivConformity()

reffe = ReferenceFE(QUAD,:RaviartThomas,Float64,0)
@test num_terms(get_prebasis(reffe)) == 4
@test get_order(get_prebasis(reffe)) == 0
@test num_dofs(reffe) == 4
@test Conformity(reffe) == DivConformity()

@test Conformity(reffe,:L2) == L2Conformity()
@test Conformity(reffe,:Hdiv) == DivConformity()
@test Conformity(reffe,:HDiv) == DivConformity()

end # module
