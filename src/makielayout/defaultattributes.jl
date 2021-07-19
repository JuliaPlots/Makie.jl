function lift_parent_attribute(scene, attr::Symbol, default_value)
    if haskey(scene.attributes, attr)
        lift(identity, scene[attr])
    else
        lift_parent_attribute(scene.parent, attr, default_value)
    end
end

function lift_parent_attribute(::Nothing, attr::Symbol, default_value)
    default_value
end




function default_attributes(::Type{Axis}, scene)
    attrs, docdict, defaultdict = @documented_attributes begin
        "Attributes with one palette per key, for example `color = [:red, :green, :blue]`"
        palette = scene !== nothing && haskey(scene.attributes, :palette) ? deepcopy(scene.palette) : Attributes()
        "The xlabel string."
        xlabel = ""
        "The ylabel string."
        ylabel = ""
        "The axis title string."
        title = ""
        "The font family of the title."
        titlefont = lift_parent_attribute(scene, :font, "DejaVu Sans")
        "The title's font size."
        titlesize = lift_parent_attribute(scene, :fontsize, 16f0)
        "The gap between axis and title."
        titlegap = 4f0
        "Controls if the title is visible."
        titlevisible = true
        "The horizontal alignment of the title."
        titlealign = :center
        "The color of the title"
        titlecolor = lift_parent_attribute(scene, :textcolor, :black)
        "The font family of the xlabel."
        xlabelfont = lift_parent_attribute(scene, :font, "DejaVu Sans")
        "The font family of the ylabel."
        ylabelfont = lift_parent_attribute(scene, :font, "DejaVu Sans")
        "The color of the xlabel."
        xlabelcolor = lift_parent_attribute(scene, :textcolor, :black)
        "The color of the ylabel."
        ylabelcolor = lift_parent_attribute(scene, :textcolor, :black)
        "The font size of the xlabel."
        xlabelsize = lift_parent_attribute(scene, :fontsize, 16f0)
        "The font size of the ylabel."
        ylabelsize = lift_parent_attribute(scene, :fontsize, 16f0)
        "Controls if the xlabel is visible."
        xlabelvisible = true
        "Controls if the ylabel is visible."
        ylabelvisible = true
        "The padding between the xlabel and the ticks or axis."
        xlabelpadding = 3f0
        "The padding between the ylabel and the ticks or axis."
        ylabelpadding = 5f0 # because of boundingbox inaccuracies of ticklabels
        "The font family of the xticklabels."
        xticklabelfont = lift_parent_attribute(scene, :font, "DejaVu Sans")
        "The font family of the yticklabels."
        yticklabelfont = lift_parent_attribute(scene, :font, "DejaVu Sans")
        "The color of xticklabels."
        xticklabelcolor = lift_parent_attribute(scene, :textcolor, :black)
        "The color of yticklabels."
        yticklabelcolor = lift_parent_attribute(scene, :textcolor, :black)
        "The font size of the xticklabels."
        xticklabelsize = lift_parent_attribute(scene, :fontsize, 16f0)
        "The font size of the yticklabels."
        yticklabelsize = lift_parent_attribute(scene, :fontsize, 16f0)
        "Controls if the xticklabels are visible."
        xticklabelsvisible = true
        "Controls if the yticklabels are visible."
        yticklabelsvisible = true
        "The space reserved for the xticklabels."
        xticklabelspace = Makie.automatic
        "The space reserved for the yticklabels."
        yticklabelspace = Makie.automatic
        "The space between xticks and xticklabels."
        xticklabelpad = 2f0
        "The space between yticks and yticklabels."
        yticklabelpad = 4f0
        "The counterclockwise rotation of the xticklabels in radians."
        xticklabelrotation = 0f0
        "The counterclockwise rotation of the yticklabels in radians."
        yticklabelrotation = 0f0
        "The horizontal and vertical alignment of the xticklabels."
        xticklabelalign = Makie.automatic
        "The horizontal and vertical alignment of the yticklabels."
        yticklabelalign = Makie.automatic
        "The size of the xtick marks."
        xticksize = 6f0
        "The size of the ytick marks."
        yticksize = 6f0
        "Controls if the xtick marks are visible."
        xticksvisible = true
        "Controls if the ytick marks are visible."
        yticksvisible = true
        "The alignment of the xtick marks relative to the axis spine (0 = out, 1 = in)."
        xtickalign = 0f0
        "The alignment of the ytick marks relative to the axis spine (0 = out, 1 = in)."
        ytickalign = 0f0
        "The width of the xtick marks."
        xtickwidth = 1f0
        "The width of the ytick marks."
        ytickwidth = 1f0
        "The color of the xtick marks."
        xtickcolor = RGBf(0, 0, 0)
        "The color of the ytick marks."
        ytickcolor = RGBf(0, 0, 0)
        "Locks interactive panning in the x direction."
        xpanlock = false
        "Locks interactive panning in the y direction."
        ypanlock = false
        "Locks interactive zooming in the x direction."
        xzoomlock = false
        "Locks interactive zooming in the y direction."
        yzoomlock = false
        "Controls if rectangle zooming affects the x dimension."
        xrectzoom = true
        "Controls if rectangle zooming affects the y dimension."
        yrectzoom = true
        "The width of the axis spines."
        spinewidth = 1f0
        "Controls if the x grid lines are visible."
        xgridvisible = true
        "Controls if the y grid lines are visible."
        ygridvisible = true
        "The width of the x grid lines."
        xgridwidth = 1f0
        "The width of the y grid lines."
        ygridwidth = 1f0
        "The color of the x grid lines."
        xgridcolor = RGBAf(0, 0, 0, 0.12)
        "The color of the y grid lines."
        ygridcolor = RGBAf(0, 0, 0, 0.12)
        "The linestyle of the x grid lines."
        xgridstyle = nothing
        "The linestyle of the y grid lines."
        ygridstyle = nothing
        "Controls if the x minor grid lines are visible."
        xminorgridvisible = false
        "Controls if the y minor grid lines are visible."
        yminorgridvisible = false
        "The width of the x minor grid lines."
        xminorgridwidth = 1f0
        "The width of the y minor grid lines."
        yminorgridwidth = 1f0
        "The color of the x minor grid lines."
        xminorgridcolor = RGBAf(0, 0, 0, 0.05)
        "The color of the y minor grid lines."
        yminorgridcolor = RGBAf(0, 0, 0, 0.05)
        "The linestyle of the x minor grid lines."
        xminorgridstyle = nothing
        "The linestyle of the y minor grid lines."
        yminorgridstyle = nothing
        "Controls if the bottom axis spine is visible."
        bottomspinevisible = true
        "Controls if the left axis spine is visible."
        leftspinevisible = true
        "Controls if the top axis spine is visible."
        topspinevisible = true
        "Controls if the right axis spine is visible."
        rightspinevisible = true
        "The color of the bottom axis spine."
        bottomspinecolor = :black
        "The color of the left axis spine."
        leftspinecolor = :black
        "The color of the top axis spine."
        topspinecolor = :black
        "The color of the right axis spine."
        rightspinecolor = :black
        "The forced aspect ratio of the axis. `nothing` leaves the axis unconstrained, `DataAspect()` forces the same ratio as the ratio in data limits between x and y axis, `AxisAspect(ratio)` sets a manual ratio."
        aspect = nothing
        "The vertical alignment of the axis within its suggested bounding box."
        valign = :center
        "The horizontal alignment of the axis within its suggested bounding box."
        halign = :center
        "The width of the axis."
        width = nothing
        "The height of the axis."
        height = nothing
        "Controls if the parent layout can adjust to this element's width"
        tellwidth = true
        "Controls if the parent layout can adjust to this element's height"
        tellheight = true
        "The relative margins added to the autolimits in x direction."
        xautolimitmargin = (0.05f0, 0.05f0)
        "The relative margins added to the autolimits in y direction."
        yautolimitmargin = (0.05f0, 0.05f0)
        "The xticks."
        xticks = Makie.automatic
        "Format for xticks."
        xtickformat = Makie.automatic
        "The yticks."
        yticks = Makie.automatic
        "Format for yticks."
        ytickformat = Makie.automatic
        "The button for panning."
        panbutton = Makie.Mouse.right
        "The key for limiting panning to the x direction."
        xpankey = Makie.Keyboard.x
        "The key for limiting panning to the y direction."
        ypankey = Makie.Keyboard.y
        "The key for limiting zooming to the x direction."
        xzoomkey = Makie.Keyboard.x
        "The key for limiting zooming to the y direction."
        yzoomkey = Makie.Keyboard.y
        "The position of the x axis (`:bottom` or `:top`)."
        xaxisposition = :bottom
        "The position of the y axis (`:left` or `:right`)."
        yaxisposition = :left
        "Controls if the x spine is limited to the furthest tick marks or not."
        xtrimspine = false
        "Controls if the y spine is limited to the furthest tick marks or not."
        ytrimspine = false
        "The background color of the axis."
        backgroundcolor = :white
        "Controls if the ylabel's rotation is flipped."
        flip_ylabel = false
        "Constrains the data aspect ratio (`nothing` leaves the ratio unconstrained)."
        autolimitaspect = nothing
        "The limits that the user has manually set. They are reinstated when calling `reset_limits!` and are set to nothing by `autolimits!`. Can be either a tuple (xlow, xhigh, ylow, high) or a tuple (nothing_or_xlims, nothing_or_ylims). Are set by `xlims!`, `ylims!` and `limits!`."
        limits = (nothing, nothing)
        "The align mode of the axis in its parent GridLayout."
        alignmode = Inside()
        "Controls if the y axis goes upwards (false) or downwards (true)"
        yreversed = false
        "Controls if the x axis goes rightwards (false) or leftwards (true)"
        xreversed = false
        "Controls if minor ticks on the x axis are visible"
        xminorticksvisible = false
        "The alignment of x minor ticks on the axis spine"
        xminortickalign = 0f0
        "The tick size of x minor ticks"
        xminorticksize = 4f0
        "The tick width of x minor ticks"
        xminortickwidth = 1f0
        "The tick color of x minor ticks"
        xminortickcolor = :black
        "The tick locator for the x minor ticks"
        xminorticks = IntervalsBetween(2)
        "Controls if minor ticks on the y axis are visible"
        yminorticksvisible = false
        "The alignment of y minor ticks on the axis spine"
        yminortickalign = 0f0
        "The tick size of y minor ticks"
        yminorticksize = 4f0
        "The tick width of y minor ticks"
        yminortickwidth = 1f0
        "The tick color of y minor ticks"
        yminortickcolor = :black
        "The tick locator for the y minor ticks"
        yminorticks = IntervalsBetween(2)
        "The x axis scale"
        xscale = identity
        "The y axis scale"
        yscale = identity
    end

    (attributes = attrs, documentation = docdict, defaults = defaultdict)
