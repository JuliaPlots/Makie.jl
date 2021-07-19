function default_attributes(::Type{Menu}, scene)
    attrs, docdict, defaultdict = @documented_attributes begin
        "The height setting of the menu."
        height = Auto()
        "The width setting of the menu."
        width = nothing
        "Controls if the parent layout can adjust to this element's width"
        tellwidth = true
        "Controls if the parent layout can adjust to this element's height"
        tellheight = true
        "The horizontal alignment of the menu in its suggested bounding box."
        halign = :center
        "The vertical alignment of the menu in its suggested bounding box."
        valign = :center
        "The alignment of the menu in its suggested bounding box."
        alignmode = Inside()
        "Index of selected item"
        i_selected = 0
        "Selected item value"
        selection = nothing
        "Is the menu showing the available options"
        is_open = false
        "Cell color when hovered"
        cell_color_hover = COLOR_ACCENT_DIMMED[]
        "Cell color when active"
        cell_color_active = COLOR_ACCENT[]
        "Cell color when inactive even"
        cell_color_inactive_even = RGBf(0.97, 0.97, 0.97)
        "Cell color when inactive odd"
        cell_color_inactive_odd = RGBf(0.97, 0.97, 0.97)
        "Selection cell color when inactive"
        selection_cell_color_inactive = RGBf(0.94, 0.94, 0.94)
        "Color of the dropdown arrow"
        dropdown_arrow_color = (:black, 0.2)
        "Size of the dropdown arrow"
        dropdown_arrow_size = 12px
        "The list of options selectable in the menu. This can be any iterable of a mixture of strings and containers with one string and one other value. If an entry is just a string, that string is both label and selection. If an entry is a container with one string and one other value, the string is the label and the other value is the selection."
        options = ["no options"]
        "Font size of the cell texts"
        textsize = lift_parent_attribute(scene, :fontsize, 16f0)
        "Padding of entry texts"
        textpadding = (10, 10, 10, 10)
        "Color of entry texts"
        textcolor = :black
        "The opening direction of the menu (:up or :down)"
        direction = automatic
        "The default message prompting a selection when i == 0"
        prompt = "Select..."
    end
    (attributes = attrs, documentation = docdict, defaults = defaultdict)
end

@doc """
    Menu(parent::Scene; bbox = nothing, kwargs...)

Create a drop-down menu with multiple selectable options. You can pass options
with the keyword argument `options`. Options are given as an iterable of elements.
For each element, the option label in the menu is determined with `optionlabel(element)`
and the option value with `optionvalue(element)`. These functions can be
overloaded for custom types. The default is that tuples of two elements are expected to be label and value,
where `string(label)` is used as the label, while for all other objects, label = `string(object)` and value = object.

When an item is selected in the menu, the menu's `selection` attribute is set to
`optionvalue(selected_element)`.

If the menu is located close to the lower scene border, you can change its open
direction to `direction = :up`.

# Example

Menu with string entries:

```julia
menu1 = Menu(scene, options = ["first", "second", "third"])
```

Menu with two-element entries, label and function:

```julia
funcs = [sin, cos, tan]
labels = ["Sine", "Cosine", "Tangens"]

menu2 = Menu(scene, options = zip(labels, funcs))
```

Lifting on the selection value:

```julia
on(menu2.selection) do func
    # do something with the selected function
end
```

Menu has the following attributes:

$(let
    _, docs, defaults = default_attributes(Menu, nothing)
    docvarstring(docs, defaults)
end)
"""
Menu


