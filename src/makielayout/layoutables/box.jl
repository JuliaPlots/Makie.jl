function layoutable(::Type{Box}, fig_or_scene; bbox = nothing, kwargs...)

    topscene = get_topscene(fig_or_scene)

    default_attrs = default_attributes(Box, topscene).attributes
    theme_attrs = subtheme(topscene, :Box)
    attrs = merge!(merge!(Attributes(kwargs), theme_attrs), default_attrs)

    @extract attrs (color, visible, valign, halign, padding, strokewidth,
        strokevisible, strokecolor)

    layoutobservables = LayoutObservables{Box}(attrs.width, attrs.height, attrs.tellwidth, attrs.tellheight,
        halign, valign, attrs.alignmode; suggestedbbox = bbox)

    strokecolor_with_visibility = lift(strokecolor, strokevisible) do col, vis
        vis ? col : RGBAf(0, 0, 0, 0)
    end

    ibbox = @lift(round_to_Rect2i($(layoutobservables.computedbbox)))

    r = poly!(topscene, ibbox, color = color, visible = visible, raw = true,
        strokecolor = strokecolor_with_visibility, strokewidth = strokewidth, 
        inspectable = false)

    elements = Dict(:rect => r)

    # trigger bbox
    layoutobservables.suggestedbbox[] = layoutobservables.suggestedbbox[]

    Box(fig_or_scene, layoutobservables, attrs, elements)
end
