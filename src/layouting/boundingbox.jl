using FreeTypeAbstraction: height_insensitive_boundingbox

"""
Calculates the exact boundingbox of a Scene/Plot, without considering any transformation
"""
raw_boundingbox(x::Atomic) = data_limits(x)


rootparent(x) = rootparent(parent(x))
rootparent(x::Scene) = x

# function raw_boundingbox(x::Annotations)
#     bb = raw_boundingbox(x.plots)
#     inv(modelmatrix(rootparent(x))) * bb
# end

raw_boundingbox(x::Combined) = raw_boundingbox(x.plots)
boundingbox(x) = raw_boundingbox(x)

function combined_modelmatrix(x)
    m = Mat4f(I)
    while true
        m = modelmatrix(x) * m
        if parent(x) !== nothing && parent(x) isa Combined
            x = parent(x)
        else
            break
        end
    end
    return m
end

function modelmatrix(x)
    t = transformation(x)
    transformationmatrix(t.translation[], t.scale[], t.rotation[])
end

function boundingbox(x::Atomic)
    bb = raw_boundingbox(x)
    return combined_modelmatrix(x) * bb
end

boundingbox(scene::Scene) = raw_boundingbox(scene)
function raw_boundingbox(scene::Scene)
    if scene[OldAxis] !== nothing
        return raw_boundingbox(scene[OldAxis])
    elseif scene.limits[] !== automatic
        return scene_limits(scene)
    elseif cameracontrols(scene) == EmptyCamera()
        # Empty camera means this is a parent scene that itself doesn't display anything
        return raw_boundingbox(scene.children)
    else
        plots = plots_from_camera(scene)
        children = filter(scene.children) do child
            child.camera == scene.camera
        end
        return raw_boundingbox([plots; children])
    end
end

function raw_boundingbox(plots::Vector)
    isempty(plots) && return Rect3f()
    plot_idx = iterate(plots)
    bb = Rect3f()
    while plot_idx !== nothing
        plot, idx = plot_idx
        plot_idx = iterate(plots, idx)
        # isvisible(plot) || continue
        bb2 = boundingbox(plot)
        isfinite_rect(bb) || (bb = bb2)
        isfinite_rect(bb2) || continue
        bb = union(bb, bb2)
    end
    return bb
end

function project_widths(matrix, vec)
    pr = project(matrix, vec)
    zero = project(matrix, zeros(typeof(vec)))
    return pr - zero
end

function rotate_bbox(bb::Rect3f, rot)
    points = decompose(Point3f, bb)
    Rect3f(Ref(rot) .* points)
end

function gl_bboxes(gl::GlyphCollection)
    scales = gl.scales.sv isa Vec2f ? (gl.scales.sv for _ in gl.extents) : gl.scales.sv
    map(gl.extents, gl.fonts, scales) do ext, font, scale
        unscaled_hi_bb = height_insensitive_boundingbox(ext, font)
        hi_bb = Rect2f(
            Makie.origin(unscaled_hi_bb) * scale,
            widths(unscaled_hi_bb) * scale
        )
    end
end

function boundingbox(glyphcollection::GlyphCollection, position::Point3f, rotation::Quaternion)

    if isempty(glyphcollection.glyphs)
        return Rect3f(position, Vec3f(0, 0, 0))
    end

    chars = glyphcollection.glyphs
    glyphorigins = glyphcollection.origins
    glyphbbs = gl_bboxes(glyphcollection)

    bb = Rect3f()
    for (char, charo, glyphbb) in zip(chars, glyphorigins, glyphbbs)
        # ignore line breaks
        # char in ('\r', '\n') && continue

        charbb = rotate_bbox(Rect3f(glyphbb), rotation) + charo + position
        if !isfinite_rect(bb)
            bb = charbb
        else
            bb = union(bb, charbb)
        end
    end
    !isfinite_rect(bb) && error("Invalid text boundingbox")
    bb
end

function boundingbox(layouts::AbstractArray{<:GlyphCollection}, positions, rotations)

    if isempty(layouts)
        Rect3f((0, 0, 0), (0, 0, 0))
    else
        bb = Rect3f()
        broadcast_foreach(layouts, positions, rotations) do layout, pos, rot
            if !isfinite_rect(bb)
                bb = boundingbox(layout, pos, rot)
            else
                bb = union(bb, boundingbox(layout, pos, rot))
            end
        end
        !isfinite_rect(bb) && error("Invalid text boundingbox")
        bb
    end
end