end

@doc """
Axis has the following attributes:

$(let
    _, docs, defaults = default_attributes(Axis, nothing)
    docvarstring(docs, defaults)
end)
"""
Axis

function default_attributes(::Type{Colorbar}, scene)
    attrs, docdict, defaultdict = @documented_attributes begin
        "The color bar label string."
        label = ""
        "The label color."
        labelcolor = lift_parent_attribute(scene, :textcolor, :black)
        "The label font family."
        labelfont = lift_parent_attribute(scene, :font, "DejaVu Sans")
        "The label font size."
        labelsize = lift_parent_attribute(scene, :fontsize, 16f0)
        "Controls if the label is visible."
        labelvisible = true
        "The gap between the label and the ticks."
        labelpadding = 5f0
        "The font family of the tick labels."
        ticklabelfont = lift_parent_attribute(scene, :font, "DejaVu Sans")
        "The font size of the tick labels."
        ticklabelsize = lift_parent_attribute(scene, :fontsize, 16f0)
        "Controls if the tick labels are visible."
        ticklabelsvisible = true
        "The color of the tick labels."
        ticklabelcolor = lift_parent_attribute(scene, :textcolor, :black)
        "The size of the tick marks."
        ticksize = 6f0
        "Controls if the tick marks are visible."
        ticksvisible = true
        "The ticks."
        ticks = Makie.automatic
        "Format for ticks."
        tickformat = Makie.automatic
        "The space reserved for the tick labels."
        ticklabelspace = Makie.automatic
        "The gap between tick labels and tick marks."
        ticklabelpad = 3f0
        "The alignment of the tick marks relative to the axis spine (0 = out, 1 = in)."
        tickalign = 0f0
        "The line width of the tick marks."
        tickwidth = 1f0
        "The color of the tick marks."
        tickcolor = RGBf(0, 0, 0)
        "The horizontal and vertical alignment of the tick labels."
        ticklabelalign = Makie.automatic
        "The rotation of the ticklabels"
        ticklabelrotation = 0f0
        "The line width of the spines."
        spinewidth = 1f0
        "Controls if the top spine is visible."
        topspinevisible = true
        "Controls if the right spine is visible."
        rightspinevisible = true
        "Controls if the left spine is visible."
        leftspinevisible = true
        "Controls if the bottom spine is visible."
        bottomspinevisible = true
        "The color of the top spine."
        topspinecolor = RGBf(0, 0, 0)
        "The color of the left spine."
        leftspinecolor = RGBf(0, 0, 0)
        "The color of the right spine."
        rightspinecolor = RGBf(0, 0, 0)
        "The color of the bottom spine."
        bottomspinecolor = RGBf(0, 0, 0)
        "The vertical alignment of the colorbar in its suggested bounding box."
        valign = :center
        "The horizontal alignment of the colorbar in its suggested bounding box."
        halign = :center
        "Controls if the colorbar is oriented vertically."
        vertical = true
        "Flips the axis to the right if vertical and to the top if horizontal."
        flipaxis = true
        "Flips the colorbar label if the axis is vertical."
        flip_vertical_label = false
        "The width setting of the colorbar. Use `size` to set width or height relative to colorbar orientation instead."
        width = Makie.automatic
        "The height setting of the colorbar."
        height = Makie.automatic
        "Controls if the parent layout can adjust to this element's width"
        tellwidth = true
        "Controls if the parent layout can adjust to this element's height"
        tellheight = true
        "The colormap that the colorbar uses."
        colormap = lift_parent_attribute(scene, :colormap, :viridis)
        "The range of values depicted in the colorbar."
        limits = nothing
        "The range of values depicted in the colorbar."
        colorrange = nothing
        "The align mode of the colorbar in its parent GridLayout."
        alignmode = Inside()
        "The number of steps in the heatmap underlying the colorbar gradient."
        nsteps = 100
        "The color of the high clip triangle."
        highclip = nothing
        "The color of the low clip triangle."
        lowclip = nothing
        "Controls if minor ticks are visible"
        minorticksvisible = false
        "The alignment of minor ticks on the axis spine"
        minortickalign = 0f0
        "The tick size of minor ticks"
        minorticksize = 4f0
        "The tick width of minor ticks"
        minortickwidth = 1f0
        "The tick color of minor ticks"
        minortickcolor = :black
        "The tick locator for the minor ticks"
        minorticks = IntervalsBetween(5)
        "The axis scale"
        scale = identity
        "The width or height of the colorbar, depending on if it's vertical or horizontal, unless overridden by `width` / `height`"
        size = 16
    end
    (attributes = attrs, documentation = docdict, defaults = defaultdict)
