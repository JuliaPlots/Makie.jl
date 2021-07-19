function LineAxis(parent::Scene; kwargs...)

    attrs = merge!(Attributes(kwargs), default_attributes(LineAxis))

    decorations = Dict{Symbol, Any}()

    @extract attrs (endpoints, limits, flipped, ticksize, tickwidth,
        tickcolor, tickalign, ticks, tickformat, ticklabelalign, ticklabelrotation, ticksvisible,
        ticklabelspace, ticklabelpad, labelpadding,
        ticklabelsize, ticklabelsvisible, spinewidth, spinecolor, label, labelsize, labelcolor,
        labelfont, ticklabelfont, ticklabelcolor,
        labelvisible, spinevisible, trimspine, flip_vertical_label, reversed,
        minorticksvisible, minortickalign, minorticksize, minortickwidth, minortickcolor, minorticks)

    pos_extents_horizontal = lift(endpoints) do endpoints
        if endpoints[1][2] == endpoints[2][2]
            horizontal = true
            extents = (endpoints[1][1], endpoints[2][1])
            position = endpoints[1][2]
            return (position, extents, horizontal)
        elseif endpoints[1][1] == endpoints[2][1]
            horizontal = false
            extents = (endpoints[1][2], endpoints[2][2])
            position = endpoints[1][1]
            return (position, extents, horizontal)
        else
            error("OldAxis endpoints $(endpoints[1]) and $(endpoints[2]) are neither on a horizontal nor vertical line")
        end
    end

    ticksnode = Node(Point2f[])
    ticklines = linesegments!(
        parent, ticksnode, linewidth = tickwidth, color = tickcolor, linestyle = nothing,
        show_axis = false, visible = ticksvisible, inspectable = false
    )
    decorations[:ticklines] = ticklines
    translate!(ticklines, 0, 0, 10)

    minorticksnode = Node(Point2f[])
    minorticklines = linesegments!(
        parent, minorticksnode, linewidth = minortickwidth, color = minortickcolor,
        linestyle = nothing,
        show_axis = false, visible = minorticksvisible, inspectable = false
    )
    decorations[:minorticklines] = minorticklines

    realticklabelalign = lift(Any, ticklabelalign, pos_extents_horizontal, flipped, ticklabelrotation) do al, (pos, ex, hor), fl, rot
        if al !== automatic
            return al
        end
        if rot == 0 || !(rot isa Real)
            if hor
                (:center, fl ? :bottom : :top)
            else
                (fl ? :left : :right, :center)
            end
        elseif rot ≈ pi/2
            if hor
                (fl ? :left : :right, :center)
            else
                (:center, fl ? :top : :bottom)
            end
        elseif rot ≈ -pi/2
            if hor
                (fl ? :right : :left, :center)
            else
                (:center, fl ? :bottom : :top)
            end
        elseif rot > 0
            if hor
                (fl ? :left : :right, fl ? :bottom : :top)
            else
                (fl ? :left : :right, :center)
            end
        elseif rot < 0
            if hor
                (fl ? :right : :left, fl ? :bottom : :top)
            else
                (fl ? :left : :right, :center)
            end
        end
    end

    ticklabelannosnode = Node(Tuple{AbstractString, Point2f}[])
    ticklabels = nothing

    ticklabel_ideal_space = lift(Float32, ticklabelannosnode, ticklabelalign, ticklabelrotation, ticklabelfont, ticklabelsvisible) do args...
        maxwidth = if pos_extents_horizontal[][3]
                # height
                ticklabelsvisible[] ? (ticklabels === nothing ? 0f0 : height(Rect2f(boundingbox(ticklabels)))) : 0f0
            else
                # width
                ticklabelsvisible[] ? (ticklabels === nothing ? 0f0 : width(Rect2f(boundingbox(ticklabels)))) : 0f0
        end
        # in case there is no string in the annotations and the boundingbox comes back all NaN
        if !isfinite(maxwidth)
            maxwidth = zero(maxwidth)
        end
        maxwidth
    end

    attrs[:actual_ticklabelspace] = 0f0
    actual_ticklabelspace = attrs[:actual_ticklabelspace]

    onany(ticklabel_ideal_space, ticklabelspace) do idealspace, space
        s = if space == automatic
            idealspace
        else
            space
        end
        if s != actual_ticklabelspace[]
            actual_ticklabelspace[] = s
        end
    end



    tickspace = lift(ticksvisible, ticksize, tickalign) do ticksvisible,
            ticksize, tickalign

        ticksvisible ? max(0f0, ticksize * (1f0 - tickalign)) : 0f0
    end

    labelgap = lift(spinewidth, tickspace, ticklabelsvisible, actual_ticklabelspace,
        ticklabelpad, labelpadding) do spinewidth, tickspace, ticklabelsvisible,
            actual_ticklabelspace, ticklabelpad, labelpadding


        spinewidth + tickspace +
            (ticklabelsvisible ? actual_ticklabelspace + ticklabelpad : 0f0) +
            labelpadding
    end

    labelpos = lift(pos_extents_horizontal, flipped, labelgap) do (position, extents, horizontal), flipped, labelgap

        # fullgap = tickspace[] + labelgap

        middle = extents[1] + 0.5f0 * (extents[2] - extents[1])

        x_or_y = flipped ? position + labelgap : position - labelgap

        if horizontal
            Point2(middle, x_or_y)
        else
            Point2(x_or_y, middle)
        end
    end

    labelalign = lift(pos_extents_horizontal, flipped, flip_vertical_label) do (position, extents, horizontal), flipped, flip_vertical_label
        if horizontal
            (:center, flipped ? :bottom : :top)
        else
            (:center, if flipped
                    flip_vertical_label ? :bottom : :top
                else
                    flip_vertical_label ? :top : :bottom
                end
            )
        end
    end

    labelrotation = lift(pos_extents_horizontal, flip_vertical_label) do (position, extents, horizontal), flip_vertical_label
        if horizontal
            0f0
        else
            if flip_vertical_label
                Float32(-0.5pi)
            else
                Float32(0.5pi)
            end
        end
    end

    labeltext = text!(
        parent, label, textsize = labelsize, color = labelcolor,
        position = labelpos, show_axis = false, visible = labelvisible,
        align = labelalign, rotation = labelrotation, font = labelfont,
        space = :data, inspectable = false
    )

    decorations[:labeltext] = labeltext

    tickvalues = Node(Float32[])

    tickvalues_labels_unfiltered = lift(pos_extents_horizontal, limits, ticks, tickformat, attrs.scale) do (position, extents, horizontal),
            limits, ticks, tickformat, scale
        get_ticks(ticks, scale, tickformat, limits...)
    end

    tickpositions = Node(Point2f[])
    tickstrings = Node(AbstractString[])

    onany(tickvalues_labels_unfiltered, reversed) do tickvalues_labels_unfiltered, reversed

        tickvalues_unfiltered, tickstrings_unfiltered = tickvalues_labels_unfiltered

        position, extents_uncorrected, horizontal = pos_extents_horizontal[]

        extents = reversed ? reverse(extents_uncorrected) : extents_uncorrected

        px_o = extents[1]
        px_width = extents[2] - extents[1]

        lim_o = limits[][1]
        lim_w = limits[][2] - limits[][1]

        # if labels are given manually, it's possible that some of them are outside the displayed limits
        # we only check approximately because otherwise because of floating point errors, ticks can be dismissed sometimes
        i_values_within_limits = findall(tickvalues_unfiltered) do tv
            (limits[][1] <= tv || limits[][1] ≈ tv) &&
             (tv <= limits[][2] || tv ≈ limits[][2])
        end

        tickvalues[] = tickvalues_unfiltered[i_values_within_limits]

        scale = attrs.scale[]
        tickvalues_scaled = scale.(tickvalues[])

        tick_fractions = (tickvalues_scaled .- scale(limits[][1])) ./ (scale(limits[][2]) - scale(limits[][1]))

        tick_scenecoords = px_o .+ px_width .* tick_fractions

        tickpos = if horizontal
            [Point(x, position) for x in tick_scenecoords]
        else
            [Point(position, y) for y in tick_scenecoords]
        end

        # now trigger updates
        tickpositions[] = tickpos

        tickstrings[] = tickstrings_unfiltered[i_values_within_limits]
    end

    minortickvalues = Node(Float32[])
    minortickpositions = Node(Point2f[])

    onany(tickvalues, minorticks) do tickvalues, minorticks
        minortickvalues[] = get_minor_tickvalues(minorticks, attrs.scale[], tickvalues, limits[]...)
    end

    onany(minortickvalues) do minortickvalues
        position, extents_uncorrected, horizontal = pos_extents_horizontal[]

        extents = reversed[] ? reverse(extents_uncorrected) : extents_uncorrected

        px_o = extents[1]
        px_width = extents[2] - extents[1]

        lim_o = limits[][1]
        lim_w = limits[][2] - limits[][1]

        scale = attrs.scale[]
        tickvalues_scaled = scale.(minortickvalues)

        tick_fractions = (tickvalues_scaled .- scale(limits[][1])) ./ (scale(limits[][2]) - scale(limits[][1]))

        tick_scenecoords = px_o .+ px_width .* tick_fractions

        minortickpositions[] = if horizontal
            [Point(x, position) for x in tick_scenecoords]
        else
            [Point(position, y) for y in tick_scenecoords]
        end
    end

    onany(minortickpositions, minortickalign, minorticksize, spinewidth) do tickpositions,
        tickalign, ticksize, spinewidth

        position, extents, horizontal = pos_extents_horizontal[]

        if horizontal
            tickstarts = [tp + (flipped[] ? -1f0 : 1f0) * Point2f(0f0, tickalign * ticksize - 0.5f0 * spinewidth) for tp in tickpositions]
            tickends = [t + (flipped[] ? -1f0 : 1f0) * Point2f(0f0, -ticksize) for t in tickstarts]
            minorticksnode[] = interleave_vectors(tickstarts, tickends)
        else
            tickstarts = [tp + (flipped[] ? -1f0 : 1f0) * Point2f(tickalign * ticksize - 0.5f0 * spinewidth, 0f0) for tp in tickpositions]
            tickends = [t + (flipped[] ? -1f0 : 1f0) * Point2f(-ticksize, 0f0) for t in tickstarts]
            minorticksnode[] = interleave_vectors(tickstarts, tickends)
        end
    end

    onany(tickstrings, labelgap, flipped) do tickstrings, labelgap, flipped
        # tickspace is always updated before labelgap
        # tickpositions are always updated before tickstrings
        # so we don't need to lift those

        position, extents, horizontal = pos_extents_horizontal[]

        nticks = length(tickvalues[])

        ticklabelgap = spinewidth[] + tickspace[] + ticklabelpad[]

        shift = if horizontal
            Point2f(0f0, flipped ? ticklabelgap : -ticklabelgap)
        else
            Point2f(flipped ? ticklabelgap : -ticklabelgap, 0f0)
        end

        ticklabelpositions = tickpositions[] .+ Ref(shift)
        ticklabelannosnode[] = collect(zip(tickstrings, ticklabelpositions))
    end

    onany(tickpositions, tickalign, ticksize, spinewidth) do tickpositions,
            tickalign, ticksize, spinewidth

        position, extents, horizontal = pos_extents_horizontal[]

        if horizontal
            tickstarts = [tp + (flipped[] ? -1f0 : 1f0) * Point2f(0f0, tickalign * ticksize - 0.5f0 * spinewidth) for tp in tickpositions]
            tickends = [t + (flipped[] ? -1f0 : 1f0) * Point2f(0f0, -ticksize) for t in tickstarts]
            ticksnode[] = interleave_vectors(tickstarts, tickends)
        else
            tickstarts = [tp + (flipped[] ? -1f0 : 1f0) * Point2f(tickalign * ticksize - 0.5f0 * spinewidth, 0f0) for tp in tickpositions]
            tickends = [t + (flipped[] ? -1f0 : 1f0) * Point2f(-ticksize, 0f0) for t in tickstarts]
            ticksnode[] = interleave_vectors(tickstarts, tickends)
        end
    end

    linepoints = lift(pos_extents_horizontal, flipped, spinewidth, trimspine, tickpositions, tickwidth) do (position, extents, horizontal),
            flipped, sw, trimspine, tickpositions, tickwidth

        if !trimspine
            if horizontal
                y = position
                p1 = Point2f(extents[1] - 0.5sw, y)
                p2 = Point2f(extents[2] + 0.5sw, y)
                [p1, p2]
            else
                x = position
                p1 = Point2f(x, extents[1] - 0.5sw)
                p2 = Point2f(x, extents[2] + 0.5sw)
                [p1, p2]
            end
        else
            [tickpositions[1], tickpositions[end]] .+ [
                (horizontal ? Point2f(-0.5f0 * tickwidth, 0) : Point2f(0, -0.5f0 * tickwidth)),
                (horizontal ? Point2f(0.5f0 * tickwidth, 0) : Point2f(0, 0.5f0 * tickwidth)),
            ]
        end
    end

    decorations[:axisline] = lines!(parent, linepoints, linewidth = spinewidth, visible = spinevisible,
        color = spinecolor, raw = true, inspectable = false, linestyle = nothing)
    translate!(decorations[:axisline], 0, 0, 20)


    protrusion = lift(ticksvisible, label, labelvisible, labelpadding, labelsize, tickalign, tickspace, ticklabelsvisible, actual_ticklabelspace, ticklabelpad, labelfont, ticklabelfont) do ticksvisible,
            label, labelvisible, labelpadding, labelsize, tickalign, tickspace, ticklabelsvisible,
            actual_ticklabelspace, ticklabelpad, labelfont, ticklabelfont
        position, extents, horizontal = pos_extents_horizontal[]

        label_is_empty = iswhitespace(label) || isempty(label)

        real_labelsize = if label_is_empty
            0f0
        else
            horizontal ? boundingbox(labeltext).widths[2] : boundingbox(labeltext).widths[1]
        end

        labelspace = (labelvisible && !label_is_empty) ? real_labelsize + labelpadding : 0f0
        # tickspace = ticksvisible ? max(0f0, xticksize * (1f0 - xtickalign)) : 0f0
        tickspace = (ticksvisible && !isempty(ticklabelannosnode[])) ? tickspace : 0f0

        ticklabelgap = (ticklabelsvisible && actual_ticklabelspace > 0) ? actual_ticklabelspace + ticklabelpad : 0f0

        together = tickspace + ticklabelgap + labelspace
    end

    # trigger whole pipeline once to fill tickpositions and tickstrings
    # etc to avoid empty ticks bug #69
    limits[] = limits[]

    # in order to dispatch to the correct text recipe later (normal text, latex, etc.)
    # we need to have the ticklabelannosnode populated once before adding the annotations
    ticklabels = text!(
        parent,
        ticklabelannosnode,
        align = realticklabelalign,
        rotation = ticklabelrotation,
        textsize = ticklabelsize,
        font = ticklabelfont,
        color = ticklabelcolor,
        show_axis = false,
        visible = ticklabelsvisible,
        space = :data,
        inspectable = false)
    decorations[:ticklabels] = ticklabels

    # HACKY: the ticklabels in the string need to be updated
    # before other stuff is triggered by them, which accesses the
    # ticklabel boundingbox (which needs to be updated already)
    # so we move the new listener from text! to the front
    pushfirst!(
        ticklabelannosnode.listeners,
        pop!(ticklabelannosnode.listeners))


    # trigger calculation of ticklabel width once, now that it's not nothing anymore
    notify(ticklabelsvisible)

    LineAxis(parent, protrusion, attrs, decorations, tickpositions, tickvalues, tickstrings, minortickpositions, minortickvalues)
