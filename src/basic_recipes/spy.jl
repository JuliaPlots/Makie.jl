"""
spy(x::Range, y::Range, z::AbstractSparseArray)

Visualizes big sparse matrices.
Usage:
```julia
N = 200_000
x = sprand(Float64, N, N, (3(10^6)) / (N*N));
spy(x)
# or if you want to specify the range of x and y:
spy(0..1, 0..1, x)
```
## Attributes
$(ATTRIBUTES)
"""
@recipe(Spy, x, y, z) do scene
    Attributes(
        marker = automatic,
        markersize = automatic,
        colormap = theme(scene, :colormap),
        colorrange = automatic,
        framecolor = :black,
        framesize = 1,
        inspectable = theme(scene, :inspectable)
    )
end

function convert_arguments(::Type{<: Spy}, x::SparseArrays.AbstractSparseArray)
    (0..size(x, 1), 0..size(x, 2), x)
end
function convert_arguments(::Type{<: Spy}, x, y, z::SparseArrays.AbstractSparseArray)
    (x, y, z)
end

function calculated_attributes!(::Type{<: Spy}, plot)
end

function plot!(p::Spy)
    rect = lift(p.x, p.y) do x, y
        xe = extrema(x)
        ye = extrema(y)
        Rect2f((xe[1], ye[1]), (xe[2] - xe[1], ye[2] - ye[1]))
    end
    # TODO FastPixel isn't accepting marker size in data coordinates
    # but instead in pixel - so we need to fix that in GLMakie for consistency
    # and make this nicer when redoing unit support
    markersize = lift(p.markersize, rect, p.z) do msize, rect, z
        if msize === automatic
            widths(rect) ./ Vec2f(size(z))
        else
            msize
        end
    end
    # TODO correctly align marker
    xycol = lift(rect, p.z, markersize) do rect, z, markersize
        x, y, color = SparseArrays.findnz(z)
        points = map(x, y) do x, y
            (((Point2f(x, y) .- 1) ./ Point2f(size(z) .- 1)) .*
            widths(rect) .+ minimum(rect))
        end
        points, convert(Vector{Float32}, color)
    end

    replace_automatic!(p, :colorrange) do
        lift(xycol) do (xy, col)
            extrema_nan(col)
        end
    end

    marker = lift(p.marker) do x
        return x === automatic ? FastPixel() : x
    end

    scatter!(
        p,
        lift(first, xycol), color = lift(last, xycol),
        marker = marker, markersize = markersize, colorrange = p.colorrange,
        inspectable = p.inspectable
    )

    lines!(p, rect, color = p.framecolor, linewidth = p.framesize, inspectable = p.inspectable)
end
