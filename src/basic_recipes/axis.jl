module Formatters
    using Showoff

    function scientific(ticks::AbstractVector)
        Showoff.showoff(ticks, :scientific)
    end

    function plain(ticks::AbstractVector)
        try
            Showoff.showoff(ticks, :plain)
        catch e
            bt = Base.catch_backtrace()
            Base.showerror(stderr, e)
            Base.show_backtrace(stdout, bt)
            println("with ticks: ", ticks)
            String["-Inf", "Inf"]
        end
    end

end
using .Formatters

"""
    $(SIGNATURES)

Plots a 3-dimensional OldAxis.

## Attributes
$(ATTRIBUTES)
"""
@recipe(Axis3D) do scene

    q1 = qrotation(Vec3f(1, 0, 0), -0.5f0*pi)
    q2 = qrotation(Vec3f(0, 0, 1), 1f0*pi)
    tickrotations3d = (
        qrotation(Vec3f(0,0,1), -1.5pi),
        q2,
        qrotation(Vec3f(1, 0, 0), -0.5pi) * q2
    )
    axisnames_rotation3d = tickrotations3d
    tickalign3d = (
        (:left, :center), # x axis
        (:right, :center), # y axis
        (:right, :center), # z axis
    )
    axisnames_align3d = tickalign3d
    tick_color = RGBAf(0.5, 0.5, 0.5, 0.6)
    grid_color = RGBAf(0.5, 0.5, 0.5, 0.4)
    grid_thickness = 1
    axis_linewidth = 1.5
    gridthickness = ntuple(x-> 1f0, Val(3))
    axislinewidth = ntuple(x->1.5f0, Val(3))
    tsize = 5 # in percent
    Attributes(
        visible = true,
        showticks = (true, true, true),
        showaxis = (true, true, true),
        showgrid = (true, true, true),
        scale = Vec3f(1),
        padding = 0.1,
        inspectable = false,

        names = Attributes(
            axisnames = ("x", "y", "z"),
            textcolor = (:black, :black, :black),
            rotation = axisnames_rotation3d,
            textsize = (6.0, 6.0, 6.0),
            align = axisnames_align3d,
            font = lift(dim3, theme(scene, :font)),
            gap = 3
        ),

        ticks = Attributes(
            ranges_labels = (automatic, automatic),
            formatter = Formatters.plain,

            textcolor = (tick_color, tick_color, tick_color),

            rotation = tickrotations3d,
            textsize = (tsize, tsize, tsize),
            align = tickalign3d,
            gap = 3,
            font = lift(dim3, theme(scene, :font)),
        ),

        frame = Attributes(
            linecolor = (grid_color, grid_color, grid_color),
            linewidth = (grid_thickness, grid_thickness, grid_thickness),
            axislinewidth = (axis_linewidth, axis_linewidth, axis_linewidth),
            axiscolor = (:black, :black, :black),
        )
    )
end

isaxis(x) = false
isaxis(x::Axis3D) = true

const Limits{N} = NTuple{N, Tuple{Number, Number}}

function default_ticks(limits::Limits, ticks, scale_func::Function)
    default_ticks.(limits, (ticks,), scale_func)
end

default_ticks(limits::Tuple{Number, Number}, ticks, scale_func::Function) = default_ticks(limits..., ticks, scale_func)

function default_ticks(
        lmin::Number, lmax::Number,
        ticks::AbstractVector{<: Number}, scale_func::Function
    )
    scale_func.((filter(t -> lmin <= t <= lmax, ticks)))
end

function default_ticks(
        lmin::Number, lmax::Number, ::Automatic, scale_func::Function
    )
    # scale the limits
    scaled_ticks, mini, maxi = optimize_ticks(
        scale_func(lmin),
        scale_func(lmax);
        k_min = 4, # minimum number of ticks
        k_max = 8, # maximum number of ticks
    )
    length(scaled_ticks) == 1 && isnan(scaled_ticks[1]) && return [-Inf, Inf]
    scaled_ticks
end

function default_ticks(
        lmin::Number, lmax::Number, ticks::Integer, scale_func = identity
    )
    scaled_ticks, mini, maxi = optimize_ticks(
        scale_func(lmin),
        scale_func(lmax);
        k_min = ticks, # minimum number of ticks
        k_max = ticks, # maximum number of ticks
        k_ideal = ticks,
        # `strict_span = false` rewards cases where the span of the
        # chosen  ticks is not too much bigger than amin - amax:
        strict_span = false,
    )
    scaled_ticks