end


function tight_ticklabel_spacing!(la::LineAxis)

    horizontal = if la.attributes.endpoints[][1][2] == la.attributes.endpoints[][2][2]
        true
    elseif la.attributes.endpoints[][1][1] == la.attributes.endpoints[][2][1]
        false
    else
        error("endpoints not on a horizontal or vertical line")
    end

    tls = la.elements[:ticklabels]
    maxwidth = if horizontal
            # height
            tls.visible[] ? height(Rect2f(boundingbox(tls))) : 0f0
        else
            # width
            tls.visible[] ? width(Rect2f(boundingbox(tls))) : 0f0
    end
    la.attributes.ticklabelspace = maxwidth
end


function iswhitespace(str)
    match(r"^\s*$", str) !== nothing
end


function Base.delete!(la::LineAxis)
    for (_, d) in la.elements
        if d isa AbstractPlot
            delete!(d.parent, d)
        else
            delete!(d)
        end
    end
end

"""
    get_ticks(ticks, scale, formatter, vmin, vmax)

Base function that calls `get_tickvalues(ticks, vmin, max)` and
`get_ticklabels(formatter, tickvalues)` and returns a tuple
`(tickvalues, ticklabels)`.
For custom ticks / formatter combinations, this method can be overloaded
directly, or both `get_tickvalues` and `get_ticklabels` separately.
"""
function get_ticks(ticks, scale, formatter, vmin, vmax)
    tickvalues = get_tickvalues(ticks, scale, vmin, vmax)
    ticklabels = get_ticklabels(formatter, tickvalues)
    return tickvalues, ticklabels
