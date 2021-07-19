#=
S. Axen implementation from https://github.com/JuliaPlots/StatsMakie.jl/blob/master/src/recipes/crossbar.jl#L22
The StatMakie.jl package is licensed under the MIT "Expat" License:
    Copyright (c) 2018: Pietro Vertechi. =#
"""
    crossbar(x, y, ymin, ymax; kwargs...)
Draw a crossbar. A crossbar represents a range with a (potentially notched) box.
It is most commonly used as part of the `boxplot`.
# Arguments
- `x`: position of the box
- `y`: position of the midline within the box
- `ymin`: lower limit of the box
- `ymax`: upper limit of the box
# Keywords
- `orientation=:vertical`: orientation of box (`:vertical` or `:horizontal`)
- `width=0.8`: width of the box
- `show_notch=false`: draw the notch
- `notchmin=automatic`: lower limit of the notch
- `notchmax=automatic`: upper limit of the notch
- `notchwidth=0.5`: multiplier of `width` for narrowest width of notch
- `show_midline=true`: show midline
"""
@recipe(CrossBar, x, y, ymin, ymax) do scene
    t = Theme(
    color=theme(scene, :patchcolor),
    colormap=theme(scene, :colormap),
    colorrange=automatic,
    orientation=:vertical,
    # box and dodging
    width = automatic,
    dodge = automatic,
    n_dodge = automatic,
    x_gap = 0.2,
    dodge_gap = 0.03,
    strokecolor = theme(scene, :patchstrokecolor),
    strokewidth = theme(scene, :patchstrokewidth),
    # notch
    show_notch=false,
    notchmin=automatic,
    notchmax=automatic,
    notchwidth=0.5,
    # median line
    show_midline=true,
    midlinecolor=automatic,
    midlinewidth=theme(scene, :linewidth),
    inspectable = theme(scene, :inspectable),
    cycle = [:color => :patchcolor],
)
    t
end

function Makie.plot!(plot::CrossBar)
    args = @extract plot (width, dodge, n_dodge, x_gap, dodge_gap, show_notch, notchmin, notchmax, notchwidth, orientation)

    signals = lift(
        plot[1],
        plot[2],
        plot[3],
        plot[4],
        args...,
    ) do x, y, ymin, ymax, width, dodge, n_dodge, x_gap, dodge_gap, show_notch, nmin, nmax, nw, orientation
        x̂, boxwidth = xw_from_dodge(x, width, 1.0, x_gap, dodge, n_dodge, dodge_gap)
        show_notch = show_notch && (nmin !== automatic && nmax !== automatic)

        # for horizontal crossbars just flip all components
        fpoint, frect = Point2f, Rectf
        if orientation == :horizontal
            fpoint, frect = _flip_xy ∘ fpoint, _flip_xy ∘ frect
        end

        # make the shape
        hw = boxwidth ./ 2 # half box width
        l, m, r = x̂ .- hw, x̂, x̂ .+ hw

        if show_notch && nmin !== automatic && nmax !== automatic
            if any(nmin < ymin || nmax > ymax)
                @warn("Crossbar's notch went outside hinges. Set notch to false.")
            end
            # when notchmin = ymin || notchmax == ymax, fill disappears from
            # half the box. first ∘ StatsBase.rle removes adjacent duplicates.
            points = first.(StatsBase.rle.(Base.vect.(fpoint.(l, ymin),
                fpoint.(r, ymin),
                fpoint.(r, nmin),
                fpoint.(m .+ nw .* hw, y), # notch right
                fpoint.(r, nmax),
                fpoint.(r, ymax),
                fpoint.(l, ymax),
                fpoint.(l, nmax),
                fpoint.(m .- nw .* hw, y), # notch left
                fpoint.(l, nmin),)))
            boxes = if points isa AbstractVector{<: Point} # poly
                [GeometryBasics.triangle_mesh(points)]
            else # multiple polys (Vector{Vector{<:Point}})
                GeometryBasics.triangle_mesh.(points)
            end
            midlines = Pair.(fpoint.(m .- nw .* hw, y), fpoint.(m .+ nw .* hw, y))
        else
            boxes = frect.(l, ymin, boxwidth, ymax .- ymin)
            midlines = Pair.(fpoint.(l, y), fpoint.(r, y))
        end
        return [boxes;], [midlines;]
    end
    boxes = @lift($signals[1])
    midlines = @lift($signals[2])
    poly!(
        plot,
        boxes,
        color=plot.color,
        colorrange=plot.colorrange,
        colormap=plot.colormap,
        strokecolor=plot.strokecolor,
        strokewidth=plot.strokewidth,
        inspectable = plot[:inspectable]
    )
    linesegments!(
        plot,
        color=lift(
            (mc, sc) -> mc === automatic ? sc : mc,
            plot.midlinecolor,
            plot.strokecolor,
        ),
        linewidth=plot[:midlinewidth],
        visible=plot[:show_midline],
        inspectable = plot[:inspectable],
        midlines,
    )
end
