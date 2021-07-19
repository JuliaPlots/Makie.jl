################################################################################
#                             Projection utilities                             #
################################################################################

function project_position(scene, point, model)

    # use transform func
    point = Makie.apply_transform(scene.transformation.transform_func[], point)

    res = scene.camera.resolution[]
    p4d = to_ndim(Vec4f, to_ndim(Vec3f, point, 0f0), 1f0)
    clip = scene.camera.projectionview[] * model * p4d
    @inbounds begin
    # between -1 and 1
        p = (clip ./ clip[4])[Vec(1, 2)]
        # flip y to match cairo
        p_yflip = Vec2f(p[1], -p[2])
        # normalize to between 0 and 1
        p_0_to_1 = (p_yflip .+ 1f0) / 2f0
    end
    # multiply with scene resolution for final position
    return p_0_to_1 .* res
end

project_scale(scene::Scene, s::Number, model = Mat4f(I)) = project_scale(scene, Vec2f(s), model)

function project_scale(scene::Scene, s, model = Mat4f(I))
    p4d = to_ndim(Vec4f, s, 0f0)
    p = @inbounds (scene.camera.projectionview[] * model * p4d)[Vec(1, 2)] ./ 2f0
    return p .* scene.camera.resolution[]
end

function project_rect(scene, rect::Rect, model)
    mini = project_position(scene, minimum(rect), model)
    maxi = project_position(scene, maximum(rect), model)
    return Rect(mini, maxi .- mini)
end

function project_polygon(scene, poly::P, model) where P <: Polygon
    ext = decompose(Point2f, poly.exterior)
    interiors = decompose.(Point2f, poly.interiors)
    Polygon(
        Point2f.(project_position.(Ref(scene), ext, Ref(model))),
        [Point2f.(project_position.(Ref(scene), interior, Ref(model))) for interior in interiors],
    )
end

scale_matrix(x, y) = Cairo.CairoMatrix(x, 0.0, 0.0, y, 0.0, 0.0)

########################################
#          Rotation handling           #
########################################

function to_2d_rotation(x)
    quat = to_rotation(x)
    return -Makie.quaternion_to_2d_angle(quat)
end

function to_2d_rotation(::Makie.Billboard)
    @warn "This should not be reachable!"
    0
end

remove_billboard(x) = x
remove_billboard(b::Makie.Billboard) = b.rotation

to_2d_rotation(quat::Makie.Quaternion) = -Makie.quaternion_to_2d_angle(quat)

# TODO: this is a hack around a hack.
# Makie encodes the transformation from a 2-vector
# to a quaternion as a rotation around the Y-axis,
# when it should be a rotation around the X-axis.
# Since I don't know how to fix this in GLMakie,
# I've reversed the order of arguments to atan,
# such that our behaviour is consistent with GLMakie's.
to_2d_rotation(vec::Vec2f) = atan(vec[1], vec[2])

to_2d_rotation(n::Real) = n


################################################################################
#                                Color handling                                #
################################################################################

function rgbatuple(c::Colorant)
    rgba = RGBA(c)
    red(rgba), green(rgba), blue(rgba), alpha(rgba)
end

function rgbatuple(c)
    colorant = to_color(c)
    if !(colorant isa Colorant)
        error("Can't convert $(c) to a colorant")
    end
    return rgbatuple(colorant)
end

to_uint32_color(c) = reinterpret(UInt32, convert(ARGB32, c))

function numbers_to_colors(numbers::AbstractArray{<:Number}, primitive)

    colormap = get(primitive, :colormap, nothing) |> to_value |> to_colormap
    colorrange = get(primitive, :colorrange, nothing) |> to_value

    if colorrange === Makie.automatic
        colorrange = extrema(numbers)
    end

    Makie.interpolated_getindex.(
        Ref(colormap),
        Float64.(numbers), # ints don't work in interpolated_getindex
        Ref(colorrange))
end

########################################
#     Image/heatmap -> ARGBSurface     #
########################################

function to_cairo_image(img::AbstractMatrix{<: AbstractFloat}, attributes)
    to_cairo_image(to_rgba_image(img, attributes), attributes)
end

function to_rgba_image(img::AbstractMatrix{<: AbstractFloat}, attributes)
    Makie.@get_attribute attributes (colormap, colorrange, nan_color, lowclip, highclip)

    nan_color = Makie.to_color(nan_color)
    lowclip = isnothing(lowclip) ? lowclip : Makie.to_color(lowclip)
    highclip = isnothing(highclip) ? highclip : Makie.to_color(highclip)

    [get_rgba_pixel(pixel, colormap, colorrange, nan_color, lowclip, highclip) for pixel in img]