end

@doc """
    Colorbar(parent; kwargs...)
    Colorbar(parent, plotobject; kwargs...)
    Colorbar(parent, heatmap::Heatmap; kwargs...)
    Colorbar(parent, contourf::Contourf; kwargs...)

Add a Colorbar to `parent`. If you pass a `plotobject`, a `heatmap` or `contourf`, the Colorbar is set up automatically such that it tracks these objects' relevant attributes like `colormap`, `colorrange`, `highclip` and `lowclip`. If you want to adjust these attributes afterwards, change them in the plot object, otherwise the Colorbar and the plot object will go out of sync.

Colorbar has the following attributes:

$(let
    _, docs, defaults = default_attributes(Colorbar, nothing)
    docvarstring(docs, defaults)
end)
"""
Colorbar

function default_attributes(::Type{Label}, scene)
    attrs, docdict, defaultdict = @documented_attributes begin
        "The displayed text string."
        text = "Text"
        "Controls if the text is visible."
        visible = true
        "The color of the text."
        color = lift_parent_attribute(scene, :textcolor, :black)
        "The font size of the text."
        textsize = lift_parent_attribute(scene, :fontsize, 16f0)
        "The font family of the text."
        font = lift_parent_attribute(scene, :font, "DejaVu Sans")
        "The vertical alignment of the text in its suggested boundingbox"
        valign = :center
        "The horizontal alignment of the text in its suggested boundingbox"
        halign = :center
        "The counterclockwise rotation of the text in radians."
        rotation = 0f0
        "The extra space added to the sides of the text boundingbox."
        padding = (0f0, 0f0, 0f0, 0f0)
        "The height setting of the text."
        height = Auto()
        "The width setting of the text."
        width = Auto()
        "Controls if the parent layout can adjust to this element's width"
        tellwidth = true
        "Controls if the parent layout can adjust to this element's height"
        tellheight = true
        "The align mode of the text in its parent GridLayout."
        alignmode = Inside()
    end
    (attributes = attrs, documentation = docdict, defaults = defaultdict)
end

