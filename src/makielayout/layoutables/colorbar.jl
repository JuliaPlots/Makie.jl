function layoutable(::Type{<:Colorbar}, fig_or_scene, plot::AbstractPlot; kwargs...)

    for key in (:colormap, :limits)
        if key in keys(kwargs)
            error("You should not pass the `$key` attribute to the colorbar when constructing it using an existing plot object. This attribute is copied from the plot object, and setting it from the colorbar will make the plot object and the colorbar go out of sync.")
        end
    end

    layoutable(Colorbar, fig_or_scene;
        colormap = plot.colormap,
        limits = plot.colorrange,
        kwargs...
    )

end

function layoutable(::Type{<:Colorbar}, fig_or_scene, heatmap::Union{Heatmap, Image}; kwargs...)

    for key in (:colormap, :limits, :highclip, :lowclip)
        if key in keys(kwargs)
            error("You should not pass the `$key` attribute to the colorbar when constructing it using an existing plot object. This attribute is copied from the plot object, and setting it from the colorbar will make the plot object and the colorbar go out of sync.")
        end
    end

    layoutable(Colorbar, fig_or_scene;
        colormap = heatmap.colormap,
        limits = heatmap.colorrange,
        highclip = heatmap.highclip,
        lowclip = heatmap.lowclip,
        kwargs...
    )
end

function layoutable(::Type{<:Colorbar}, fig_or_scene, contourf::Makie.Contourf; kwargs...)

    for key in (:colormap, :limits, :highclip, :lowclip)
        if key in keys(kwargs)
            error("You should not pass the `$key` attribute to the colorbar when constructing it using an existing plot object. This attribute is copied from the plot object, and setting it from the colorbar will make the plot object and the colorbar go out of sync.")
        end
    end

    steps = contourf._computed_levels

    limits = lift(steps) do steps
        steps[1], steps[end]
    end

    layoutable(Colorbar, fig_or_scene;
        colormap = contourf._computed_colormap,
        limits = limits,
        lowclip = contourf._computed_extendlow,
        highclip = contourf._computed_extendhigh,
        kwargs...
    )

end