function layoutable(::Type{Menu}, fig_or_scene; bbox = nothing, kwargs...)

    topscene = get_topscene(fig_or_scene)

    default_attrs = default_attributes(Menu, topscene).attributes
    theme_attrs = subtheme(topscene, :Menu)
    attrs = merge!(merge!(Attributes(kwargs), theme_attrs), default_attrs)

    @extract attrs (halign, valign, i_selected, is_open, cell_color_hover,
        cell_color_inactive_even, cell_color_inactive_odd, dropdown_arrow_color,
        options, dropdown_arrow_size, textsize, selection, cell_color_active,
        textpadding, selection_cell_color_inactive, textcolor, direction, prompt)

    decorations = Dict{Symbol, Any}()

    layoutobservables = LayoutObservables{Menu}(attrs.width, attrs.height, attrs.tellwidth, attrs.tellheight,
    halign, valign, attrs.alignmode; suggestedbbox = bbox)


    sceneheight = Node(20.0)

    # the direction is auto-chosen as up if there is too little space below and if the space below
    # is smaller than above
    _direction = lift(Any, layoutobservables.computedbbox, direction, sceneheight) do bb, dir, sh
        if dir == Makie.automatic
            pxa = pixelarea(topscene)[]
            if (sh > abs(bottom(pxa) - bottom(bb))) && (abs(bottom(pxa) - bottom(bb)) < abs(top(pxa) - top(bb)))
                :up
            else
                :down
            end
        else
            dir
        end
    end

    scenearea = lift(layoutobservables.computedbbox, sceneheight, _direction) do bbox, h, d
        round_to_IRect2D(BBox(
            left(bbox),
            right(bbox),
            d == :down ? top(bbox) - h : bottom(bbox),
            d == :down ? top(bbox) : bottom(bbox) + h))
    end


    scene = Scene(topscene, scenearea, raw = true, camera = campixel!)
    translate!(scene, 0, 0, 21)

    contentgrid = GridLayout(
        bbox = lift(x -> Rect2f(Makie.zero_origin(x)), scenearea),
        valign = @lift($_direction == :down ? :top : :bottom))

    selectionrect = Box(scene, width = nothing, height = nothing,
        color = selection_cell_color_inactive[], strokewidth = 0)


    optionstrings = Ref{Vector{String}}(optionlabel.(options[]))

    selected_text = lift(prompt, i_selected) do prompt, i_selected
        if i_selected == 0
            prompt
        else
            optionstrings[][i_selected]
        end
    end

    selectiontext = Label(scene, selected_text, tellwidth = false, halign = :left,
        padding = textpadding, textsize = textsize, color = textcolor)


    allrects = Vector{Box}(undef, 0)
    alltexts = Vector{Label}(undef, 0)
    mouseeventhandles = Vector{MouseEventHandle}(undef, 0)

    on(options) do options
        # Make sure i_selected is on a valid index when the contentgrid updates
        old_selection = selection[]
        old_selected_text = selected_text[]
        should_search = i_selected[] > 0
        i_selected.val = 0

        # update string ref before reassembly
        optionstrings[] = optionlabel.(options)

        _reassemble_menu(
            scene, selectionrect, selectiontext,
            allrects, alltexts, mouseeventhandles,
            contentgrid, attrs, optionstrings
        )


        new_i = 0 # default to nothing selected
        # if there is a current selection, check if it still exists in the new options
        if should_search
            for (i, o) in enumerate(options)
                # if one of the new options is equivalent to the old options, we choose it for continuity
                if old_selection == optionvalue(o) && old_selected_text == optionlabel(o)
                    new_i = i
                    break
                end
            end
        end

        # trigger eventual selection actions
        i_selected[] = new_i
    end

    # reassemble for the first time
    _reassemble_menu(
        scene, selectionrect, selectiontext,
        allrects, alltexts, mouseeventhandles,
        contentgrid, attrs, optionstrings
    )


    dropdown_arrow = scatter!(scene,
        lift(x -> [Point2f(width(x) - 20, (top(x) + bottom(x)) / 2)], selectionrect.layoutobservables.computedbbox),
        marker = @lift($is_open ? '▴' : '▾'),
        markersize = dropdown_arrow_size,
        color = dropdown_arrow_color,
        strokecolor = :transparent,
        raw = true, inspectable = false)
    translate!(dropdown_arrow, 0, 0, 1)


    onany(i_selected, is_open, contentgrid.layoutobservables.autosize) do i, open, gridautosize

        h = if i == 0
            selectiontext.layoutobservables.autosize[][2]
        else
            alltexts[i+1].layoutobservables.autosize[][2]
        end
        layoutobservables.autosize[] = (nothing, h)
        autosize = layoutobservables.autosize[]

        (isnothing(gridautosize[2]) || isnothing(autosize[2])) && return

        if open
            sceneheight[] = gridautosize[2]
        else
            sceneheight[] = alltexts[2].layoutobservables.autosize[][2]
        end
    end


    on(_direction) do d
        if d == :down
            contentgrid[:v] = allrects
            contentgrid[:v] = alltexts
        elseif d == :up
            contentgrid[:v] = vcat(allrects[2:end], allrects[1:1])
            contentgrid[:v] = vcat(alltexts[2:end], alltexts[1:1])
        else
            error("Invalid direction $d. Possible values are :up and :down.")
        end
    end

    # trigger size without triggering selection
    i_selected[] = i_selected[]
    is_open[] = is_open[]

    on(i_selected) do i
        if i == 0
            selection[] = nothing
        else
            # collect in case options is a zip or other generator without indexing
            option = collect(options[])[i]

            # only update the selection value if the new value is actually different
            # this is because i_selected can also be changed when the options themselves
            # are mutated, and there could still be the same option in the list
            # just at a different place, so that should not trigger a selection
            newvalue = optionvalue(option)
            if selection[] != newvalue
                selection[] = newvalue
            end
        end
    end

    # close the menu if the user clicks somewhere else
    onmousedownoutside(addmouseevents!(scene, priority=Int8(61))) do events
        if is_open[]
            is_open[] = !is_open[]
        end
        return Consume(false)
    end

    # trigger bbox
    layoutobservables.suggestedbbox[] = layoutobservables.suggestedbbox[]
    # notify(direction)

    Menu(fig_or_scene, layoutobservables, attrs, decorations)