function boundingbox(x::Text{<:Tuple{<:GlyphCollection}})
    boundingbox(
        to_value(x[1]),
        to_ndim(Point3f, to_value(x[:position]), 0),
        convert_attribute(to_value(x[:rotation]), key"rotation"())
    )
end

function boundingbox(x::Text{<:Tuple{<:AbstractArray{<:GlyphCollection}}})
    boundingbox(
        to_value(x[1]),
        to_ndim.(Point3f, to_value(x[:position]), 0),
        convert_attribute(to_value(x[:rotation]), key"rotation"())
    )
end


#     if x.space[] == :data
#         if x[1][] isa AbstractArray
#             bb = Rect3f()
#             for
#         else
#             boundingbox(x, to_value(x[1]))
#         end
#     elseif x.space[] == :screen
#         data_limits(x)
#     end
# end


# boundingbox(x::Text) = boundingbox(x, to_value(x[1]))

# function boundingbox(
#         text::String, position, textsize;
#         font = "default", align = (:left, :bottom), rotation = 0.0
#     )
#     return boundingbox(
#         text, position, textsize,
#         to_font(font), to_align(align), to_rotation(rotation)
#     )
# end

"""
Calculate an approximation of a tight rectangle around a 2D rectangle rotated by `angle` radians.
This is not perfect but works well enough. Check an A vs X to see the difference.
"""
function rotatedrect(rect::Rect{2}, angle)
    ox, oy = rect.origin
    wx, wy = rect.widths
    points = @SMatrix([
        ox oy;
        ox oy+wy;
        ox+wx oy;
        ox+wx oy+wy;
    ])
    mrot = @SMatrix([
        cos(angle) -sin(angle);
        sin(angle) cos(angle);
    ])
    rotated = mrot * points'

    rmins = minimum(rotated, dims = 2)
    rmaxs = maximum(rotated, dims = 2)

    return Rect2(rmins..., (rmaxs .- rmins)...)
end

function quaternion_to_2d_angle(quat)
    # this assumes that the quaternion was calculated from a simple 2d rotation as well
    return 2acos(quat[4]) * (signbit(quat[1]) ? -1 : 1)
end

function boundingbox(
        text::String, position, textsize, font,
        align, rotation, model, justification, lineheight;
        # use the font's ascenders and descenders for the bounding box
        # this means that a string's boundingbox doesn't change in the vertical
        # dimension when characters change (for example numbers during an animation)
        # this is not wanted in most cases because of the jitter it creates when
        # the boundingbox slightly changes size in each frame (in MakieLayout mostly)
        use_vertical_dimensions_from_font = true
    )
    atlas = get_texture_atlas()
    N = length(text)
    ctext_state1 = iterate(text)
    ctext_state1 === nothing && return Rect3f()

    # call the layouting algorithm to find out where all the glyphs end up
    # this is kind of a doubling, maybe it could be avoided if at creation all
    # positions would be populated in the text object, but that seems convoluted
    if position isa VecTypes
        glyph_offsets = layout_text(text, textsize, font, align,
            rotation, model, justification, lineheight)
        position = [go .+ to_ndim(Point3f, position, 0) for go in glyph_offsets]
    end

    bbox = Ref(Rect3f())            # use ref to avoid julia#15276
    ctext_state = Ref{Union{Nothing,typeof(ctext_state1)}}(ctext_state1)

    let position = position
        broadcast_foreach(1:N, rotation, font, textsize) do i, rotation, font, scale
            c, text_state = ctext_state[]::typeof(ctext_state1)
            ctext_state[] = iterate(text, text_state)

            if !(c in ('\r', '\n'))
                bb_unitspace = if use_vertical_dimensions_from_font
                    height_insensitive_boundingbox(
                        FreeTypeAbstraction.get_extent(font, c), font)
                else
                    inkboundingbox(FreeTypeAbstraction.get_extent(font, c))
                end

                scaled_bb = bb_unitspace * scale

                # TODO this only works in 2d
                rot_2d_radians = quaternion_to_2d_angle(rotation)
                rotated_bb = rotatedrect(scaled_bb, rot_2d_radians)

                # bb = rectdiv(bb, 1.5)
                shifted_bb = Rect3f(rotated_bb) + position[i]
                bboxc = bbox[]
                if !isfinite_rect(bboxc)
                    bbox[] = shifted_bb
                else
                    bbox[] = union(bboxc, shifted_bb)
                end
            end
        end
    end
    return bbox[]
end