@doc """
Label has the following attributes:

$(let
    _, docs, defaults = default_attributes(Label, nothing)
    docvarstring(docs, defaults)
end)
"""
Label

function default_attributes(::Type{Box}, scene)
    attrs, docdict, defaultdict = @documented_attributes begin
        "Controls if the rectangle is visible."
        visible = true
        "The color of the rectangle."
        color = RGBf(0.9, 0.9, 0.9)
        "The vertical alignment of the rectangle in its suggested boundingbox"
        valign = :center
        "The horizontal alignment of the rectangle in its suggested boundingbox"
        halign = :center
        "The extra space added to the sides of the rectangle boundingbox."
        padding = (0f0, 0f0, 0f0, 0f0)
        "The line width of the rectangle's border."
        strokewidth = 1f0
        "Controls if the border of the rectangle is visible."
        strokevisible = true
        "The color of the border."
        strokecolor = RGBf(0, 0, 0)
        "The width setting of the rectangle."
        width = nothing
        "The height setting of the rectangle."
        height = nothing
        "Controls if the parent layout can adjust to this element's width"
        tellwidth = true
        "Controls if the parent layout can adjust to this element's height"
        tellheight = true
        "The align mode of the rectangle in its parent GridLayout."
        alignmode = Inside()
    end
    (attributes = attrs, documentation = docdict, defaults = defaultdict)
end

@doc """
Box has the following attributes:

$(let
    _, docs, defaults = default_attributes(Box, nothing)
    docvarstring(docs, defaults)
end)
"""
Box


function default_attributes(::Type{Button}, scene)
    attrs, docdict, defaultdict = @documented_attributes begin
        "The horizontal alignment of the button in its suggested boundingbox"
        halign = :center
        "The vertical alignment of the button in its suggested boundingbox"
        valign = :center
        "The extra space added to the sides of the button label's boundingbox."
        padding = (10f0, 10f0, 10f0, 10f0)
        "The font size of the button label."
        textsize = lift_parent_attribute(scene, :fontsize, 16f0)
        "The text of the button label."
        label = "Button"
        "The font family of the button label."
        font = lift_parent_attribute(scene, :font, "DejaVu Sans")
        "The width setting of the button."
        width = Auto()
        "The height setting of the button."
        height = Auto()
        "Controls if the parent layout can adjust to this element's width"
        tellwidth = true
        "Controls if the parent layout can adjust to this element's height"
        tellheight = true
        "The radius of the rounded corners of the button."
        cornerradius = 4
        "The number of poly segments used for each rounded corner."
        cornersegments = 10
        "The line width of the button border."
        strokewidth = 2f0
        "The color of the button border."
        strokecolor = :transparent
        "The color of the button."
        buttoncolor = RGBf(0.94, 0.94, 0.94)
        "The color of the label."
        labelcolor = lift_parent_attribute(scene, :textcolor, :black)
        "The color of the label when the mouse hovers over the button."
        labelcolor_hover = :black
        "The color of the label when the mouse clicks the button."
        labelcolor_active = :white
        "The color of the button when the mouse clicks the button."
        buttoncolor_active = COLOR_ACCENT[]
        "The color of the button when the mouse hovers over the button."
        buttoncolor_hover = COLOR_ACCENT_DIMMED[]
        "The number of clicks that have been registered by the button."
        clicks = 0
        "The align mode of the button in its parent GridLayout."
        alignmode = Inside()
    end
    (attributes = attrs, documentation = docdict, defaults = defaultdict)
end

@doc """
Button has the following attributes:

$(let
    _, docs, defaults = default_attributes(Button, nothing)
    docvarstring(docs, defaults)
end)
"""
Button

function default_attributes(::Type{LineAxis})
    Attributes(
        endpoints = (Point2f(0, 0), Point2f(100, 0)),
        trimspine = false,
        limits = (0f0, 100f0),
        flipped = false,
        flip_vertical_label = false,
        ticksize = 6f0,
        tickwidth = 1f0,
        tickcolor = RGBf(0, 0, 0),
        tickalign = 0f0,
        ticks = Makie.automatic,
        tickformat = Makie.automatic,
        ticklabelalign = (:center, :top),
        ticksvisible = true,
        ticklabelrotation = 0f0,
        ticklabelsize = 20f0,
        ticklabelcolor = RGBf(0, 0, 0),
        ticklabelsvisible = true,
        spinewidth = 1f0,
        label = "label",
        labelsize = 20f0,
        labelcolor = RGBf(0, 0, 0),
        labelvisible = true,
        ticklabelspace = Makie.automatic,
        ticklabelpad = 3f0,
        labelpadding = 5f0,
        reversed = false,
        minorticksvisible = true,
        minortickalign = 0f0,
        minorticksize = 4f0,
        minortickwidth = 1f0,
        minortickcolor = :black,
        minorticks = Makie.automatic,
        scale = identity,
    )
end

function default_attributes(::Type{Slider}, scene)
    attrs, docdict, defaultdict = @documented_attributes begin
        "The horizontal alignment of the slider in its suggested bounding box."
        halign = :center
        "The vertical alignment of the slider in its suggested bounding box."
        valign = :center
        "The width setting of the slider."
        width = Auto()
        "The height setting of the slider."
        height = Auto()
        "The range of values that the slider can pick from."
        range = 0:0.01:10
        "Controls if the parent layout can adjust to this element's width"
        tellwidth = true
        "Controls if the parent layout can adjust to this element's height"
        tellheight = true
        "The start value of the slider or the value that is closest in the slider range."
        startvalue = 0
        "The current value of the slider. Don't set this manually, use the function `set_close_to!`."
        value = 0
        "The width of the slider line"
        linewidth = 15
        "The color of the slider when the mouse hovers over it."
        color_active_dimmed = COLOR_ACCENT_DIMMED[]
        "The color of the slider when the mouse clicks and drags the slider."
        color_active = COLOR_ACCENT[]
        "The color of the slider when it is not interacted with."
        color_inactive = RGBf(0.94, 0.94, 0.94)
        "Controls if the slider has a horizontal orientation or not."
        horizontal = true
        "The align mode of the slider in its parent GridLayout."
        alignmode = Inside()
        "Controls if the button snaps to valid positions or moves freely"
        snap = true
    end
    (attributes = attrs, documentation = docdict, defaults = defaultdict)