end

# automatic with identity scaling uses WilkinsonTicks by default
get_tickvalues(::Automatic, ::typeof(identity), vmin, vmax) = get_tickvalues(WilkinsonTicks(5, k_min = 3), vmin, vmax)

# fall back to identity if not overloaded scale function is used with automatic
get_tickvalues(::Automatic, F, vmin, vmax) = get_tickvalues(automatic, identity, vmin, vmax)

# fall back to non-scale aware behavior if no special version is overloaded
get_tickvalues(ticks, scale, vmin, vmax) = get_tickvalues(ticks, vmin, vmax)



function get_ticks(ticks_and_labels::Tuple{Any, Any}, any_scale, ::Automatic, vmin, vmax)
    n1 = length(ticks_and_labels[1])
    n2 = length(ticks_and_labels[2])
    if n1 != n2
        error("There are $n1 tick values in $(ticks_and_labels[1]) but $n2 tick labels in $(ticks_and_labels[2]).")
    end
    ticks_and_labels
end

function get_ticks(tickfunction::Function, any_scale, formatter, vmin, vmax)
    result = tickfunction(vmin, vmax)
    if result isa Tuple{Any, Any}
        tickvalues, ticklabels = result
    else
        tickvalues = result
        ticklabels = get_ticklabels(formatter, tickvalues)
    end
    return tickvalues, ticklabels