end

to_rgba_image(img::AbstractMatrix{<: Colorant}, attributes) = RGBAf.(img)

function get_rgba_pixel(pixel, colormap, colorrange, nan_color, lowclip, highclip)
    vmin, vmax = colorrange

    if isnan(pixel)
        RGBAf(nan_color)
    elseif pixel < vmin && !isnothing(lowclip)
        RGBAf(lowclip)
    elseif pixel > vmax && !isnothing(highclip)
        RGBAf(highclip)
    else
        RGBAf(Makie.interpolated_getindex(colormap, pixel, colorrange))
    end
end

function to_cairo_image(img::AbstractMatrix{<: Colorant}, attributes)
    to_cairo_image(to_uint32_color.(img), attributes)
end

function to_cairo_image(img::Matrix{UInt32}, attributes)
    # we need to convert from column-major to row-major storage,
    # therefore we permute x and y
    return Cairo.CairoARGBSurface(permutedims(img))
end


################################################################################
#                                Mesh handling                                 #
################################################################################

struct FaceIterator{Iteration, T, F, ET} <: AbstractVector{ET}
    data::T
    faces::F
end

function (::Type{FaceIterator{Typ}})(data::T, faces::F) where {Typ, T, F}
    FaceIterator{Typ, T, F}(data, faces)
end
function (::Type{FaceIterator{Typ, T, F}})(data::AbstractVector, faces::F) where {Typ, F, T}
    FaceIterator{Typ, T, F, NTuple{3, eltype(data)}}(data, faces)
end
function (::Type{FaceIterator{Typ, T, F}})(data::T, faces::F) where {Typ, T, F}
    FaceIterator{Typ, T, F, NTuple{3, T}}(data, faces)
end
function FaceIterator(data::AbstractVector, faces)
    if length(data) == length(faces)
        FaceIterator{:PerFace}(data, faces)
    else
        FaceIterator{:PerVert}(data, faces)
    end
end


Base.size(fi::FaceIterator) = size(fi.faces)
Base.getindex(fi::FaceIterator{:PerFace}, i::Integer) = fi.data[i]
Base.getindex(fi::FaceIterator{:PerVert}, i::Integer) = fi.data[fi.faces[i]]
Base.getindex(fi::FaceIterator{:Const}, i::Integer) = ntuple(i-> fi.data, 3)

color_or_nothing(c) = c === nothing ? nothing : to_color(c)

function per_face_colors(
        color, colormap, colorrange, matcap, vertices, faces, normals, uv,
        lowclip=nothing, highclip=nothing, nan_color=nothing
    )
    if matcap !== nothing
        wsize = reverse(size(matcap))
        wh = wsize .- 1
        cvec = map(normals) do n
            muv = 0.5n[Vec(1,2)] .+ Vec2f(0.5)
            x, y = clamp.(round.(Int, Tuple(muv) .* wh) .+ 1, 1, wh)
            return matcap[end - (y - 1), x]
        end
        return FaceIterator(cvec, faces)
    elseif color isa Colorant
        return FaceIterator{:Const}(color, faces)
    elseif color isa AbstractArray
        if color isa AbstractVector{<: Colorant}
            return FaceIterator(color, faces)
        elseif color isa AbstractArray{<: Number}
            low, high = extrema(colorrange)
            cvec = map(color[:]) do c
                if isnan(c) && nan_color !== nothing
                    return nan_color
                elseif c < low && lowclip !== nothing
                    return lowclip
                elseif c > high && highclip !== nothing
                    return highclip
                else
                    Makie.interpolated_getindex(colormap, c, colorrange)
                end
            end
            return FaceIterator(cvec, faces)
        elseif color isa AbstractMatrix{<: Colorant} && uv !== nothing
            wsize = reverse(size(color))
            wh = wsize .- 1
            cvec = map(uv) do uv
                x, y = clamp.(round.(Int, Tuple(uv) .* wh) .+ 1, 1, wh)
                return color[end - (y - 1), x]
            end
            # TODO This is wrong and doesn't actually interpolate
            # Inside the triangle sampling the color image
            return FaceIterator(cvec, faces)
        end
    end
    error("Unsupported Color type: $(typeof(color))")
end

mesh_pattern_set_corner_color(pattern, id, c::Colorant) =
    Cairo.mesh_pattern_set_corner_color_rgba(pattern, id, rgbatuple(c)...)
