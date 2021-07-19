function layoutable(::Type{Legend},
        fig_or_scene,
        entry_groups::Node{Vector{Tuple{Optional{<:AbstractString}, Vector{LegendEntry}}}};
        bbox = nothing, kwargs...)

    topscene = get_topscene(fig_or_scene)

    default_attrs = default_attributes(Legend, topscene).attributes
    theme_attrs = subtheme(topscene, :Legend)
    attrs = merge!(merge!(Attributes(kwargs), theme_attrs), default_attrs)

    @extract attrs (
        halign, valign, padding, margin,
        titlefont, titlesize, titlehalign, titlevalign, titlevisible, titlecolor,
        labelsize, labelfont, labelcolor, labelhalign, labelvalign,
        bgcolor, framecolor, framewidth, framevisible,
        patchsize, # the side length of the entry patch area
        nbanks,
        colgap, rowgap, patchlabelgap,
        titlegap, groupgap,
        orientation,
        titleposition,
        gridshalign, gridsvalign,
    )

    decorations = Dict{Symbol, Any}()

    layoutobservables = LayoutObservables{Legend}(attrs.width, attrs.height, attrs.tellwidth, attrs.tellheight,
        halign, valign, attrs.alignmode; suggestedbbox = bbox)

    scenearea = lift(round_to_IRect2D, layoutobservables.computedbbox)

    scene = Scene(topscene, scenearea, raw = true, camera = campixel!)

    # the rectangle in which the legend is drawn when margins are removed
    legendrect = @lift(
        BBox($margin[1], width($scenearea) - $margin[2],
             $margin[3], height($scenearea) - $margin[4]))

    decorations[:frame] = poly!(scene,
        @lift(enlarge($legendrect, repeat([-$framewidth/2], 4)...)),
        color = bgcolor, strokewidth = framewidth, visible = framevisible,
        strokecolor = framecolor, raw = true, inspectable = false)

    # the grid containing all content
    grid = GridLayout(bbox = legendrect, alignmode = Outside(padding[]...))

    # while the entries are being manipulated through code, this Ref value is set to
    # true so the GridLayout doesn't update itself to save time
    manipulating_grid = Ref(false)

    on(padding) do p
        grid.alignmode = Outside(p...)
        relayout()
    end

    update_grid = Node(true)
    onany(update_grid, margin) do _, margin
        if manipulating_grid[]
            return
        end
        w = GridLayoutBase.determinedirsize(grid, GridLayoutBase.Col())
        h = GridLayoutBase.determinedirsize(grid, GridLayoutBase.Row())
        if !any(isnothing.((w, h)))
            layoutobservables.autosize[] = (w + sum(margin[1:2]), h + sum(margin[3:4]))
        end
    end

    # these arrays store all the plot objects that the legend entries need
    titletexts = Optional{Label}[]
    entrytexts = [Label[]]
    entryplots = [[AbstractPlot[]]]
    entryrects = [Box[]]

    decorations[:titletexts] = titletexts
    decorations[:entrytexts] = entrytexts
    decorations[:entryplots] = entryplots
    decorations[:entryrects] = entryrects


    function relayout()
        manipulating_grid[] = true

        rowcol(n) = ((n - 1) ÷ nbanks[] + 1, (n - 1) % nbanks[] + 1)

        for i in length(grid.content):-1:1
            GridLayoutBase.remove_from_gridlayout!(grid.content[i])
        end

        # loop through groups
        for g in 1:length(entry_groups[])
            title = titletexts[g]
            etexts = entrytexts[g]
            erects = entryrects[g]

            subgl = if orientation[] == :vertical
                if titleposition[] == :left
                    isnothing(title) || (grid[g, 1] = title)
                    grid[g, 2] = GridLayout(halign = gridshalign[], valign = gridsvalign[])
                elseif titleposition[] == :top
                    isnothing(title) || (grid[2g - 1, 1] = title)
                    grid[2g, 1] = GridLayout(halign = gridshalign[], valign = gridsvalign[])
                end
            elseif orientation[] == :horizontal
                if titleposition[] == :left
                    isnothing(title) || (grid[1, 2g-1] = title)
                    grid[1, 2g] = GridLayout(halign = gridshalign[], valign = gridsvalign[])
                elseif titleposition[] == :top
                    isnothing(title) || (grid[1, g] = title)
                    grid[2, g] = GridLayout(halign = gridshalign[], valign = gridsvalign[])
                end
            end

            for (n, (et, er)) in enumerate(zip(etexts, erects))
                i, j = orientation[] == :vertical ? rowcol(n) : reverse(rowcol(n))
                subgl[i, 2j-1] = er
                subgl[i, 2j] = et
            end

            rowgap!(subgl, rowgap[])
            for c in 1:subgl.ncols-1
                colgap!(subgl, c, c % 2 == 1 ? patchlabelgap[] : colgap[])
            end
        end

        for r in 1:grid.nrows-1
            if orientation[] == :horizontal
                if titleposition[] == :left
                    # nothing
                elseif titleposition[] == :top
                    rowgap!(grid, r, titlegap[])
                end
            elseif orientation[] == :vertical
                if titleposition[] == :left
                    rowgap!(grid, r, groupgap[])
                elseif titleposition[] == :top
                    rowgap!(grid, r, r % 2 == 1 ? titlegap[] : groupgap[])
                end
            end
        end
        for c in 1:grid.ncols-1
            if orientation[] == :horizontal
                if titleposition[] == :left
                    colgap!(grid, c, c % 2 == 1 ? titlegap[] : groupgap[])
                elseif titleposition[] == :top
                    colgap!(grid, c, groupgap[])
                end
            elseif orientation[] == :vertical
                if titleposition[] == :left
                    colgap!(grid, c, titlegap[])
                elseif titleposition[] == :top
                    # nothing here
                end
            end
        end


        # delete unused rows and columns
        trim!(grid)


        manipulating_grid[] = false
        notify(update_grid)

        # translate the legend forward so it is above the standard axis content
        # which is at zero. this will not really work if the legend should be
        # above a 3d plot, but for now this hack is ok.
        translate!(scene, (0, 0, 10))
    end

    onany(nbanks, titleposition, rowgap, colgap, patchlabelgap, groupgap, titlegap,
            titlevisible, orientation, gridshalign, gridsvalign) do args...
        relayout()
    end

    on(entry_groups) do entry_groups
        # first delete all existing labels and patches

        for t in titletexts
            !isnothing(t) && delete!(t)
        end
        empty!(titletexts)

        [delete!.(etexts) for etexts in entrytexts]
        empty!(entrytexts)

        [delete!.(erects) for erects in entrytexts]
        empty!(entryrects)

        # delete patch plots
        for eplotgroup in entryplots
            for eplots in eplotgroup
                # each entry can have a vector of patch plots
                delete!.(scene, eplots)
            end
        end
        empty!(entryplots)

        # the attributes for legend entries that the legend itself carries
        # these serve as defaults unless the legendentry gets its own value set
        preset_attrs = extractattributes(attrs, LegendEntry)

        for (title, entries) in entry_groups

            if isnothing(title)
                # in case a group has no title
                push!(titletexts, nothing)
            else
                push!(titletexts, Label(scene, text = title, font = titlefont, color = titlecolor,
                    textsize = titlesize, halign = titlehalign, valign = titlevalign, inspectable = false))
            end

            etexts = []
            erects = []
            eplots = []
            for (i, e) in enumerate(entries)
                # fill missing entry attributes with those carried by the legend
                merge!(e.attributes, preset_attrs)

                # create the label
                push!(etexts, Label(scene,
                    text = e.label, textsize = e.labelsize, font = e.labelfont,
                    color = e.labelcolor, halign = e.labelhalign, valign = e.labelvalign
                    ))

                # create the patch rectangle
                rect = Box(scene, color = e.patchcolor, strokecolor = e.patchstrokecolor,
                    strokewidth = e.patchstrokewidth,
                    width = lift(x -> x[1], e.patchsize),
                    height = lift(x -> x[2], e.patchsize))
                push!(erects, rect)

                # plot the symbols belonging to this entry
                symbolplots = AbstractPlot[]
                for element in e.elements
                    append!(symbolplots,
                        legendelement_plots!(scene, element,
                            rect.layoutobservables.computedbbox, e.attributes))
                end

                push!(eplots, symbolplots)
            end
            push!(entrytexts, etexts)
            push!(entryrects, erects)
            push!(entryplots, eplots)
        end
        relayout()
    end


    # trigger suggestedbbox
    layoutobservables.suggestedbbox[] = layoutobservables.suggestedbbox[]

    leg = Legend(fig_or_scene, layoutobservables, attrs, decorations, entry_groups)
    # trigger first relayout
    entry_groups[] = entry_groups[]
    leg
