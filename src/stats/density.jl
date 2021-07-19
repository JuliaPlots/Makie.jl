function convert_arguments(P::PlotFunc, d::KernelDensity.UnivariateKDE)
    ptype = plottype(P, Lines) # choose the more concrete one
    to_plotspec(ptype, convert_arguments(ptype, d.x, d.density))
end

function convert_arguments(::Type{<:Poly}, d::KernelDensity.UnivariateKDE)
    points = Vector{Point2f}(undef, length(d.x) + 2)
    points[1] = Point2f(d.x[1], 0)
    points[2:end-1] .= Point2f.(d.x, d.density)
    points[end] = Point2f(d.x[end], 0)
    (points,)
end

function convert_arguments(P::PlotFunc, d::KernelDensity.BivariateKDE)
    ptype = plottype(P, Heatmap)
    to_plotspec(ptype, convert_arguments(ptype, d.x, d.y, d.density))
end

"""
    density(values; npoints = 200, offset = 0.0, direction = :x)

Plot a kernel density estimate of `values`.
`npoints` controls the resolution of the estimate, the baseline can be
shifted with `offset` and the `direction` set to :x or :y.
`bandwidth` and `boundary` are determined automatically by default.

`color` is usually set to a single color, but can also be set to `:x` or
`:y` to color with a gradient. If you use `:y` when direction = `:x` (or vice versa),
note that only 2-element colormaps can work correctly.

## Attributes
$(ATTRIBUTES)
"""
@recipe(Density) do scene
    Theme(
        color = theme(scene, :patchcolor),
        colormap = theme(scene, :colormap),
        colorrange = Makie.automatic,
        strokecolor = theme(scene, :patchstrokecolor),
        strokewidth = theme(scene, :patchstrokewidth),
        linestyle = nothing,
        strokearound = false,
        npoints = 200,
        offset = 0.0,
        direction = :x,
        boundary = automatic,
        bandwidth = automatic,
        cycle = [:color => :patchcolor],
        inspectable = theme(scene, :inspectable)
    )
end

function plot!(plot::Density{<:Tuple{<:AbstractVector}})
    x = plot[1]

    lowerupper = lift(x, plot.direction, plot.boundary, plot.offset,
        plot.npoints, plot.bandwidth) do x, dir, bound, offs, n, bw

        k = KernelDensity.kde(x;
            npoints = n,
            (bound === automatic ? NamedTuple() : (boundary = bound,))...,
            (bw === automatic ? NamedTuple() : (bandwidth = bw,))...,
        )

        if dir === :x
            lowerv = Point2f.(k.x, offs)
            upperv = Point2f.(k.x, offs .+ k.density)
        elseif dir === :y
            lowerv = Point2f.(offs, k.x)
            upperv = Point2f.(offs .+ k.density, k.x)
        else
            error("Invalid direction $dir, only :x or :y allowed")
        end
        (lowerv, upperv)
    end

    linepoints = lift(lowerupper, plot.strokearound) do lu, sa
        if sa
            ps = copy(lu[2])
            push!(ps, lu[1][end])
            push!(ps, lu[1][1])
            push!(ps, lu[1][2])
            ps
        else
            lu[2]
        end
    end

    lower = Node(Point2f[])
    upper = Node(Point2f[])

    on(lowerupper) do (l, u)
        lower.val = l
        upper[] = u
    end
    notify(lowerupper)

    colorobs = lift(Any, plot.color, lowerupper, plot.direction) do c, lu, dir
        if (dir == :x && c == :x) || (dir == :y && c == :y)
            dim = dir == :x ? 1 : 2
            [l[dim] for l in lu[1]]
        elseif (dir == :y && c == :x) || (dir == :x && c == :y)
            o = Float32(plot.offset[])
            dim = dir == :x ? 2 : 1
            vcat([l[dim] - o for l in lu[1]], [l[dim] - o for l in lu[2]])
        else
            c
        end
    end

    band!(plot, lower, upper, color = colorobs, colormap = plot.colormap,
        colorrange = plot.colorrange, inspectable = plot.inspectable)
    l = lines!(plot, linepoints, color = plot.strokecolor,
        linestyle = plot.linestyle, linewidth = plot.strokewidth,
        inspectable = plot.inspectable)
    plot
end
