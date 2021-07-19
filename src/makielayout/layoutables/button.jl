function layoutable(::Type{Button}, fig_or_scene::FigureLike; bbox = nothing, kwargs...)

    scene = get_scene(fig_or_scene)

    default_attrs = default_attributes(Button, scene).attributes
    theme_attrs = subtheme(scene, :Button)
    attrs = merge!(merge!(Attributes(kwargs), theme_attrs), default_attrs)

    @extract attrs (padding, textsize, label, font, halign, valign, cornerradius,
        cornersegments, strokewidth, strokecolor, buttoncolor,
        labelcolor, labelcolor_hover, labelcolor_active,
        buttoncolor_active, buttoncolor_hover, clicks)

    decorations = Dict{Symbol, Any}()

    layoutobservables = LayoutObservables{Button}(attrs.width, attrs.height, attrs.tellwidth, attrs.tellheight,
        halign, valign, attrs.alignmode; suggestedbbox = bbox)

    textpos = Node(Point2f(0, 0))

    subarea = lift(layoutobservables.computedbbox) do bbox
        round_to_IRect2D(bbox)
    end
    subscene = Scene(scene, subarea, camera=campixel!)



    # buttonrect is without the left bottom offset of the bbox
    buttonrect = lift(layoutobservables.computedbbox) do bbox
        BBox(0, width(bbox), 0, height(bbox))
    end

    on(buttonrect) do rect
        textpos[] = Point2f(left(rect) + 0.5f0 * width(rect), bottom(rect) + 0.5f0 * height(rect))
    end

    roundedrectpoints = lift(roundedrectvertices, buttonrect, cornerradius, cornersegments)

    mousestate = Node(:out)

    bcolors = (; out = buttoncolor, active = buttoncolor_active, hover = buttoncolor_hover)
    bcolor = lift((s,_...)->bcolors[s][], Any, mousestate, values(bcolors)...)
    button = poly!(subscene, roundedrectpoints, strokewidth = strokewidth, strokecolor = strokecolor,
        color = bcolor, raw = true, inspectable = false)
    decorations[:button] = button



    lcolors = (; out = labelcolor, active = labelcolor_active, hover = labelcolor_hover)
    lcolor = lift((s,_...)->lcolors[s][], Any, mousestate, values(lcolors)...)
    labeltext = text!(subscene, label, position = textpos, textsize = textsize, font = font,
        color = lcolor, align = (:center, :center), raw = true, space = :data, inspectable = false)

    decorations[:label] = labeltext

    # move text in front of background to be sure it's not occluded
    translate!(labeltext, 0, 0, 1)


    onany(label, textsize, font, padding) do label, textsize, font, padding
        textbb = Rect2f(boundingbox(labeltext))
        autowidth = width(textbb) + padding[1] + padding[2]
        autoheight = height(textbb) + padding[3] + padding[4]
        layoutobservables.autosize[] = (autowidth, autoheight)
    end


    mouseevents = addmouseevents!(scene, layoutobservables.computedbbox)

    onmouseover(mouseevents) do _
        mousestate[] = :hover
        return Consume(false)
    end

    onmouseout(mouseevents) do _
        mousestate[] = :out
        return Consume(false)
    end

    onmouseleftup(mouseevents) do _
        mousestate[] = :hover
        return Consume(true)
    end

    onmouseleftdown(mouseevents) do _
        mousestate[] = :active
        clicks[] = clicks[] + 1
        return Consume(true)
    end

    label[] = label[]
    # trigger bbox
    layoutobservables.suggestedbbox[] = layoutobservables.suggestedbbox[]

    Button(fig_or_scene, layoutobservables, attrs, decorations)
end
