
"""
    wireframe(x, y, z)
    wireframe(positions)
    wireframe(mesh)

Draws a wireframe, either interpreted as a surface or as a mesh.

## Attributes
$(ATTRIBUTES)
"""
@recipe(Wireframe) do scene
    default_theme(scene, LineSegments)
end

function convert_arguments(::Type{<: Wireframe}, x::AbstractVector, y::AbstractVector, z::AbstractMatrix)
    (ngrid(x, y)..., z)
end

xvector(x::AbstractVector, len) = x
xvector(x::ClosedInterval, len) = range(minimum(x), stop=maximum(x), length=len)
xvector(x::AbstractMatrix, len) = x

yvector(x, len) = xvector(x, len)'
yvector(x::AbstractMatrix, len) = x

function plot!(plot::Wireframe{<: Tuple{<: Any, <: Any, <: AbstractMatrix}})
    points_faces = lift(plot[1:3]...) do x, y, z
        M, N = size(z)
        points = vec(Point3f.(xvector(x, M), yvector(y, N), z))
        # Connect the vetices with faces, as one would use for a 2D Rectangle
        # grid with M,N grid points
        faces = decompose(LineFace{GLIndex}, Tesselation(Rect2(0, 0, 1, 1), (M, N)))
        connect(points, faces)
    end
    linesegments!(plot, Attributes(plot), points_faces)
end

function plot!(plot::Wireframe{Tuple{T}}) where T
    points = lift(plot[1]) do g
        # get the point representation of the geometry
        indices = decompose(LineFace{GLIndex}, g)
        points = decompose(Point3f, g)
        return connect(points, indices)
    end
    linesegments!(plot, Attributes(plot), points)
end