function layoutable(::Type{<:Colorbar}, fig_or_scene; bbox = nothing, kwargs...)
    topscene = get_topscene(fig_or_scene)
    attrs = merge!(Attributes(kwargs), default_attributes(Colorbar, topscene).attributes)

    default_attrs = default_attributes(Colorbar, topscene).attributes
    theme_attrs = subtheme(topscene, :Colorbar)
    attrs = merge!(merge!(Attributes(kwargs), theme_attrs), default_attrs)

    @extract attrs (
        label, labelcolor, labelsize, labelvisible, labelpadding, ticklabelsize,
        ticklabelspace, labelfont, ticklabelfont, ticklabelcolor, ticklabelrotation,
        ticklabelsvisible, ticks, tickformat, ticksize, ticksvisible, ticklabelpad, tickalign,
        tickwidth, tickcolor, spinewidth, topspinevisible,
        rightspinevisible, leftspinevisible, bottomspinevisible, topspinecolor,
        leftspinecolor, rightspinecolor, bottomspinecolor, colormap, limits, colorrange,
        halign, valign, vertical, flipaxis, ticklabelalign, flip_vertical_label,
        nsteps, highclip, lowclip,
        minorticksvisible, minortickalign, minorticksize, minortickwidth, minortickcolor, minorticks, scale)

    limits = lift(limits, colorrange) do limits, colorrange
        if all(!isnothing, (limits, colorrange))
            error("Both colorrange + limits are set, please only set one, they're aliases. colorrange: $(colorrange), limits: $(limits)")
        end
        return something(limits, colorrange, (0, 1))
    end

    decorations = Dict{Symbol, Any}()

    protrusions = Node(GridLayoutBase.RectSides{Float32}(0, 0, 0, 0))

    # make the layout width and height settings depend on `size` if they are set to automatic
    # and determine whether they are nothing or `size` depending on colorbar orientation
    _width = lift(Any, attrs.size, attrs.width, vertical) do sz, w, v
        w === Makie.automatic ? (v ? sz : nothing) : w
    end

    _height = lift(Any, attrs.size, attrs.height, vertical) do sz, h, v
        h === Makie.automatic ? (v ? nothing : sz) : h
    end

    layoutobservables = LayoutObservables{Colorbar}(_width, _height, attrs.tellwidth, attrs.tellheight,
        halign, valign, attrs.alignmode; suggestedbbox = bbox, protrusions = protrusions)

    framebox = @lift(round_to_Rect2i($(layoutobservables.computedbbox)))

    highclip_tri_visible = lift(x -> !(isnothing(x) || to_color(x) == to_color(:transparent)), highclip)
    lowclip_tri_visible = lift(x -> !(isnothing(x) || to_color(x) == to_color(:transparent)), lowclip)

    tri_heights = lift(highclip_tri_visible, lowclip_tri_visible, framebox) do hv, lv, box
        if vertical[]
            (lv * width(box), hv * width(box))
        else
            (lv * height(box), hv * height(box))
        end .* sin(pi/3)
    end

    barsize = lift(tri_heights) do heights
        if vertical[]
            max(1, height(framebox[]) - sum(heights))
        else
            max(1, width(framebox[]) - sum(heights))
        end
    end

    barbox = lift(barsize) do sz
        fbox = framebox[]
        if vertical[]
            BBox(left(fbox), right(fbox), bottom(fbox) + tri_heights[][1], top(fbox) - tri_heights[][2])
        else
            BBox(left(fbox) + tri_heights[][1], right(fbox) - tri_heights[][2], bottom(fbox), top(fbox))
        end
    end


    cgradient = lift(Any, colormap) do cmap
        if cmap isa PlotUtils.ColorGradient
            # if we have a colorgradient directly, we want to keep it intact
            # to enable correct categorical colormap behavior etc
            cmap
        else
            # this is a bit weird, first convert to a vector of colors,
            # then use cgrad, but at least I can use `get` on that later
            converted = Makie.convert_attribute(
                cmap,
                Makie.key"colormap"()
            )
            cgrad(converted)
        end
    end

    map_is_categorical = lift(x -> x isa PlotUtils.CategoricalColorGradient, cgradient)

    steps = lift(cgradient, nsteps) do cgradient, n
        s = if cgradient isa PlotUtils.CategoricalColorGradient
            cgradient.values
        else
            collect(LinRange(0, 1, n))
        end::Vector{Float64}
    end

    # it's hard to draw categorical and continous colormaps well
    # with the same primitives

    # therefore we make one interpolated image for continous
    # colormaps and number of polys for categorical colormaps
    # at the same time, then we just set one of them invisible
    # depending on the type of colormap
    # this should solve most white-line issues

    # for categorical colormaps we make a number of rectangle polys

    rects_and_colors = lift(barbox, vertical, steps, cgradient, scale, limits) do bbox, v, steps, gradient, scale, lims

        # we need to convert the 0 to 1 steps into rescaled 0 to 1 steps given the
        # colormap's `scale` attribute

        s_scaled = scaled_steps(steps, scale, lims)

        xmin, ymin = minimum(bbox)
        xmax, ymax = maximum(bbox)

        rects = if v
            yvals = s_scaled .* (ymax - ymin) .+ ymin
            [BBox(xmin, xmax, b, t)
                for (b, t) in zip(yvals[1:end-1], yvals[2:end])]
        else
            xvals = s_scaled .* (xmax - xmin) .+ xmin
            [BBox(l, r, ymin, ymax)
                for (l, r) in zip(xvals[1:end-1], xvals[2:end])]
        end

        colors = get.(Ref(gradient), (steps[1:end-1] .+ steps[2:end]) ./2)

        rects, colors
    end

    colors = lift(x -> getindex(x, 2), rects_and_colors)

    rects = poly!(topscene,
        lift(x -> getindex(x, 1), rects_and_colors),
        color = colors,
        show_axis = false,
        visible = map_is_categorical,
        inspectable = false
    )

    decorations[:categorical_map] = rects

    # for continous colormaps we sample a 1d image
    # to avoid white lines when rendering vector graphics

    continous_pixels = lift(vertical, nsteps, cgradient, limits, scale) do v, n, grad, lims, scale

        s_steps = scaled_steps(LinRange(0, 1, n), scale, lims)
        px = get.(Ref(grad), s_steps)
        v ? reshape(px, 1, n) : reshape(px, n, 1)
    end

    cont_image = image!(topscene,
        @lift(range(left($barbox), right($barbox), length = 2)),
        @lift(range(bottom($barbox), top($barbox), length = 2)),
        continous_pixels,
        visible = @lift(!$map_is_categorical),
        show_axis = false,
        interpolate = true,
        inspectable = false
    )

    decorations[:continuous_map] = cont_image

    highclip_tri = lift(barbox, spinewidth) do box, spinewidth
        if vertical[]
            lb, rb = topline(box)
            l = lb
            r = rb
            t = ((l .+ r) ./ 2) .+ Point2f(0, sqrt(sum((r .- l) .^ 2)) * sin(pi/3))
            [l, r, t]
        else
            b, t = rightline(box)
            r = ((b .+ t) ./ 2) .+ Point2f(sqrt(sum((t .- b) .^ 2)) * sin(pi/3), 0)
            [t, b, r]
        end
    end

    highclip_tri_color = Observables.map(highclip) do hc
        to_color(isnothing(hc) ? :transparent : hc)
    end

    highclip_visible = lift(x -> !(isnothing(x) || to_color(x) == to_color(:transparent)), highclip)

    highclip_tri_poly = poly!(topscene, highclip_tri, color = highclip_tri_color,
        strokecolor = :transparent,
        visible = highclip_visible, inspectable = false)

    decorations[:highclip] = highclip_tri_poly


    lowclip_tri = lift(barbox, spinewidth) do box, spinewidth
        if vertical[]
            lb, rb = bottomline(box)
            l = lb
            r = rb
            t = ((l .+ r) ./ 2) .- Point2f(0, sqrt(sum((r .- l) .^ 2)) * sin(pi/3))
            [l, r, t]
        else
            b, t = leftline(box)
            l = ((b .+ t) ./ 2) .- Point2f(sqrt(sum((t .- b) .^ 2)) * sin(pi/3), 0)
            [b, t, l]
        end
    end

    lowclip_tri_color = Observables.map(lowclip) do lc
        to_color(isnothing(lc) ? :transparent : lc)
    end

    lowclip_visible = lift(x -> !(isnothing(x) || to_color(x) == to_color(:transparent)), lowclip)

    lowclip_tri_poly = poly!(topscene, lowclip_tri, color = lowclip_tri_color,
        strokecolor = :transparent,
        visible = lowclip_visible, inspectable = false)

    decorations[:lowclip] = lowclip_tri_poly


    borderpoints = lift(barbox, highclip_visible, lowclip_visible) do bb, hcv, lcv
        if vertical[]
            points = [bottomright(bb), topright(bb)]
            if hcv
                push!(points, highclip_tri[][3])
            end
            append!(points, [topleft(bb), bottomleft(bb)])
            if lcv
                push!(points, lowclip_tri[][3])
            end
            push!(points, bottomright(bb))
            points
        else
            points = [bottomleft(bb), bottomright(bb)]
            if hcv
                push!(points, highclip_tri[][3])
            end
            append!(points, [topright(bb), topleft(bb)])
            if lcv
                push!(points, lowclip_tri[][3])
            end
            push!(points, bottomleft(bb))
            points
        end
    end

    decorations[:spines] = lines!(topscene, borderpoints, linewidth = spinewidth, color = topspinecolor, inspectable = false)

    axispoints = lift(barbox, vertical, flipaxis) do scenearea,
            vertical, flipaxis

        if vertical
            if flipaxis
                (bottomright(scenearea), topright(scenearea))
            else
                (bottomleft(scenearea), topleft(scenearea))
            end
        else
            if flipaxis
                (topleft(scenearea), topright(scenearea))
            else
                (bottomleft(scenearea), bottomright(scenearea))
            end
        end

    end

    axis = LineAxis(topscene, endpoints = axispoints, flipped = flipaxis,
        limits = limits, ticklabelalign = ticklabelalign, label = label,
        labelpadding = labelpadding, labelvisible = labelvisible, labelsize = labelsize,
        labelcolor = labelcolor,
        labelfont = labelfont, ticklabelfont = ticklabelfont, ticks = ticks, tickformat = tickformat,
        ticklabelsize = ticklabelsize, ticklabelsvisible = ticklabelsvisible, ticksize = ticksize,
        ticksvisible = ticksvisible, ticklabelpad = ticklabelpad, tickalign = tickalign,
        ticklabelrotation = ticklabelrotation,
        tickwidth = tickwidth, tickcolor = tickcolor, spinewidth = spinewidth,
        ticklabelspace = ticklabelspace, ticklabelcolor = ticklabelcolor,
        spinecolor = :transparent, spinevisible = :false, flip_vertical_label = flip_vertical_label,
        minorticksvisible = minorticksvisible, minortickalign = minortickalign,
        minorticksize = minorticksize, minortickwidth = minortickwidth,
        minortickcolor = minortickcolor, minorticks = minorticks, scale = scale)

    decorations[:axis] = axis

    onany(axis.protrusion, vertical, flipaxis) do axprotrusion,
            vertical, flipaxis


        left, right, top, bottom = 0f0, 0f0, 0f0, 0f0

        if vertical
            if flipaxis
                right += axprotrusion
            else
                left += axprotrusion
            end
        else
            if flipaxis
                top += axprotrusion
            else
                bottom += axprotrusion
            end
        end

        protrusions[] = GridLayoutBase.RectSides{Float32}(left, right, bottom, top)
    end

    # trigger protrusions with one of the attributes
    vertical[] = vertical[]

    # trigger bbox
    layoutobservables.suggestedbbox[] = layoutobservables.suggestedbbox[]

    Colorbar(fig_or_scene, layoutobservables, attrs, decorations)
end

function tight_ticklabel_spacing!(lc::Colorbar)
    tight_ticklabel_spacing!(lc.elements[:axis])
end

function scaled_steps(steps, scale, lims)
    # first scale to limits so we can actually apply the scale to the values
    # (log(0) doesn't work etc.)
    s_limits = steps .* (lims[2] - lims[1]) .+ lims[1]
    # scale with scaling function
    s_limits_scaled = scale.(s_limits)
    # then rescale to 0 to 1
    s_scaled = (s_limits_scaled .- s_limits_scaled[1]) ./ (s_limits_scaled[end] - s_limits_scaled[1])
end
