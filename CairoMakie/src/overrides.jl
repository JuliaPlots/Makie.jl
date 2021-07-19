################################################################################
#                    Poly - the not so primitive, primitive                    #
################################################################################


"""
Special method for polys so we don't fall back to atomic meshes, which are much more
complex and slower to draw than standard paths with single color.
"""
function draw_plot(scene::Scene, screen::CairoScreen, poly::Poly)
    # dispatch on input arguments to poly to use smarter drawing methods than
    # meshes if possible
    draw_poly(scene, screen, poly, to_value.(poly.input_args)...)
end

"""
Fallback method for args without special treatment.
"""
function draw_poly(scene::Scene, screen::CairoScreen, poly, args...)
    draw_poly_as_mesh(scene, screen, poly)
end

function draw_poly_as_mesh(scene, screen, poly)
    draw_plot(scene, screen, poly.plots[1])
    draw_plot(scene, screen, poly.plots[2])
end


# in the rare case of per-vertex colors redirect to mesh drawing
function draw_poly(scene::Scene, screen::CairoScreen, poly, points::Vector{<:Point2}, color::AbstractArray, model, strokecolor, strokewidth)
    draw_poly_as_mesh(scene, screen, poly)
end

function draw_poly(scene::Scene, screen::CairoScreen, poly, points::Vector{<:Point2})
    draw_poly(scene, screen, poly, points, poly.color[], poly.model[], poly.strokecolor[], poly.strokewidth[])
end

function draw_poly(scene::Scene, screen::CairoScreen, poly, points::Vector{<:Point2}, color, model, strokecolor, strokewidth)
    points = project_position.(Ref(scene), points, Ref(model))
    Cairo.move_to(screen.context, points[1]...)
    for p in points[2:end]
        Cairo.line_to(screen.context, p...)
    end
    Cairo.close_path(screen.context)
    Cairo.set_source_rgba(screen.context, rgbatuple(to_color(color))...)
    Cairo.fill_preserve(screen.context)
    Cairo.set_source_rgba(screen.context, rgbatuple(to_color(strokecolor))...)
    Cairo.set_line_width(screen.context, strokewidth)
    Cairo.stroke(screen.context)
end

function draw_poly(scene::Scene, screen::CairoScreen, poly, points_list::Vector{<:Vector{<:Point2}})
    broadcast_foreach(points_list, poly.color[],
        poly.strokecolor[], poly.strokewidth[]) do points, color, strokecolor, strokewidth

            draw_poly(scene, screen, poly, points, color, poly.model[], strokecolor, strokewidth)
    end
end


draw_poly(scene::Scene, screen::CairoScreen, poly, rect::Rect2) = draw_poly(scene, screen, poly, [rect])

function draw_poly(scene::Scene, screen::CairoScreen, poly, rects::Vector{<:Rect2})
    model = poly.model[]
    projected_rects = project_rect.(Ref(scene), rects, Ref(model))

    color = poly.color[]
    if color isa AbstractArray{<:Number}
        color = numbers_to_colors(color, poly)
    elseif color isa String
        # string is erroneously broadcasted as chars otherwise
        color = to_color(color)
    end
    strokecolor = poly.strokecolor[]
    if strokecolor isa AbstractArray{<:Number}
        strokecolor = numbers_to_colors(strokecolor, poly)
    elseif strokecolor isa String
        # string is erroneously broadcasted as chars otherwise
        strokecolor = to_color(strokecolor)
    end

    broadcast_foreach(projected_rects, color, strokecolor, poly.strokewidth[]) do r, c, sc, sw
        Cairo.rectangle(screen.context, origin(r)..., widths(r)...)
        Cairo.set_source_rgba(screen.context, rgbatuple(to_color(c))...)
        Cairo.fill_preserve(screen.context)
        Cairo.set_source_rgba(screen.context, rgbatuple(to_color(sc))...)
        Cairo.set_line_width(screen.context, sw)
        Cairo.stroke(screen.context)
    end
end

function polypath(ctx, polygon)
    ext = decompose(Point2f, polygon.exterior)
    Cairo.move_to(ctx, ext[1]...)
    for point in ext[2:end]
        Cairo.line_to(ctx, point...)
    end
    Cairo.close_path(ctx)

    interiors = decompose.(Point2f, polygon.interiors)
    for interior in interiors
        Cairo.move_to(ctx, interior[1]...)
        for point in interior[2:end]
            Cairo.line_to(ctx, point...)
        end
        Cairo.close_path(ctx)
    end
end

function draw_poly(scene::Scene, screen::CairoScreen, poly, polygons::AbstractArray{<:Polygon})
    
    model = poly.model[]
    projected_polys = project_polygon.(Ref(scene), polygons, Ref(model))

    color = poly.color[]
    if color isa AbstractArray{<:Number}
        color = numbers_to_colors(color, poly)
    elseif color isa String
        # string is erroneously broadcasted as chars otherwise
        color = to_color(color)
    end
    strokecolor = poly.strokecolor[]
    if strokecolor isa AbstractArray{<:Number}
        strokecolor = numbers_to_colors(strokecolor, poly)
    elseif strokecolor isa String
        # string is erroneously broadcasted as chars otherwise
        strokecolor = to_color(strokecolor)
    end

    broadcast_foreach(projected_polys, color, strokecolor, poly.strokewidth[]) do po, c, sc, sw
        polypath(screen.context, po)
        Cairo.set_source_rgba(screen.context, rgbatuple(to_color(c))...)
        Cairo.fill_preserve(screen.context)
        Cairo.set_source_rgba(screen.context, rgbatuple(to_color(sc))...)
        Cairo.set_line_width(screen.context, sw)
        Cairo.stroke(screen.context)
    end

end


################################################################################
#                                     Band                                     #
#     Override because band is usually a polygon, but because it supports      #
#        gradients as well via `mesh` we have to intercept the poly use        #
################################################################################

function draw_plot(scene::Scene, screen::CairoScreen,
        band::Band{<:Tuple{<:AbstractVector{<:Point2},<:AbstractVector{<:Point2}}})

    if !(band.color[] isa AbstractArray)
        upperpoints = band[1][]
        lowerpoints = band[2][]
        points = vcat(lowerpoints, reverse(upperpoints))
        model = band.model[]
        points = project_position.(Ref(scene), points, Ref(model))
        Cairo.move_to(screen.context, points[1]...)
        for p in points[2:end]
            Cairo.line_to(screen.context, p...)
        end
        Cairo.close_path(screen.context)
        Cairo.set_source_rgba(screen.context, rgbatuple(to_color(band.color[]))...)
        Cairo.fill(screen.context)
    else
        for p in band.plots
            draw_plot(scene, screen, p)
        end
    end

    nothing
end