end

function default_ticks(x::Automatic, limits::Tuple, n)
    default_ticks(limits, n, identity)
end

function default_ticks(ticks::Tuple, limits::Tuple, n::Tuple)
    default_ticks.(ticks, (limits,), n)
end

default_ticks(ticks::Tuple, limits::Limits, n) = default_ticks.(ticks, limits, (n,))

default_ticks(ticks::Tuple, limits::Limits, n::Tuple) = default_ticks.(ticks, limits, n)

default_ticks(ticks::AbstractVector{<: Number}, limits, n) = ticks


function default_labels(x::NTuple{N, Any}, formatter::Function) where N
    default_labels.(x, formatter)
end

function default_labels(x::AbstractVector, y::AbstractVector, formatter::Function = Formatters.plain)
    default_labels.((x, y), formatter)
end

function default_labels(ticks::AbstractVector, formatter::Function = Formatters.plain)
    if applicable(formatter, ticks)
        return formatter(ticks) # takes the whole array
    elseif applicable(formatter, first(ticks))
        return formatter.(ticks)
    else
        error("Formatting function $(formatter) is neither applicable to $(typeof(ticks)) nor $(eltype(ticks)).")
    end
end

default_labels(x::Automatic, ranges, formatter) = default_labels(ranges, formatter)
default_labels(x::Tuple, ranges::Tuple, formatter) = default_labels.(x, ranges, (formatter,))
default_labels(x::Tuple, ranges, formatter) = default_labels.(x, (ranges,), (formatter,))
default_labels(x::AbstractVector{<: AbstractString}, ranges, formatter::Function) = x
default_labels(x::AbstractVector{<: AbstractString}, ranges::AbstractVector, formatter::Function) = x

function convert_arguments(::Type{<: Axis3D}, limits::Rect)
    e = (minimum(limits), maximum(limits))
    (((e[1][1], e[2][1]), (e[1][2], e[2][2]), (e[1][3], e[2][3])),)
end

a_length(x::AbstractVector) = length(x)
a_length(x::Automatic) = x

function calculated_attributes!(::Type{<: Axis3D}, plot)
    ticks = plot.ticks
    args = (plot.padding, plot[1], ticks.ranges, ticks.labels, ticks.formatter)
    ticks[:ranges_labels] = lift(args...) do pad, lims, ranges, labels, formatter
        limit_widths = map(x-> x[2] - x[1], lims)
        pad = (limit_widths .* pad)
        # pad the drawn limits and use them as the ranges
        lim_pad = map((lim, p)-> (lim[1] - p, lim[2] + p), lims, pad)
        num_ticks = labels === automatic ? automatic : a_length.(labels)
        ranges = default_ticks(ranges, lim_pad, num_ticks)
        labels = default_labels(labels, ranges, formatter)
        (ranges, labels)
    end
    return
end

function labelposition(ranges, dim, dir, tgap, origin::StaticVector{N}) where N
    a, b = extrema(ranges[dim])
    whalf = Float32(((b - a) / 2))
    halfaxis = unit(Point{N, Float32}, dim) .* whalf

    origin .+ (halfaxis .+ (normalize(dir) * tgap))
end

_widths(x::Tuple{<: Number, <: Number}) = x[2] - x[1]
_widths(x) = Float32(maximum(x) - minimum(x))

to3tuple(x::Tuple{Any}) = (x[1], x[1], x[1])
to3tuple(x::Tuple{Any, Any}) = (x[1], x[2], x[2])
to3tuple(x::Tuple{Any, Any, Any}) = x
to3tuple(x) = ntuple(i-> x, Val(3))