end

@doc """
Slider has the following attributes:

$(let
    _, docs, defaults = default_attributes(Slider, nothing)
    docvarstring(docs, defaults)
end)
"""
Slider

function default_attributes(::Type{IntervalSlider}, scene)
    attrs, docdict, defaultdict = @documented_attributes begin
        "The horizontal alignment of the slider in its suggested bounding box."
        halign = :center
        "The vertical alignment of the slider in its suggested bounding box."
        valign = :center
        "The width setting of the slider."
        width = Auto()
        "The height setting of the slider."
        height = Auto()
        "The range of values that the slider can pick from."
        range = 0:0.01:10
        "Controls if the parent layout can adjust to this element's width"
        tellwidth = true
        "Controls if the parent layout can adjust to this element's height"
        tellheight = true
        "The start values of the slider or the values that are closest in the slider range."
        startvalues = Makie.automatic
        "The current interval of the slider. Don't set this manually, use the function `set_close_to!`."
        interval = (0, 0)
        "The width of the slider line"
        linewidth = 15
        "The color of the slider when the mouse hovers over it."
        color_active_dimmed = COLOR_ACCENT_DIMMED[]
        "The color of the slider when the mouse clicks and drags the slider."
        color_active = COLOR_ACCENT[]
        "The color of the slider when it is not interacted with."
        color_inactive = RGBf(0.94, 0.94, 0.94)
        "Controls if the slider has a horizontal orientation or not."
        horizontal = true
        "The align mode of the slider in its parent GridLayout."
        alignmode = Inside()
        "Controls if the buttons snap to valid positions or move freely"
        snap = true
    end
    (attributes = attrs, documentation = docdict, defaults = defaultdict)
end

@doc """
IntervalSlider has the following attributes:

$(let
    _, docs, defaults = default_attributes(IntervalSlider, nothing)
    docvarstring(docs, defaults)
end)
"""
IntervalSlider


function default_attributes(::Type{Toggle}, scene)
    attrs, docdict, defaultdict = @documented_attributes begin
        "The horizontal alignment of the toggle in its suggested bounding box."
        halign = :center
        "The vertical alignment of the toggle in its suggested bounding box."
        valign = :center
        "The width of the toggle."
        width = 60
        "The height of the toggle."
        height = 28
        "Controls if the parent layout can adjust to this element's width"
        tellwidth = true
        "Controls if the parent layout can adjust to this element's height"
        tellheight = true
        "The number of poly segments in each rounded corner."
        cornersegments = 15
        # strokewidth = 2f0
        # strokecolor = :transparent
        "The color of the border when the toggle is inactive."
        framecolor_inactive = RGBf(0.94, 0.94, 0.94)
        "The color of the border when the toggle is hovered."
        framecolor_active = COLOR_ACCENT_DIMMED[]
        # buttoncolor = RGBf(0.2, 0.2, 0.2)
        "The color of the toggle button."
        buttoncolor = COLOR_ACCENT[]
        "Indicates if the toggle is active or not."
        active = false
        "The duration of the toggle animation."
        toggleduration = 0.15
        "The border width as a fraction of the toggle height "
        rimfraction = 0.33
        "The align mode of the toggle in its parent GridLayout."
        alignmode = Inside()
    end
    (attributes = attrs, documentation = docdict, defaults = defaultdict)
end

@doc """
Toggle has the following attributes:

$(let
    _, docs, defaults = default_attributes(Toggle, nothing)
    docvarstring(docs, defaults)
end)
"""
Toggle


