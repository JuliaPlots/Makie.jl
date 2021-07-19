notchheight(q2, q4, N) = 1.58 * (q4 - q2) / sqrt(N)

#=
Taken from https://github.com/JuliaPlots/StatPlots.jl/blob/master/src/boxplot.jl#L7
The StatPlots.jl package is licensed under the MIT "Expat" License:
    Copyright (c) 2016: Thomas Breloff.
=#
"""
    boxplot(x, y; kwargs...)
Draw a Tukey style boxplot.
The boxplot has 3 components:
- a `crossbar` spanning the interquartile (IQR) range with a midline marking the
    median
- an `errorbar` whose whiskers span `range * iqr`
- points marking outliers, that is, data outside the whiskers
# Arguments
- `x`: positions of the categories
- `y`: variables within the boxes
# Keywords
- `orientation=:vertical`: orientation of box (`:vertical` or `:horizontal`)
- `width=0.8`: width of the box
- `show_notch=false`: draw the notch
- `notchwidth=0.5`: multiplier of `width` for narrowest width of notch
- `show_median=true`: show median as midline
- `range`: multiple of IQR controlling whisker length
- `whiskerwidth`: multiplier of `width` for width of T's on whiskers, or
    `:match` to match `width`
- `show_outliers`: show outliers as points
"""
@recipe(BoxPlot, x, y) do scene
    Theme(
        color = theme(scene, :patchcolor),
        colormap = theme(scene, :colormap),
        colorrange = automatic,
        orientation = :vertical,
        # box and dodging
        width = automatic,
        dodge = automatic,
        n_dodge = automatic,
        x_gap = 0.2,
        dodge_gap = 0.03,
        strokecolor = theme(scene, :patchstrokecolor),
        strokewidth = theme(scene, :patchstrokewidth),
        # notch
        show_notch = false,
        notchwidth = 0.5,
        # median line
        show_median = true,
        mediancolor = theme(scene, :linecolor),
        medianlinewidth = theme(scene, :linewidth),
        # whiskers
        range = 1.5,
        whiskerwidth = 0.0,
        whiskercolor = theme(scene, :linecolor),
        whiskerlinewidth = theme(scene, :linewidth),
        # outliers points
        show_outliers = true,
        marker = theme(scene, :marker),
        markersize = theme(scene, :markersize),
        outliercolor = automatic,
        outlierstrokecolor = theme(scene, :markerstrokecolor),
        outlierstrokewidth = theme(scene, :markerstrokewidth),
        cycle = [:color => :patchcolor],
        inspectable = theme(scene, :inspectable)
    )
end

conversion_trait(x::Type{<:BoxPlot}) = SampleBased()

_cycle(v::AbstractVector, idx::Integer) = v[mod1(idx, length(v))]
_cycle(v, idx::Integer) = v

_flip_xy(p::Point2f) = reverse(p)
_flip_xy(r::Rect{2,T}) where {T} = Rect{2,T}(reverse(r.origin), reverse(r.widths))