end


function legendelement_plots!(scene, element::MarkerElement, bbox::Node{Rect2f}, defaultattrs::Attributes)
    merge!(element.attributes, defaultattrs)
    attrs = element.attributes

    fracpoints = attrs.markerpoints
    points = @lift(fractionpoint.(Ref($bbox), $fracpoints))
    scat = scatter!(scene, points, color = attrs.markercolor, marker = attrs.marker,
        markersize = attrs.markersize,
        strokewidth = attrs.markerstrokewidth,
        strokecolor = attrs.markerstrokecolor, raw = true, inspectable = false)
    [scat]
end

function legendelement_plots!(scene, element::LineElement, bbox::Node{Rect2f}, defaultattrs::Attributes)
    merge!(element.attributes, defaultattrs)
    attrs = element.attributes

    fracpoints = attrs.linepoints
    points = @lift(fractionpoint.(Ref($bbox), $fracpoints))
    lin = lines!(scene, points, linewidth = attrs.linewidth, color = attrs.linecolor,
        linestyle = attrs.linestyle,
        raw = true, inspectable = false)
    [lin]
end

function legendelement_plots!(scene, element::PolyElement, bbox::Node{Rect2f}, defaultattrs::Attributes)
    merge!(element.attributes, defaultattrs)
    attrs = element.attributes

    fracpoints = attrs.polypoints
    points = @lift(fractionpoint.(Ref($bbox), $fracpoints))
    pol = poly!(scene, points, strokewidth = attrs.polystrokewidth, color = attrs.polycolor,
        strokecolor = attrs.polystrokecolor,
        raw = true, inspectable = false)
    [pol]