end

_logbase(::typeof(log10)) = "10"
_logbase(::typeof(log2)) = "2"
_logbase(::typeof(log)) = "e"


function get_ticks(::Automatic, scale::Union{typeof(log10), typeof(log2), typeof(log)},
        any_formatter, vmin, vmax)
    get_ticks(LogTicks(WilkinsonTicks(5, k_min = 3)), scale, any_formatter, vmin, vmax)
end

# log ticks just use the normal pipeline but with log'd limits, then transform the labels
function get_ticks(l::LogTicks, scale::Union{typeof(log10), typeof(log2), typeof(log)}, ::Automatic, vmin, vmax)
    ticks_scaled = get_tickvalues(l.linear_ticks, identity, scale(vmin), scale(vmax))

    ticks = Makie.inverse_transform(scale).(ticks_scaled)

    labels_scaled = get_ticklabels(automatic, ticks_scaled)
    labels = _logbase(scale) .* Makie.UnicodeFun.to_superscript.(labels_scaled)

    (ticks, labels)
end

# function get_ticks(::Automatic, scale::typeof(Makie.logit), any_formatter, vmin, vmax)
#     get_ticks(LogitTicks(WilkinsonTicks(5, k_min = 3)), scale, any_formatter, vmin, vmax)
# end

logit_10(x) = Makie.logit(x) / log(10)
expit_10(x) = Makie.logistic(log(10) * x)

