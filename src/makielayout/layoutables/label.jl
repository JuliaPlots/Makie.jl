function layoutable(::Type{Label}, fig_or_scene, text; kwargs...)
    layoutable(Label, fig_or_scene; text = text, kwargs...)
end

function layoutable(::Type{Label}, fig_or_scene; bbox = nothing, kwargs...)

    topscene = get_topscene(fig_or_scene)
    default_attrs = default_attributes(Label, topscene).attributes
    theme_attrs = subtheme(topscene, :Label)
    attrs = merge!(merge!(Attributes(kwargs), theme_attrs), default_attrs)

    @extract attrs (text, textsize, font, color, visible, halign, valign,
        rotation, padding)

    layoutobservables = LayoutObservables{Label}(attrs.width, attrs.height, attrs.tellwidth, attrs.tellheight,
        halign, valign, attrs.alignmode; suggestedbbox = bbox)

    textpos = Node(Point3f(0, 0, 0))

    # this is just a hack until boundingboxes in Makie are perfect
    alignnode = lift(halign, rotation) do h, rot
        # left align the text if it's not rotated and left aligned
        if rot == 0 && (h == :left || h == 0.0)
            (:left, :center)
        else
            (:center, :center)
        end
    end

    t = text!(topscene, text, position = textpos, textsize = textsize, font = font, color = color,
        visible = visible, align = alignnode, rotation = rotation, raw = true, space = :data, inspectable = false)

    textbb = Ref(BBox(0, 1, 0, 1))

    onany(text, textsize, font, rotation, padding) do text, textsize, font, rotation, padding
        textbb[] = Rect2f(boundingbox(t))
        autowidth = width(textbb[]) + padding[1] + padding[2]
        autoheight = height(textbb[]) + padding[3] + padding[4]
        layoutobservables.autosize[] = (autowidth, autoheight)
    end

    onany(layoutobservables.computedbbox, padding) do bbox, padding

        tw = width(textbb[])
        th = height(textbb[])

        box = bbox.origin[1]
        boy = bbox.origin[2]

        # this is also part of the hack to improve left alignment until
        # boundingboxes are perfect
        tx = if rotation[] == 0 && (halign[] == :left || halign[] == 0.0)
            box + padding[1]
        else
            box + padding[1] + 0.5 * tw
        end
        ty = boy + padding[3] + 0.5 * th

        textpos[] = Point3f(tx, ty, 0)
    end


    # trigger first update, otherwise bounds are wrong somehow
    text[] = text[]
    # trigger bbox
    layoutobservables.suggestedbbox[] = layoutobservables.suggestedbbox[]

    lt = Label(fig_or_scene, layoutobservables, attrs, Dict(:text => t))

    lt
end
