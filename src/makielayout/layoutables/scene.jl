function Makie.plot!(
        lscene::LScene, P::Makie.PlotFunc,
        attributes::Makie.Attributes, args...;
        kw_attributes...)

    plot = Makie.plot!(lscene.scene, P, attributes, args...; kw_attributes...)

    plot
end

function Makie.plot!(P::Makie.PlotFunc, ls::LScene, args...; kw_attributes...)
    attributes = Makie.Attributes(kw_attributes)
    Makie.plot!(ls, P, attributes, args...)
end


function layoutable(::Type{LScene}, fig_or_scene; bbox = nothing, scenekw = NamedTuple(), kwargs...)

    topscene = get_topscene(fig_or_scene)

    default_attrs = default_attributes(LScene, topscene).attributes
    theme_attrs = subtheme(topscene, :LScene)
    attrs = merge!(merge!(Attributes(kwargs), theme_attrs), default_attrs)

    layoutobservables = LayoutObservables{LScene}(attrs.width, attrs.height, attrs.tellwidth, attrs.tellheight,
        attrs.halign, attrs.valign, attrs.alignmode; suggestedbbox = bbox)

    # We also set `raw = false` because otherwise the scene will not automatically
    # pick a camera and draw axis.
    scenekw = merge((raw = false, clear = false), scenekw)
    scene = Scene(topscene, lift(round_to_Rect2i, layoutobservables.computedbbox); scenekw...)

    ls = LScene(fig_or_scene, layoutobservables, attrs, Dict{Symbol, Any}(), scene)

    ls
end

function Base.delete!(ax::LScene, plot::AbstractPlot)
    delete!(ax.scene, plot)
    ax
end

can_be_current_axis(ls::LScene) = true