# function get_ticks(l::LogitTicks, scale::typeof(Makie.logit), ::Automatic, vmin, vmax)

#     ticks_scaled = get_tickvalues(l.linear_ticks, identity, logit_10(vmin), logit_10(vmax))

#     ticks = expit_10.(ticks_scaled)

#     base_labels = get_ticklabels(automatic, ticks_scaled)

#     labels = map(ticks_scaled, base_labels) do t, bl
#         if t == 0
#             "¹/₂"
#         elseif t < 0
#             "10" * Makie.UnicodeFun.to_superscript(bl)
#         else
#             "1-10" * Makie.UnicodeFun.to_superscript("-" * bl)
#         end
#     end

#     (ticks, labels)
# end

"""
    get_tickvalues(lt::LinearTicks, vmin, vmax)

Runs a common tick finding algorithm to as many ticks as requested by the
`LinearTicks` instance.
"""
get_tickvalues(lt::LinearTicks, vmin, vmax) = locateticks(vmin, vmax, lt.n_ideal)


"""
    get_tickvalues(tickvalues, vmin, vmax)

Convert tickvalues to a float array by default.
"""
get_tickvalues(tickvalues, vmin, vmax) = convert(Vector{Float64}, tickvalues)


# function get_tickvalues(l::LogitTicks, vmin, vmax)
#     ticks_scaled = get_tickvalues(l.linear_ticks, identity, logit_10(vmin), logit_10(vmax))
#     expit_10.(ticks_scaled)
# end