end

function Base.getproperty(lentry::LegendEntry, s::Symbol)
    if s in fieldnames(LegendEntry)
        getfield(lentry, s)
    else
        lentry.attributes[s]
    end
end

function Base.setproperty!(lentry::LegendEntry, s::Symbol, value)
    if s in fieldnames(LegendEntry)
        setfield!(lentry, s, value)
    else
        lentry.attributes[s][] = value
    end
end

function Base.propertynames(lentry::LegendEntry)
    [fieldnames(T)..., keys(lentry.attributes)...]
end

legendelements(le::LegendElement, legend) = LegendElement[le]
legendelements(les::AbstractArray{<:LegendElement}, legend) = LegendElement[les...]


function LegendEntry(label::AbstractString, contentelements::AbstractArray, legend; kwargs...)
    attrs = Attributes(label = label)

    kwargattrs = Attributes(kwargs)
    merge!(attrs, kwargattrs)

    elems = vcat(legendelements.(contentelements, Ref(legend))...)
    LegendEntry(elems, attrs)
end

function LegendEntry(label::AbstractString, contentelement, legend; kwargs...)
    attrs = Attributes(label = label)

    kwargattrs = Attributes(kwargs)
    merge!(attrs, kwargattrs)

    elems = legendelements(contentelement, legend)
    LegendEntry(elems, attrs)
end


function LineElement(;kwargs...)
    _legendelement(LineElement, Attributes(kwargs))
end

function MarkerElement(;kwargs...)
    _legendelement(MarkerElement, Attributes(kwargs))
end

function PolyElement(;kwargs...)
    _legendelement(PolyElement, Attributes(kwargs))
end

function _legendelement(T::Type{<:LegendElement}, a::Attributes)
    _rename_attributes!(T, a)
    T(a)
end

_renaming_mapping(::Type{LineElement}) = Dict(
    :points => :linepoints,
    :color => :linecolor,
)
_renaming_mapping(::Type{MarkerElement}) = Dict(
    :points => :markerpoints,
    :color => :markercolor,
    :strokewidth => :markerstrokewidth,
    :strokecolor => :markerstrokecolor,
)
_renaming_mapping(::Type{PolyElement}) = Dict(
    :points => :polypoints,
    :color => :polycolor,
    :strokewidth => :polystrokewidth,
    :strokecolor => :polystrokecolor,
)

function _rename_attributes!(T, a)
    m = _renaming_mapping(T)
    for (key, val) in pairs(a)
        if haskey(m, key)
            newkey = m[key]
            if haskey(a, newkey)
                error("Can't rename $key to $newkey as $newkey already exists in attributes.")
            end
            a[newkey] = pop!(a, key)
        end
    end
    a
end


function scalar_lift(attr, default)
    lift(Any, attr, default) do at, def
        Makie.is_scalar_attribute(at) ? at : def
    end
