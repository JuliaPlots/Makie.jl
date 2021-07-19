function layoutable(::Type{Slider}, fig_or_scene; bbox = nothing, kwargs...)

    topscene = get_topscene(fig_or_scene)

    default_attrs = default_attributes(Slider, topscene).attributes
    theme_attrs = subtheme(topscene, :Slider)
    attrs = merge!(merge!(Attributes(kwargs), theme_attrs), default_attrs)

    decorations = Dict{Symbol, Any}()

    @extract attrs (
        halign, valign, horizontal, linewidth, snap,
        startvalue, value, color_active, color_active_dimmed, color_inactive
    )

    sliderrange = attrs.range

    protrusions = Node(GridLayoutBase.RectSides{Float32}(0, 0, 0, 0))
    layoutobservables = LayoutObservables{Slider}(attrs.width, attrs.height, attrs.tellwidth, attrs.tellheight,
        halign, valign, attrs.alignmode; suggestedbbox = bbox, protrusions = protrusions)

    onany(linewidth, horizontal) do lw, horizontal
        if horizontal
            layoutobservables.autosize[] = (nothing, Float32(lw))
        else
            layoutobservables.autosize[] = (Float32(lw), nothing)
        end
    end

    sliderbox = lift(identity, layoutobservables.computedbbox)

    endpoints = lift(sliderbox, horizontal) do bb, horizontal

        h = height(bb)
        w = width(bb)

        if horizontal
            y = bottom(bb) + h / 2
            [Point2f(left(bb) + h/2, y),
             Point2f(right(bb) - h/2, y)]
        else
            x = left(bb) + w / 2
            [Point2f(x, bottom(bb) + w/2),
             Point2f(x, top(bb) - w/2)]
        end
    end

    # this is the index of the selected value in the slider's range
    # selected_index = Node(1)
    # add the selected index to the attributes so it can be manipulated later
    attrs.selected_index = 1
    selected_index = attrs.selected_index

    # the fraction on the slider corresponding to the selected_index
    # this is only used after dragging
    sliderfraction = lift(selected_index, sliderrange) do i, r
        (i - 1) / (length(r) - 1)
    end

    dragging = Node(false)

    # what the slider actually displays currently (also during dragging when
    # the slider position is in an "invalid" position given the slider's range)
    displayed_sliderfraction = Node(0.0)

    on(sliderfraction) do frac
        # only update displayed fraction through sliderfraction if not dragging
        # dragging overrides the value so there is clear mouse interaction
        if !dragging[]
            displayed_sliderfraction[] = frac
        end
    end

    # when the range is changed, switch to closest value
    on(sliderrange) do rng
        selected_index[] = closest_index(rng, value[])
    end

    on(selected_index) do i
        value[] = sliderrange[][i]
    end

    # initialize slider value with closest from range
    selected_index[] = closest_index(sliderrange[], startvalue[])

    middlepoint = lift(endpoints, displayed_sliderfraction) do ep, sf
        Point2f(ep[1] .+ sf .* (ep[2] .- ep[1]))
    end

    linepoints = lift(endpoints, middlepoint) do eps, middle
        [eps[1], middle, middle, eps[2]]
    end

    linecolors = lift(color_active_dimmed, color_inactive) do ca, ci
        [ca, ci]
    end

    endbuttons = scatter!(topscene, endpoints, color = linecolors, 
        markersize = linewidth, strokewidth = 0, raw = true, inspectable = false)
    decorations[:endbuttons] = endbuttons

    linesegs = linesegments!(topscene, linepoints, color = linecolors, 
        linewidth = linewidth, raw = true, inspectable = false)
    decorations[:linesegments] = linesegs

    button_magnification = Node(1.0)
    buttonsize = @lift($linewidth * $button_magnification)
    button = scatter!(topscene, middlepoint, color = color_active, strokewidth = 0, 
        markersize = buttonsize, raw = true, inspectable = false)
    decorations[:button] = button

    mouseevents = addmouseevents!(topscene, layoutobservables.computedbbox)

    onmouseleftdrag(mouseevents) do event
        dragging[] = true
        dif = event.px - event.prev_px
        fraction = clamp(if horizontal[]
            (event.px[1] - endpoints[][1][1]) / (endpoints[][2][1] - endpoints[][1][1])
        else
            (event.px[2] - endpoints[][1][2]) / (endpoints[][2][2] - endpoints[][1][2])
        end, 0, 1)

        newindex = closest_fractionindex(sliderrange[], fraction)
        if snap[]
            fraction = (newindex - 1) / (length(sliderrange[]) - 1)
        end
        displayed_sliderfraction[] = fraction

        if selected_index[] != newindex
            selected_index[] = newindex
        end

        return Consume(true)
    end

    onmouseleftdragstop(mouseevents) do event
        dragging[] = false
        # adjust slider to closest legal value
        sliderfraction[] = sliderfraction[]
        linecolors[] = [color_active_dimmed[], color_inactive[]]
        return Consume(true)
    end

    onmouseleftdown(mouseevents) do event
        pos = event.px
        dim = horizontal[] ? 1 : 2
        frac = (pos[dim] - endpoints[][1][dim]) / (endpoints[][2][dim] - endpoints[][1][dim])
        selected_index[] = closest_fractionindex(sliderrange[], frac)
        # linecolors[] = [color_active[], color_inactive[]]
        return Consume(true)
    end

    onmouseleftdoubleclick(mouseevents) do event
        selected_index[] = closest_index(sliderrange[], startvalue[])
        return Consume(true)
    end

    onmouseenter(mouseevents) do event
        button_magnification[] = 1.25
        return Consume(false)
    end

    onmouseout(mouseevents) do event
        button_magnification[] = 1.0
        linecolors[] = [color_active_dimmed[], color_inactive[]]
        return Consume(false)
    end

    # trigger autosize through linewidth for first layout
    linewidth[] = linewidth[]

    Slider(fig_or_scene, layoutobservables, attrs, decorations)
end

function valueindex(sliderrange, value)
    for (i, val) in enumerate(sliderrange)
        if val == value
            return i
        end
    end
    nothing
end

function closest_fractionindex(sliderrange, fraction)
    n = length(sliderrange)
    onestepfrac = 1 / (n - 1)
    i = round(Int, fraction / onestepfrac) + 1
    min(max(i, 1), n)
end

function closest_index(sliderrange, value)
    for (i, val) in enumerate(sliderrange)
        if val == value
            return i
        end
    end
    # if the value wasn't found this way try inexact
    closest_index_inexact(sliderrange, value)
end

function closest_index_inexact(sliderrange, value)
    distance = Inf
    selected_i = 0
    for (i, val) in enumerate(sliderrange)
        newdist = abs(val - value)
        if newdist < distance
            distance = newdist
            selected_i = i
        end
    end
    selected_i
end

"""
Set the `slider` to the value in the slider's range that is closest to `value` and return this value.
"""
function set_close_to!(slider::Slider, value)
    closest = closest_index(slider.range[], value)
    slider.selected_index = closest
    slider.range[][closest]
end