function get_tickvalues(l::LogTicks, scale, vmin, vmax)
    ticks_scaled = get_tickvalues(l.linear_ticks, scale(vmin), scale(vmax))
    Makie.inverse_transform(scale).(ticks_scaled)
end

"""
    get_ticklabels(::Automatic, values)

Gets tick labels by applying `Showoff.showoff` to `values`.
"""
get_ticklabels(::Automatic, values) = Showoff.showoff(values)

"""
    get_ticklabels(formatfunction::Function, values)

Gets tick labels by applying `formatfunction` to `values`.
"""
get_ticklabels(formatfunction::Function, values) = formatfunction(values)

"""
    get_ticklabels(formatstring::AbstractString, values)

Gets tick labels by formatting each value in `values` according to a `Formatting.format` format string.
"""
get_ticklabels(formatstring::AbstractString, values) = [Formatting.format(formatstring, v) for v in values]


function get_ticks(m::MultiplesTicks, any_scale, ::Automatic, vmin, vmax)
    dvmin = vmin / m.multiple
    dvmax = vmax / m.multiple
    multiples = MakieLayout.get_tickvalues(LinearTicks(m.n_ideal), dvmin, dvmax)

    multiples .* m.multiple, Showoff.showoff(multiples) .* m.suffix
end


function get_minor_tickvalues(i::IntervalsBetween, scale, tickvalues, vmin, vmax)
    vals = Float64[]
    length(tickvalues) < 2 && return vals
    n = i.n

    if i.mirror
        firstinterval = tickvalues[2] - tickvalues[1]
        stepsize = firstinterval / n
        v = tickvalues[1] - stepsize
        prepend!(vals, v:-stepsize:vmin)
    end

    for (lo, hi) in zip(@view(tickvalues[1:end-1]), @view(tickvalues[2:end]))
        interval = hi - lo
        stepsize = interval / n
        v = lo
        for i in 1:n-1
            v += stepsize
            push!(vals, v)
        end
    end

    if i.mirror
        lastinterval = tickvalues[end] - tickvalues[end-1]
        stepsize = lastinterval / n
        v = tickvalues[end] + stepsize
        append!(vals, v:stepsize:vmax)
    end

    vals
end

# for log scales, we need to step in log steps at the edges
function get_minor_tickvalues(i::IntervalsBetween, scale::Union{typeof(log), typeof(log2), typeof(log10)}, tickvalues, vmin, vmax)

    vals = Float64[]
    length(tickvalues) < 2 && return vals
    n = i.n

    invscale = Makie.inverse_transform(scale)

    if i.mirror
        firstinterval_scaled = scale(tickvalues[2]) - scale(tickvalues[1])
        stepsize = firstinterval_scaled / n
        prevtick = invscale(scale(tickvalues[1]) - firstinterval_scaled)
        stepsize = (tickvalues[1] - prevtick) / n
        v = tickvalues[1] - stepsize
        prepend!(vals, v:-stepsize:vmin)
    end

    for (lo, hi) in zip(@view(tickvalues[1:end-1]), @view(tickvalues[2:end]))
        interval = hi - lo
        stepsize = interval / n
        v = lo
        for i in 1:n-1
            v += stepsize
            push!(vals, v)
        end
    end

    if i.mirror
        lastinterval_scaled = scale(tickvalues[end]) - scale(tickvalues[end-1])
        nexttick = invscale(scale(tickvalues[end]) + lastinterval_scaled)
        stepsize = (nexttick - tickvalues[end]) / n
        v = tickvalues[end] + stepsize
        append!(vals, v:stepsize:vmax)
    end

    vals
end