end

function legendelements(plot::Union{Lines, LineSegments}, legend)
    LegendElement[LineElement(
        color = scalar_lift(plot.color, legend.linecolor),
        linestyle = scalar_lift(plot.linestyle, legend.linestyle),
        linewidth = scalar_lift(plot.linewidth, legend.linewidth))]
end


function legendelements(plot::Scatter, legend)
    LegendElement[MarkerElement(
        color = scalar_lift(plot.color, legend.markercolor),
        marker = scalar_lift(plot.marker, legend.marker),
        markersize = scalar_lift(plot.markersize, legend.markersize),
        strokewidth = scalar_lift(plot.strokewidth, legend.markerstrokewidth),
        strokecolor = scalar_lift(plot.strokecolor, legend.markerstrokecolor),
    )]
end

function legendelements(plot::Union{Poly, Violin, BoxPlot, CrossBar, Density}, legend)
    LegendElement[PolyElement(
        color = scalar_lift(plot.color, legend.polycolor),
        strokecolor = scalar_lift(plot.strokecolor, legend.polystrokecolor),
        strokewidth = scalar_lift(plot.strokewidth, legend.polystrokewidth),
    )]
end

function legendelements(plot::Band, legend)
    # there seems to be no stroke for Band, so we set it invisible
    LegendElement[PolyElement(polycolor = scalar_lift(plot.color, legend.polystrokecolor), polystrokecolor = :transparent, polystrokewidth = 0)]
end

# if there is no specific overload available, we go through the child plots and just stack
# those together as a simple fallback
function legendelements(plot, legend)::Vector{LegendElement}
    if isempty(plot.plots)
        error("No child plot elements found in plot of type $(typeof(plot)) but also no `legendelements` method defined.")
    end
    reduce(vcat, [legendelements(childplot, legend) for childplot in plot.plots])
end

function Base.getproperty(legendelement::T, s::Symbol) where T <: LegendElement
    if s in fieldnames(T)
        getfield(legendelement, s)
    else
        legendelement.attributes[s]
    end
end

function Base.setproperty!(legendelement::T, s::Symbol, value) where T <: LegendElement
    if s in fieldnames(T)
        setfield!(legendelement, s, value)
    else
        legendelement.attributes[s][] = value
    end
end

function Base.propertynames(legendelement::T) where T <: LegendElement
    [fieldnames(T)..., keys(legendelement.attributes)...]
end



"""
    Legend(
        fig_or_scene,
        contents::AbstractArray,
        labels::AbstractArray{<:AbstractString},
        title::Optional{<:AbstractString} = nothing;
        kwargs...)

Create a legend from `contents` and `labels` where each label is associated to
one content element. A content element can be an `AbstractPlot`, an array of
`AbstractPlots`, a `LegendElement`, or any other object for which the
`legendelements` method is defined.
"""
function layoutable(::Type{Legend}, fig_or_scene,
        contents::AbstractArray,
        labels::AbstractArray{<:AbstractString},
        title::Optional{<:AbstractString} = nothing;
        kwargs...)

    if length(contents) != length(labels)
        error("Number of elements not equal: $(length(contents)) content elements and $(length(labels)) labels.")
    end

    entrygroups = Node{Vector{EntryGroup}}([])
    legend = layoutable(Legend, fig_or_scene, entrygroups; kwargs...)
    entries = [LegendEntry(label, content, legend) for (content, label) in zip(contents, labels)]
    entrygroups[] = [(title, entries)]
    legend
end



"""
    Legend(
        fig_or_scene,
        contentgroups::AbstractArray{<:AbstractArray},
        labelgroups::AbstractArray{<:AbstractArray},
        titles::AbstractArray{<:Optional{<:AbstractString}};
        kwargs...)

Create a multi-group legend from `contentgroups`, `labelgroups` and `titles`.
Each group from `contentgroups` and `labelgroups` is associated with one title
from `titles` (a title can be `nothing` to hide it).

Within each group, each content element is associated with one label. A content
element can be an `AbstractPlot`, an array of `AbstractPlots`, a `LegendElement`,
or any other object for which the `legendelements` method is defined.
"""
function layoutable(::Type{Legend}, fig_or_scene,
        contentgroups::AbstractArray{<:AbstractArray},
        labelgroups::AbstractArray{<:AbstractArray},
        titles::AbstractArray{<:Optional{<:AbstractString}};
        kwargs...)

    if !(length(titles) == length(contentgroups) == length(labelgroups))
        error("Number of elements not equal: $(length(titles)) titles, $(length(contentgroups)) content groups and $(length(labelgroups)) label groups.")
    end


    entrygroups = Node{Vector{EntryGroup}}([])
    legend = layoutable(Legend, fig_or_scene, entrygroups; kwargs...)
    entries = [[LegendEntry(l, pg, legend) for (l, pg) in zip(labelgroup, contentgroup)]
        for (labelgroup, contentgroup) in zip(labelgroups, contentgroups)]
    entrygroups[] = [(t, en) for (t, en) in zip(titles, entries)]
    legend
