"""
    pie(fractions; kwargs...)

Creates a pie chart with the given `fractions`.

## Attributes
$(ATTRIBUTES)
"""
@recipe(Pie, values) do scene
    Theme(
        normalize = true,
        color = :gray,
        strokecolor = :black,
        strokewidth = 1,
        vertex_per_deg = 1,
        radius = 1,
        inner_radius = 0,
        offset = 0,
        inspectable = theme(scene, :inspectable)
    )
end

function plot!(plot::Pie)

    values = plot[1]

    polys = lift(values, plot.vertex_per_deg, plot.radius, plot.inner_radius, plot.offset, plot.normalize) do vals, vertex_per_deg, radius, inner_radius, offset, normalize

        T = eltype(vals)

        # find start and end angles of all pie pieces
        summed = cumsum([zero(T); vals])
        boundaries = if normalize
            summed ./ summed[end] .* 2pi
        else
            summed
        end

        # create vector of a vector of points for each piece
        vertex_arrays = map(boundaries[1:end-1], boundaries[2:end]) do sta, en
            distance = en - sta
            # how many vertices are needed for the curve?
            nvertices = max(2, ceil(Int, rad2deg(distance) * vertex_per_deg))

            # curve points
            points = map(LinRange(sta, en, nvertices)) do rad
                Point2f(cos(rad + offset), sin(rad + offset)) .* radius
            end

            # add inner points (either curve or one point)
            if inner_radius != 0
                inner_points = map(LinRange(en, sta, nvertices)) do rad
                    Point2f(cos(rad + offset), sin(rad + offset)) .* inner_radius
                end

                append!(points, inner_points)
            else
                push!(points, Point2f(0, 0))
            end

            points
        end
    end

    # plot pieces as polys
    poly!(plot, polys, color = plot.color, strokewidth = plot.strokewidth,
        strokecolor = plot.strokecolor, inspectable = plot.inspectable)
    
    plot
end