function Makie.plot!(plot::BoxPlot)
    args = @extract plot (width, range, show_outliers, whiskerwidth, show_notch, orientation, x_gap, dodge, n_dodge, dodge_gap)

    signals = lift(
        plot[1],
        plot[2],
        plot[:color],
        args...,
    ) do x, y, color, width, range, show_outliers, whiskerwidth, show_notch, orientation, x_gap, dodge, n_dodge, dodge_gap
        x̂, boxwidth = xw_from_dodge(x, width, 1.0, x_gap, dodge, n_dodge, dodge_gap)
        if !(whiskerwidth == :match || whiskerwidth >= 0)
            error("whiskerwidth must be :match or a positive number. Found: $whiskerwidth")
        end
        ww = whiskerwidth == :match ? boxwidth : whiskerwidth * boxwidth
        outlier_points = Point2f[]
        centers = Float32[]
        medians = Float32[]
        boxmin = Float32[]
        boxmax = Float32[]
        notchmin = Float32[]
        notchmax = Float32[]
        t_segments = Point2f[]
        outlier_indices = Int[]
        T = color isa AbstractVector ? eltype(color) : typeof(color)
        boxcolor = T[]
        for (i, (center, idxs)) in enumerate(StructArrays.finduniquesorted(x̂))
            values = view(y, idxs)

            # compute quantiles
            q1, q2, q3, q4, q5 = quantile(values, LinRange(0, 1, 5))

            # notches
            if show_notch
                nh = notchheight(q2, q4, length(values))
                nmin, nmax = q3 - nh, q3 + nh
                push!(notchmin, nmin)
                push!(notchmax, nmax)
            end

            # outliers
            if Float64(range) != 0.0  # if the range is 0.0, the whiskers will extend to the data
                limit = range * (q4 - q2)
                inside = Float64[]
                for (value, idx) in zip(values,idxs)
                    if (value < (q2 - limit)) || (value > (q4 + limit))
                        if show_outliers
                            push!(outlier_points, (center, value))
                            # register outlier box indices
                            push!(outlier_indices, idx)
                        end
                    else
                        push!(inside, value)
                    end
                end
                # change q1 and q5 to show outliers
                # using maximum and minimum values inside the limits
                q1, q5 = extrema_nan(inside)
                # register boxcolor
                push!(boxcolor, getuniquevalue(color, idxs))
            end

            # whiskers
            HW = 0.5 * _cycle(ww, i) # Whisker width
            lw, rw = center - HW, center + HW
            push!(t_segments, (center, q2), (center, q1), (lw, q1), (rw, q1)) # lower T
            push!(t_segments, (center, q4), (center, q5), (rw, q5), (lw, q5)) # upper T

            # box
            push!(centers, center)
            push!(boxmin, q2)
            push!(medians, q3)
            push!(boxmax, q4)
        end

        # for horizontal boxplots just flip all components
        if orientation == :horizontal
            outlier_points = _flip_xy.(outlier_points)
            t_segments = _flip_xy.(t_segments)
        elseif orientation != :vertical
            error("Invalid orientation $orientation. Valid options: :horizontal or :vertical.")
        end

        return (
            centers = centers,
            boxmin = boxmin,
            boxmax = boxmax,
            medians = medians,
            notchmin = notchmin,
            notchmax = notchmax,
            outliers = outlier_points,
            t_segments = t_segments,
            boxwidth = boxwidth,
            outlier_indices = outlier_indices,
            boxcolor = boxcolor,
        )
    end
    centers = @lift($signals.centers)
    boxmin = @lift($signals.boxmin)
    boxmax = @lift($signals.boxmax)
    medians = @lift($signals.medians)
    notchmin = @lift($show_notch ? $signals.notchmin : automatic)
    notchmax = @lift($show_notch ? $signals.notchmax : automatic)
    outliers = @lift($signals.outliers)
    t_segments = @lift($signals.t_segments)
    boxwidth = @lift($signals.boxwidth)
    outlier_indices = @lift($signals.outlier_indices)
    boxcolor = @lift($signals.boxcolor)

    outliercolor = lift(plot[:outliercolor], plot[:color], outlier_indices) do outliercolor, color, outlier_indices
        c = outliercolor === automatic ? color : outliercolor
        if c isa AbstractVector
            return c[outlier_indices]
        else 
            return c
        end
    end

    scatter!(
        plot,
        color = outliercolor,
        marker = plot[:marker],
        markersize = plot[:markersize],
        strokecolor = plot[:outlierstrokecolor],
        strokewidth = plot[:outlierstrokewidth],
        outliers,
        inspectable = plot[:inspectable]
    )
    linesegments!(
        plot,
        color = plot[:whiskercolor],
        linewidth = plot[:whiskerlinewidth],
        t_segments,
        inspectable = plot[:inspectable]
    )
    crossbar!(
        plot,
        color = boxcolor,
        colorrange = plot[:colorrange],
        colormap = plot[:colormap],
        strokecolor = plot[:strokecolor],
        strokewidth = plot[:strokewidth],
        midlinecolor = plot[:mediancolor],
        midlinewidth = plot[:medianlinewidth],
        show_midline = plot[:show_median],
        orientation = orientation,
        width = boxwidth,
        show_notch = show_notch,
        notchmin = notchmin,
        notchmax = notchmax,
        notchwidth = plot[:notchwidth],
        inspectable = plot[:inspectable],
        centers,
        medians,
        boxmin,
        boxmax,
    )
end
