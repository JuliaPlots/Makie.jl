# Inspecting Data

Makie provides a data inspection tool via `DataInspector(x)` where x can be a
figure, axis or scene. With it you get a floating tooltip with relevant
information for various plots by hovering over one of its elements.

By default the inspector will be able to pick any plot other than `text` and
`volume` based plots. If you wish to ignore a plot, you can set its attribute
`plot.inspectable[] = false`. With that the next closest plot (in range) will be
picked.

## Attributes of `DataInspector`

The `inspector = DataInspector(fig)` contains the following attributes:

- `range = 10`: Controls the snapping range for selecting an element of a plot.
- `enabled = true`: Disables inspection of plots when set to false. Can also be adjusted with `enable!(inspector)` and `disable!(inspector)`.
- `text_padding = Vec4f(5, 5, 3, 3)`: Padding for the box drawn around the tooltip text. (left, right, bottom, top)
- `text_align = (:left, :bottom)`: Alignment of text within the tooltip. This does not affect the alignment of the tooltip relative to the cursor.
- `textcolor = :black`: Tooltip text color.
- `textsize = 20`: Tooltip text size.
- `font = "Dejavu Sans"`: Tooltip font.
- `background_color = :white`: Background color of the tooltip.
- `outline_color = :grey`: Outline color of the tooltip.
- `outline_linestyle = nothing`: Linestyle of the tooltip outline.
- `outline_linewidth = 2`: Linewidth of the tooltip outline.
- `indicator_color = :red`: Color of the selection indicator.
- `indicator_linewidth = 2`: Linewidth of the selection indicator.
- `indicator_linestyle = nothing`: Linestyle of the selection indicator
- `tooltip_align = (:center, :top)`: Default position of the tooltip relative to the cursor or current selection. The real align may adjust to keep the tooltip in view.
- `tooltip_offset = Vec2f(20)`: Offset from the indicator to the tooltip.
- `depth = 9e3`: Depth value of the tooltip. This should be high so that the tooltip is always in front.
- `priority = 100`: The priority of creating a tooltip on a mouse movement or scrolling event.

## Extending the `DataInspector`

The inspector implements tooltips for primitive plots and a few non-primitive
(i.e. a recipe) plots. All other plots will fall back to tooltips of their
hovered child. While this means that most plots have a tooltip it also means
many may not have a fitting one. If you wish to implement a more fitting tooltip
for non-primitive plot you may do so by creating a method

```julia
function show_data(inspector::DataInspector, my_plot::MyPlot, idx, primitive_child::SomePrimitive)
    ...
end
```

Here `my_plot` is the plot you want to create a custom tooltip for,
`primitive_child` is one of the primitives your plot is made from and `idx` is
the index into that primitive plot. The latter two are the result from
`pick_sorted` at the mouseposition. In general you will need to adjust `idx` to
be useful for `MyPlot`.

Let's take a look at the `BarPlot` overload, which also powers `hist`. It
contains two primitive plots - `Mesh` and `Lines`. The `idx` from picking a
`Mesh` is based on vertices, which there are four per rectangle. From `Lines` we
get an index based on the end point of the line. To draw the outline of a
rectangle we need 5 points and a seperator, totaling 6. We thus implement

```julia
import Makie: show_data

function show_data(inspector::DataInspector, plot::BarPlot, idx, ::Lines)
    return show_barplot(inspector, plot, div(idx-1, 6)+1)
end

function show_data(inspector::DataInspector, plot::BarPlot, idx, ::Mesh)
    return show_barplot(inspector, plot, div(idx-1, 4)+1)
end
```

to map the primitive `idx` to one relevant for `BarPlot`. With this we can now
get the position of the hovered bar with `plot[1][][idx]`. To align the tooltip
to the selection we need to compute the relevant position in screen space and
update the tooltip position.

```julia
using Makie: parent_scene, shift_project, update_tooltip_alignment!, position2string

function show_barplot(inspector::DataInspector, plot::BarPlot, idx)
    # All the attributes of DataInspector are here
    a = inspector.plot.attributes

    # Get the scene BarPlot lives in
    scene = parent_scene(plot)

    # Get the hovered world-space position
    pos = plot[1][][idx]
    # project to screen space and shift it to be correct on the root scene
    proj_pos = shift_project(scene, to_ndim(Point3f, pos, 0))
    # anchor the tooltip at the projected position
    update_tooltip_alignment!(inspector, proj_pos)

    # Update the final text of the tooltip
    # position2string is just an `@sprintf`
    a._display_text[] = position2string(pos)
    # Show the tooltip
    a._visible[] = true

    # return true to indicate that we have updated the tooltip
    return true
end
```

Next we need to mark the rectangle we are hovering. In this case we can use the
rectangles which `BarPlot` passes to `Poly`, i.e. `plot.plots[1][1][][idx]`. The
`DataInspector` contains some functionality for keeping track of temporary plots,
so we can plot the indicator to the same `scene` that `BarPlot` uses. Doing so
results in

```julia
using Makie:
    parent_scene, shift_project, update_tooltip_alignment!, position2string,
    clear_temporary_plots!


function show_barplot(inspector::DataInspector, plot::BarPlot, idx)
    a = inspector.plot.attributes
    scene = parent_scene(plot)

    pos = plot[1][][idx]
    proj_pos = shift_project(scene, to_ndim(Point3f, pos, 0))
    update_tooltip_alignment!(inspector, proj_pos)

    # Get the rectangle BarPlot generated for Poly
    # `_bbox2D` is a node meant for saving a `Rect2` indicator. There is also
    # a `_bbox3D`. Here we keep `_bbox2D` updated and use it as a source for
    # our custom indicator.
    a._bbox2D[] = plot.plots[1][1][][idx]
    a._model[] = plot.model[]

    # Only plot the indicator once. It'll be updated via `_bbox2D`.
    if inspector.selection != plot
        # Clear any old temporary plots (i.e. other indicators like this)
        # this also updates inspector.selection.
        clear_temporary_plots!(inspector, plot)

        # create the indicator using a bunch of the DataInspector attributes.
        # Note that temporary plots only cleared when a new one is created. To
        # control whether indicator is visible or not `a._bbox_visible` is set
        # instead, so it should be in any custom indicator like this.
        p = wireframe!(
            scene, a._bbox2D, model = a._model, color = a.indicator_color,
            strokewidth = a.indicator_linewidth, linestyle = a.indicator_linestyle,
            visible = a._bbox_visible, show_axis = false, inspectable = false
        )

        # Make sure this draws on top
        translate!(p, Vec3f(0, 0, a.depth[]))

        # register this indicator for later cleanup.
        push!(inspector.temp_plots, p)
    end

    a._display_text[] = position2string(pos)
    a._visible[] = true

    # Show our custom indicator
    a._bbox_visible[] = true
    # Don't show the default screen space indicator
    a._px_bbox_visible[] = false

    return true
end
```

which finishes the implementation of a custom tooltip for `BarPlot`.