end


"""
    Legend(fig_or_scene, axis::Union{Axis, Scene, LScene}, title = nothing; merge = false, unique = false, kwargs...)

Create a single-group legend with all plots from `axis` that have the
attribute `label` set.

If `merge` is `true`, all plot objects with the same label will be layered on top of each other into one legend entry.
If `unique` is `true`, all plot objects with the same plot type and label will be reduced to one occurance.
"""
function layoutable(::Type{Legend}, fig_or_scene, axis::Union{Axis, Scene, LScene}, title = nothing; merge = false, unique = false, kwargs...)
    plots, labels = get_labeled_plots(axis, merge = merge, unique = unique)
    isempty(plots) && error("There are no plots with labels in the given axis that can be put in the legend. Supply labels to plotting functions like `plot(args...; label = \"My label\")`")
    layoutable(Legend, fig_or_scene, plots, labels, title; kwargs...)
end

function get_labeled_plots(ax; merge::Bool, unique::Bool)
    lplots = filter(get_plots(ax)) do plot
        haskey(plot.attributes, :label)
    end
    labels = map(lplots) do l
        l.label[]
    end

    # filter out plots with same plot type and label
    if unique
        plots_labels = Base.unique(((p, l),) -> (typeof(p), l), zip(lplots, labels))
        lplots = first.(plots_labels)
        labels = last.(plots_labels)
    end

    if merge
        ulabels = Base.unique(labels)
        mergedplots = [[lp for (i, lp) in enumerate(lplots) if labels[i] == ul]
            for ul in ulabels]

        lplots, labels = mergedplots, ulabels
    end

    lplots, labels
end

get_plots(p::AbstractPlot) = [p]
get_plots(ax::Axis) = get_plots(ax.scene)
get_plots(lscene::LScene) = get_plots(lscene.scene)
function get_plots(scene::Scene)
    plots = AbstractPlot[]
    for p in scene.plots
        append!(plots, get_plots(p))
    end
    return plots
end

# convenience constructor for axis legend
axislegend(ax = current_axis(); kwargs...) = axislegend(ax, ax; kwargs...)

axislegend(title::AbstractString; kwargs...) = axislegend(current_axis(), current_axis(), title; kwargs...)

"""
    axislegend(ax, args...; position = :rt, kwargs...)
    axislegend(ax, args...; position = (1, 1), kwargs...)
    axislegend(ax = current_axis(); kwargs...)
    axislegend(title::AbstractString; kwargs...)

Create a legend that sits inside an Axis's plot area.

The position can be a Symbol where the first letter controls the horizontal
alignment and can be l, r or c, and the second letter controls the vertical
alignment and can be t, b or c. Or it can be a tuple where the first
element is set as the Legend's halign and the second element as its valign.
"""
function axislegend(ax, args...; position = :rt, kwargs...)
    Legend(ax.parent, args...;
        bbox = ax.scene.px_area,
        margin = (10, 10, 10, 10),
        legend_position_to_aligns(position)...,
        kwargs...)
end

function legend_position_to_aligns(s::Symbol)
    p = string(s)
    length(p) != 2 && throw(ArgumentError("Position symbol must have length == 2"))

    haligns = Dict(
        'l' => :left,
        'r' => :right,
        'c' => :center,
    )
    haskey(haligns, p[1]) || throw(ArgumentError("First letter can be l, r or c, not $(p[1])."))

    valigns = Dict(
        't' => :top,
        'b' => :bottom,
        'c' => :center,
    )
    haskey(valigns, p[2]) || throw(ArgumentError("Second letter can be b, t or c, not $(p[2])."))

    (halign = haligns[p[1]], valign = valigns[p[2]])
end

function legend_position_to_aligns(t::Tuple{Any, Any})
    (halign = t[1], valign = t[2])
end
