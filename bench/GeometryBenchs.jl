module GeometryBenchs

using Numa.Geometry

function doloop(a)
  for ai in a
  end
end

l = 1000000

println("+++ GeometryBenchs ( length = $l ) +++")

grid = CartesianGrid(domain=(0.0,1.0,-1.0,2.0,2.0,3.0),partition=(100,100,100))

x = points(grid)

print("CartesianGridPoints ->"); @time doloop(x)
print("CartesianGridPoints ->"); @time doloop(x)

t = cells(grid)

print("CartesianGridCells ->"); @time doloop(t)
print("CartesianGridCells ->"); @time doloop(t)

end # module GeometryBenchs