function default_attributes(::Type{Legend}, scene)
    attrs, docdict, defaultdict = @documented_attributes begin
        "The horizontal alignment of the legend in its suggested bounding box."
        halign = :center
        "The vertical alignment of the legend in its suggested bounding box."
        valign = :center
        "The width setting of the legend."
        width = Auto()
        "The height setting of the legend."
        height = Auto()
        "Controls if the parent layout can adjust to this element's width"
        tellwidth = true
        "Controls if the parent layout can adjust to this element's height"
        tellheight = false
        "The font family of the legend group titles."
        titlefont = lift_parent_attribute(scene, :font, "DejaVu Sans")
        "The font size of the legend group titles."
        titlesize = lift_parent_attribute(scene, :fontsize, 16f0)
        "The horizontal alignment of the legend group titles."
        titlehalign = :center
        "The vertical alignment of the legend group titles."
        titlevalign = :center
        "Controls if the legend titles are visible."
        titlevisible = true
        "The color of the legend titles"
        titlecolor = lift_parent_attribute(scene, :textcolor, :black)
        "The group title positions relative to their groups. Can be `:top` or `:left`."
        titleposition = :top
        "The font size of the entry labels."
        labelsize = lift_parent_attribute(scene, :fontsize, 16f0)
        "The font family of the entry labels."
        labelfont = lift_parent_attribute(scene, :font, "DejaVu Sans")
        "The color of the entry labels."
        labelcolor = lift_parent_attribute(scene, :textcolor, :black)
        "The horizontal alignment of the entry labels."
        labelhalign = :left
        "The vertical alignment of the entry labels."
        labelvalign = :center
        "The additional space between the legend content and the border."
        padding = (10f0, 10f0, 8f0, 8f0)
        "The additional space between the legend and its suggested boundingbox."
        margin = (0f0, 0f0, 0f0, 0f0)
        "The background color of the legend."
        bgcolor = :white
        "The color of the legend border."
        framecolor = :black
        "The line width of the legend border."
        framewidth = 1f0
        "Controls if the legend border is visible."
        framevisible = true
        "The size of the rectangles containing the legend markers."
        patchsize = (20f0, 20f0)
        "The color of the border of the patches containing the legend markers."
        patchstrokecolor = :transparent
        "The line width of the border of the patches containing the legend markers."
        patchstrokewidth = 1f0
        "The color of the patches containing the legend markers."
        patchcolor = :transparent
        "The default entry label."
        label = "undefined"
        "The number of banks in which the legend entries are grouped. Columns if the legend is vertically oriented, otherwise rows."
        nbanks = 1
        "The gap between the label of one legend entry and the patch of the next."
        colgap = 16
        "The gap between the entry rows."
        rowgap = 3
        "The gap between the patch and the label of each legend entry."
        patchlabelgap = 5
        "The default points used for LineElements in normalized coordinates relative to each label patch."
        linepoints = [Point2f(0, 0.5), Point2f(1, 0.5)]
        "The default line width used for LineElements."
        linewidth = theme(scene, :linewidth)
        "The default line color used for LineElements"
        linecolor = theme(scene, :linecolor)
        "The default line style used for LineElements"
        linestyle = :solid
        "The default marker color for MarkerElements"
        markercolor = theme(scene, :markercolor)
        "The default marker for MarkerElements"
        marker = theme(scene, :marker)
        "The default marker points used for MarkerElements in normalized coordinates relative to each label patch."
        markerpoints = [Point2f(0.5, 0.5)]
        "The default marker size used for MarkerElements."
        markersize = theme(scene, :markersize)
        "The default marker stroke width used for MarkerElements."
        markerstrokewidth = theme(scene, :markerstrokewidth)
        "The default marker stroke color used for MarkerElements."
        markerstrokecolor = theme(scene, :markerstrokecolor)
        "The default poly points used for PolyElements in normalized coordinates relative to each label patch."
        polypoints = [Point2f(0, 0), Point2f(1, 0), Point2f(1, 1), Point2f(0, 1)]
        "The default poly stroke width used for PolyElements."
        polystrokewidth = theme(scene, :patchstrokewidth)
        "The default poly color used for PolyElements."
        polycolor = theme(scene, :patchcolor)
        "The default poly stroke color used for PolyElements."
        polystrokecolor = theme(scene, :patchstrokecolor)
        "The orientation of the legend (:horizontal or :vertical)."
        orientation = :vertical
        "The gap between each group title and its group."
        titlegap = 8
        "The gap between each group and the next."
        groupgap = 16
        "The horizontal alignment of entry groups in their parent GridLayout."
        gridshalign = :center
        "The vertical alignment of entry groups in their parent GridLayout."
        gridsvalign = :center
        "The align mode of the legend in its parent GridLayout."
        alignmode = Inside()
    end
    (attributes = attrs, documentation = docdict, defaults = defaultdict)
end

@doc """
Legend has the following attributes:

$(let
    _, docs, defaults = default_attributes(Legend, nothing)
    docvarstring(docs, defaults)
end)
"""
Legend

function attributenames(::Type{LegendEntry})
    (:label, :labelsize, :labelfont, :labelcolor, :labelhalign, :labelvalign,
        :patchsize, :patchstrokecolor, :patchstrokewidth, :patchcolor,
        :linepoints, :linewidth, :linecolor, :linestyle,
        :markerpoints, :markersize, :markerstrokewidth, :markercolor, :markerstrokecolor,
        :polypoints, :polystrokewidth, :polycolor, :polystrokecolor)
end

function extractattributes(attributes::Attributes, typ::Type)
    extracted = Attributes()
    for name in attributenames(typ)
        if haskey(attributes, name)
            extracted[name] = attributes[name]
        end
    end
    extracted
end


function default_attributes(::Type{LScene}, scene)
    attrs, docdict, defaultdict = @documented_attributes begin
        "The height setting of the scene."
        height = nothing
        "The width setting of the scene."
        width = nothing
        "Controls if the parent layout can adjust to this element's width"
        tellwidth = true
        "Controls if the parent layout can adjust to this element's height"
        tellheight = true
        "The horizontal alignment of the scene in its suggested bounding box."
        halign = :center
        "The vertical alignment of the scene in its suggested bounding box."
        valign = :center
        "The alignment of the scene in its suggested bounding box."
        alignmode = Inside()
    end
    (attributes = attrs, documentation = docdict, defaults = defaultdict)
end

@doc """
LScene has the following attributes:

$(let
    _, docs, defaults = default_attributes(LScene, nothing)
    docvarstring(docs, defaults)
end)
"""
LScene