end

function _reassemble_menu(
        scene, selectionrect, selectiontext,
        allrects, alltexts, mouseeventhandles,
        contentgrid, attributes, optionstrings
    )

    @extract attributes (
        cell_color_inactive_even, cell_color_inactive_odd, textsize, textcolor,
        textpadding, cell_color_hover, selection_cell_color_inactive,
        cell_color_active, is_open, options, i_selected
    )

    # Clear previous options plots
    for i in length(allrects):-1:2
        delete!(allrects[i])
        delete!(alltexts[i])
    end

    # remove all mouse actions previously connected to rects / texts
    foreach(clear!, mouseeventhandles)

    trim!(contentgrid)

    # Repopulate allrects and all alltexts
    resize!(allrects, length(options[])+1)
    resize!(alltexts, length(options[])+1)

    allrects[1] = selectionrect
    alltexts[1] = selectiontext

    for i in 1:length(options[])
        allrects[i+1] = Box(
            scene, width = nothing, height = nothing,
            color = iseven(i) ? cell_color_inactive_even[] : cell_color_inactive_odd[],
            strokewidth = 0, visible = is_open
        )

        alltexts[i+1] = Label(
            scene, optionstrings[][i], halign = :left, tellwidth = false,
            textsize = textsize, color = textcolor,
            padding = textpadding, visible = is_open
        )
    end


    contentgrid[1:length(allrects), 1] = allrects
    contentgrid[1:length(alltexts), 1] = alltexts

    rowgap!(contentgrid, 0)

    resize!(mouseeventhandles, length(alltexts))
    map!(mouseeventhandles, allrects) do r
        addmouseevents!(scene, r.layoutobservables.computedbbox, priority=Int8(60))
    end

    # create mouse events for each menu entry rect / text combo
    for (i, (mouseeventhandle, r, t)) in enumerate(zip(mouseeventhandles, allrects, alltexts))
        onmouseover(mouseeventhandle) do _
            r.visible[] || return Consume(false)
            (i == i_selected[]+1) && return Consume(false)
            r.color = cell_color_hover[]
            return Consume(false)
        end

        onmouseout(mouseeventhandle) do _
            r.visible[] || return Consume(false)
            # do nothing for selected items
            (i == i_selected[]+1) && return Consume(false)
            if i == 1
                r.color = selection_cell_color_inactive[]
            else
                i_option = i - 1
                r.color = iseven(i_option) ? cell_color_inactive_even[] : cell_color_inactive_odd[]
            end
            return Consume(false)
        end

        onmouseleftdown(mouseeventhandle) do _
            r.visible[] || return Consume(false)
            r.color = cell_color_active[]
            if is_open[]
                # first item is already selected
                if i > 1
                    # de-highlight previously selected
                    if i_selected[] != 0
                        allrects[i_selected[] + 1].color = cell_color_inactive_even[]
                    end
                    i_selected[] = i - 1
                end
            end
            is_open[] = !is_open[]
            return Consume(true)
        end
    end

    nothing
end

function optionlabel(option)
    string(option)
end

function optionlabel(option::Tuple{Any, Any})
    string(option[1])
end

function optionvalue(option)
    option
end

function optionvalue(option::Tuple{Any, Any})
    option[2]
end
