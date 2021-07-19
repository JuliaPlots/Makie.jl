"""
    stairs(xs, ys; kwargs...)

Plot a stair function.

The `step` parameter can take the following values:
- `:pre`: horizontal part of step extends to the left of each value in `xs`.
- `:post`: horizontal part of step extends to the right of each value in `xs`.
- `:center`: horizontal part of step extends halfway between the two adjacent values of `xs`.

The conversion trait of stem is `PointBased`.

## Attributes
$(ATTRIBUTES)
"""
@recipe(Stairs) do scene
    a = Attributes(
        step = :pre, # :center :post
    )
    merge(a, default_theme(scene, Lines))
end

conversion_trait(::Type{<:Stairs}) = PointBased()

function plot!(p::Stairs{<:Tuple{<:AbstractVector{<:Point2}}})
    points = p[1]

    steppoints = lift(points, p.step) do points, step
        if step == :pre
            s_points = Vector{Point2f}(undef, length(points) * 2 - 1)
            s_points[1] = point = points[1]
            for i in 1:length(points)-1
                nextpoint = points[i + 1]
                s_points[2i] = Point2f(point[1], nextpoint[2])
                s_points[2i + 1] = nextpoint
                point = nextpoint
            end
            s_points
        elseif step == :post
            s_points = Vector{Point2f}(undef, length(points) * 2 - 1)
            s_points[1] = point = points[1]
            for i in 1:length(points)-1
                nextpoint = points[i+1]
                s_points[2i] = Point2f(nextpoint[1], point[2])
                s_points[2i + 1] = nextpoint
                point = nextpoint
            end
            s_points
        elseif step == :center
            s_points = Vector{Point2f}(undef, length(points) * 2)
            s_points[1] = point = points[1]
            for i in 1:length(points)-1
                nextpoint = points[i+1]
                halfx = (point[1] + nextpoint[1]) / 2
                s_points[2i] = Point2f(halfx, point[2])
                s_points[2i + 1] = Point2f(halfx, nextpoint[2])
                point = nextpoint
            end
            s_points[end] = point
            s_points
        else
            error("Invalid step $step. Valid options are :pre, :post and :center")
        end
    end

    lines!(p, steppoints; [x for x in pairs(p.attributes) if x[1] != :step]...)
    p
end