function default_attributes(::Type{Textbox}, scene)
    attrs, docdict, defaultdict = @documented_attributes begin
        "The height setting of the textbox."
        height = Auto()
        "The width setting of the textbox."
        width = Auto()
        "Controls if the parent layout can adjust to this element's width."
        tellwidth = true
        "Controls if the parent layout can adjust to this element's height."
        tellheight = true
        "The horizontal alignment of the textbox in its suggested bounding box."
        halign = :center
        "The vertical alignment of the textbox in its suggested bounding box."
        valign = :center
        "The alignment of the textbox in its suggested bounding box."
        alignmode = Inside()
        "A placeholder text that is displayed when the saved string is nothing."
        placeholder = "Click to edit..."
        "The currently stored string."
        stored_string = nothing
        "The currently displayed string (for internal use)."
        displayed_string = nothing
        "Controls if the displayed text is reset to the stored text when defocusing the textbox without submitting."
        reset_on_defocus = false
        "Controls if the textbox is defocused when a string is submitted."
        defocus_on_submit = true
        "Text size."
        textsize = lift_parent_attribute(scene, :fontsize, 16f0)
        "Text color."
        textcolor = lift_parent_attribute(scene, :textcolor, :black)
        "Text color for the placeholder."
        textcolor_placeholder = RGBf(0.5, 0.5, 0.5)
        "Font family."
        font = lift_parent_attribute(scene, :font, "DejaVu Sans")
        "Color of the box."
        boxcolor = :transparent
        "Color of the box when focused."
        boxcolor_focused = :transparent
        "Color of the box when focused."
        boxcolor_focused_invalid = RGBAf(1, 0, 0, 0.3)
        "Color of the box when hovered."
        boxcolor_hover = :transparent
        "Color of the box border."
        bordercolor = RGBf(0.80, 0.80, 0.80)
        "Color of the box border when hovered."
        bordercolor_hover = COLOR_ACCENT_DIMMED[]
        "Color of the box border when focused."
        bordercolor_focused = COLOR_ACCENT[]
        "Color of the box border when focused and invalid."
        bordercolor_focused_invalid = RGBf(1, 0, 0)
        "Width of the box border."
        borderwidth = 2f0
        "Padding of the text against the box."
        textpadding = (10, 10, 10, 10)
        "If the textbox is focused and receives text input."
        focused = false
        "Corner radius of text box."
        cornerradius = 8
        "Corner segments of one rounded corner."
        cornersegments = 20
        "Validator that is called with validate_textbox(string, validator) to determine if the current string is valid. Can by default be a RegEx that needs to match the complete string, or a function taking a string as input and returning a Bool. If the validator is a type T (for example Float64), validation will be `tryparse(string, T)`."
        validator = str -> true
        "Restricts the allowed unicode input via is_allowed(char, restriction)."
        restriction = nothing
        "The color of the cursor."
        cursorcolor = :transparent
    end
    (attributes = attrs, documentation = docdict, defaults = defaultdict)
end

@doc """
    Textbox(parent::Scene; bbox = nothing, kwargs...)
Textbox has the following attributes:
$(let
    _, docs, defaults = default_attributes(Textbox, nothing)
    docvarstring(docs, defaults)
end)
"""
Textbox