function draw_axis3d(textbuffer, linebuffer, scale, limits, ranges_labels, args...)
    # make sure we extend all args to 3D
    ranges, ticklabels = ranges_labels
    args3d = to3tuple.(args)
    (
        showaxis, showticks, showgrid,
        axisnames, axisnames_color, axisnames_size, axisrotation, axisalign,
        axisnames_font, titlegap,
        gridcolors, gridthickness, axislinewidth, axiscolors,
        ttextcolor, trotation, ttextsize, talign, tfont, tgap
    ) = args3d # splat to names

    N = 3
    start!(textbuffer)
    start!(linebuffer)
    mini, maxi = first.(limits), last.(limits)

    origin = Point{N, Float32}(min.(mini, first.(ranges)))
    limit_widths = max.(last.(ranges), maxi) .- origin
    % = minimum(limit_widths) / 100 # percentage
    ttextsize = (%) .* ttextsize
    axisnames_size = (%) .* axisnames_size

    # index of the direction in which ticks and labels are drawn
    offset_indices = [ifelse(i != 2, mod1(i + 1, N), 1) for i in 1:N]
    # These need the real limits, not (%), to be scale-aware
    titlegap = 0.01limit_widths[offset_indices] .* titlegap
    tgap = 0.01limit_widths[offset_indices] .* tgap

    for i in 1:N
        axis_vec = unit(Point{N, Float32}, i)
        width = Float32(limit_widths[i])
        stop = origin .+ (width .* axis_vec)
        if showaxis[i]
            append!(linebuffer, [origin, stop], color = axiscolors[i], linewidth = axislinewidth[i])
        end
        if showticks[i]
            range = ranges[i]
            j = offset_indices[i]
            tickdir = unit(Vec{N, Float32}, j)
            offset2 = Float32(limit_widths[j] + tgap[i]) * tickdir
            for (j, tick) in enumerate(range)
                labels = ticklabels[i]
                if length(labels) >= j
                    str = labels[j]
                    if !isempty(str)
                        startpos = (origin .+ ((Float32(tick - origin[i]) * axis_vec)) .+ offset2)
                        push!(
                            textbuffer, str, startpos,
                            color = ttextcolor[i], rotation = trotation[i],
                            textsize = ttextsize[i], align = talign[i], font = tfont[i]
                        )
                    end
                end
            end
            if !isempty(axisnames[i])
                font = to_font(tfont[i])
                tick_widths = maximum(ticklabels[i]) do label
                    widths(text_bb(label, font, ttextsize[i]))[1]
                end / scale[j]
                pos = labelposition(ranges, i, tickdir, titlegap[i] + tick_widths, origin) .+ offset2
                push!(
                    textbuffer, to_latex(axisnames[i]), pos,
                    textsize = axisnames_size[i], color = axisnames_color[i],
                    rotation = axisrotation[i], align = axisalign[i], font = axisnames_font[i]
                )
            end
        end
        if showgrid[i]
            c = gridcolors[i]
            thickness = gridthickness[i]
            for _j = (i + 1):(i + N - 1)
                j = mod1(_j, N)
                dir = unit(Point{N, Float32}, j)
                range = ranges[j]
                for tick in range
                    offset = Float32(tick - origin[j]) * dir
                    append!(
                        linebuffer, [origin .+ offset, stop .+ offset],
                        color = c, linewidth = thickness
                    )
                end
            end
        end
        finish!(textbuffer); finish!(linebuffer)
    end
    return
end

function text_bb(str, font, size)
    rot = Quaternionf(0,0,0,1)
    layout = layout_text(
        str, size, font, Vec2f(0), rot, Mat4f(I), 0.5, 1.0,
        RGBAf(0, 0, 0, 0), RGBAf(0, 0, 0, 0), 0f0)
    # @assert typeof(layout.bboxes) <: Vector{Rect2f}
    return boundingbox(layout, Point3f(0), rot)
end


function plot!(scene::SceneLike, ::Type{<: Axis3D}, attributes::Attributes, args...)
    axis = Axis3D(scene, attributes, args)
    # Disable any non linear transform for the axis plot!
    axis.transformation.transform_func[] = identity
    textbuffer = TextBuffer(axis, Point{3}, transparency = true, space = :data, inspectable = axis.inspectable)
    linebuffer = LinesegmentBuffer(axis, Point{3}, transparency = true, inspectable = axis.inspectable)

    tstyle, ticks, frame = to_value.(getindex.(axis, (:names, :ticks, :frame)))
    titlevals = getindex.(tstyle, (:axisnames, :textcolor, :textsize, :rotation, :align, :font, :gap))
    framevals = getindex.(frame, (:linecolor, :linewidth, :axislinewidth, :axiscolor))
    tvals = getindex.(ticks, (:textcolor, :rotation, :textsize, :align, :font, :gap))
    args = (
        getindex.(axis, (:showaxis, :showticks, :showgrid))...,
        titlevals..., framevals..., tvals...
    )
    map_once(
        draw_axis3d,
        Node(textbuffer), Node(linebuffer), scale(scene),
        axis[1], axis.ticks.ranges_labels, args...
    )
    push!(scene, axis)
    return axis
end