function default_attributes(::Type{Axis3}, scene)
    attrs, docdict, defaultdict = @documented_attributes begin
        "Attributes with one palette per key, for example `color = [:red, :green, :blue]`"
        palette = scene !== nothing && haskey(scene.attributes, :palette) ? deepcopy(scene.palette) : Attributes()
        "The height setting of the scene."
        height = nothing
        "The width setting of the scene."
        width = nothing
        "Controls if the parent layout can adjust to this element's width"
        tellwidth = true
        "Controls if the parent layout can adjust to this element's height"
        tellheight = true
        "The horizontal alignment of the scene in its suggested bounding box."
        halign = :center
        "The vertical alignment of the scene in its suggested bounding box."
        valign = :center
        "The alignment of the scene in its suggested bounding box."
        alignmode = Inside()
        "The elevation angle of the camera"
        elevation = pi/8
        "The azimuth angle of the camera"
        azimuth = 1.275 * pi
        "A number between 0 and 1, where 0 is orthographic, and 1 full perspective"
        perspectiveness = 0f0
        "Aspects of the 3 axes with each other"
        aspect = (1, 1, 2/3) # :data :equal
        "The view mode which affects the final projection. `:fit` results in the projection that always fits the limits into the viewport, invariant to rotation. `:fitzoom` keeps the x/y ratio intact but stretches the view so the corners touch the scene viewport. `:stretch` scales separately in both x and y direction to fill the viewport, which can distort the `aspect` that is set."
        viewmode = :fitzoom # :fit :fitzoom :stretch
        "The background color"
        backgroundcolor = :transparent
        "The x label"
        xlabel = "x"
        "The y label"
        ylabel = "y"
        "The z label"
        zlabel = "z"
        "The x label color"
        xlabelcolor = lift_parent_attribute(scene, :textcolor, :black)
        "The y label color"
        ylabelcolor = lift_parent_attribute(scene, :textcolor, :black)
        "The z label color"
        zlabelcolor = lift_parent_attribute(scene, :textcolor, :black)
        "Controls if the x label is visible"
        xlabelvisible = true
        "Controls if the y label is visible"
        ylabelvisible = true
        "Controls if the z label is visible"
        zlabelvisible = true
        "Controls if the x ticklabels are visible"
        xticklabelsvisible = true
        "Controls if the y ticklabels are visible"
        yticklabelsvisible = true
        "Controls if the z ticklabels are visible"
        zticklabelsvisible = true
        "Controls if the x ticks are visible"
        xticksvisible = true
        "Controls if the y ticks are visible"
        yticksvisible = true
        "Controls if the z ticks are visible"
        zticksvisible = true
        "The x label size"
        xlabelsize = lift_parent_attribute(scene, :fontsize, 16f0)
        "The y label size"
        ylabelsize = lift_parent_attribute(scene, :fontsize, 16f0)
        "The z label size"
        zlabelsize = lift_parent_attribute(scene, :fontsize, 16f0)
        "The x label font"
        xlabelfont = lift_parent_attribute(scene, :font, "DejaVu Sans")
        "The y label font"
        ylabelfont = lift_parent_attribute(scene, :font, "DejaVu Sans")
        "The z label font"
        zlabelfont = lift_parent_attribute(scene, :font, "DejaVu Sans")
        "The x label rotation"
        xlabelrotation = Makie.automatic
        "The y label rotation"
        ylabelrotation = Makie.automatic
        "The z label rotation"
        zlabelrotation = Makie.automatic
        "The x label align"
        xlabelalign = Makie.automatic
        "The y label align"
        ylabelalign = Makie.automatic
        "The z label align"
        zlabelalign = Makie.automatic
        "The x label offset"
        xlabeloffset = 40
        "The y label offset"
        ylabeloffset = 40
        "The z label offset"
        zlabeloffset = 50
        "The x ticklabel color"
        xticklabelcolor = lift_parent_attribute(scene, :textcolor, :black)
        "The y ticklabel color"
        yticklabelcolor = lift_parent_attribute(scene, :textcolor, :black)
        "The z ticklabel color"
        zticklabelcolor = lift_parent_attribute(scene, :textcolor, :black)
        "The x ticklabel size"
        xticklabelsize = lift_parent_attribute(scene, :fontsize, 16f0)
        "The y ticklabel size"
        yticklabelsize = lift_parent_attribute(scene, :fontsize, 16f0)
        "The z ticklabel size"
        zticklabelsize = lift_parent_attribute(scene, :fontsize, 16f0)
        "The x ticklabel pad"
        xticklabelpad = 5
        "The y ticklabel pad"
        yticklabelpad = 5
        "The z ticklabel pad"
        zticklabelpad = 10
        "The x ticklabel font"
        xticklabelfont = lift_parent_attribute(scene, :font, "DejaVu Sans")
        "The y ticklabel font"
        yticklabelfont = lift_parent_attribute(scene, :font, "DejaVu Sans")
        "The z ticklabel font"
        zticklabelfont = lift_parent_attribute(scene, :font, "DejaVu Sans")
        "The x grid color"
        xgridcolor = RGBAf(0, 0, 0, 0.12)
        "The y grid color"
        ygridcolor = RGBAf(0, 0, 0, 0.12)
        "The z grid color"
        zgridcolor = RGBAf(0, 0, 0, 0.12)
        "The x grid width"
        xgridwidth = 1
        "The y grid width"
        ygridwidth = 1
        "The z grid width"
        zgridwidth = 1
        "The x tick color"
        xtickcolor = :black
        "The y tick color"
        ytickcolor = :black
        "The z tick color"
        ztickcolor = :black
        "The x tick width"
        xtickwidth = 1
        "The y tick width"
        ytickwidth = 1
        "The z tick width"
        ztickwidth = 1
        "The color of x spine 1 where the ticks are displayed"
        xspinecolor_1 = :black
        "The color of y spine 1 where the ticks are displayed"
        yspinecolor_1 = :black
        "The color of z spine 1 where the ticks are displayed"
        zspinecolor_1 = :black
        "The color of x spine 2 towards the center"
        xspinecolor_2 = :black
        "The color of y spine 2 towards the center"
        yspinecolor_2 = :black
        "The color of z spine 2 towards the center"
        zspinecolor_2 = :black
        "The color of x spine 3 opposite of the ticks"
        xspinecolor_3 = :black
        "The color of y spine 3 opposite of the ticks"
        yspinecolor_3 = :black
        "The color of z spine 3 opposite of the ticks"
        zspinecolor_3 = :black
        "The x spine width"
        xspinewidth = 1
        "The y spine width"
        yspinewidth = 1
        "The z spine width"
        zspinewidth = 1
        "Controls if the x spine is visible"
        xspinesvisible = true
        "Controls if the y spine is visible"
        yspinesvisible = true
        "Controls if the z spine is visible"
        zspinesvisible = true
        "Controls if the x grid is visible"
        xgridvisible = true
        "Controls if the y grid is visible"
        ygridvisible = true
        "Controls if the z grid is visible"
        zgridvisible = true
        "The protrusions on the sides of the axis, how much gap space is reserved for labels etc."
        protrusions = 30
        "The x ticks"
        xticks = WilkinsonTicks(5; k_min = 3)
        "The y ticks"
        yticks = WilkinsonTicks(5; k_min = 3)
        "The z ticks"
        zticks = WilkinsonTicks(5; k_min = 3)
        "The x tick format"
        xtickformat = Makie.automatic
        "The y tick format"
        ytickformat = Makie.automatic
        "The z tick format"
        ztickformat = Makie.automatic
        "The axis title string."
        title = ""
        "The font family of the title."
        titlefont = lift_parent_attribute(scene, :font, "DejaVu Sans")
        "The title's font size."
        titlesize = lift_parent_attribute(scene, :fontsize, 16f0)
        "The gap between axis and title."
        titlegap = 4f0
        "Controls if the title is visible."
        titlevisible = true
        "The horizontal alignment of the title."
        titlealign = :center
        "The color of the title"
        titlecolor = lift_parent_attribute(scene, :textcolor, :black)
        "The color of the xy panel"
        xypanelcolor = :transparent
        "The color of the yz panel"
        yzpanelcolor = :transparent
        "The color of the xz panel"
        xzpanelcolor = :transparent
        "Controls if the xy panel is visible"
        xypanelvisible = true
        "Controls if the yz panel is visible"
        yzpanelvisible = true
        "Controls if the xz panel is visible"
        xzpanelvisible = true
        "The limits that the axis tries to set given other constraints like aspect. Don't set this directly, use `xlims!`, `ylims!` or `limits!` instead."
        targetlimits = Rect3f(Vec3f(0, 0, 0), Vec3f(1, 1, 1))
        "The limits that the user has manually set. They are reinstated when calling `reset_limits!` and are set to nothing by `autolimits!`. Can be either a tuple (xlow, xhigh, ylow, high, zlow, zhigh) or a tuple (nothing_or_xlims, nothing_or_ylims, nothing_or_zlims). Are set by `xlims!`, `ylims!`, `zlims!` and `limits!`."
        limits = (nothing, nothing, nothing)
        "The relative margins added to the autolimits in x direction."
        xautolimitmargin = (0.05, 0.05)
        "The relative margins added to the autolimits in y direction."
        yautolimitmargin = (0.05, 0.05)
        "The relative margins added to the autolimits in z direction."
        zautolimitmargin = (0.05, 0.05)
    end
    (attributes = attrs, documentation = docdict, defaults = defaultdict)
end

@doc """
Axis3 has the following attributes:

$(let
    _, docs, defaults = default_attributes(Axis3, nothing)
    docvarstring(docs, defaults)
end)
"""
Axis3
