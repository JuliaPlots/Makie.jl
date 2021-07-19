#=
A lot of visualization forms in GLVisualize are realised in the form of instanced
particles. This is because they can be handled very efficiently by OpenGL.
There are quite a few different ways to feed instances with different attributes.
The main constructor for particles is a tuple of (Primitive, Position), whereas
position can come in all forms and shapes. You can leave away the primitive.
In that case, GLVisualize will fill in some default that is anticipated to make
the most sense for the datatype.
=#

#3D primitives
const Primitives3D = Union{AbstractGeometry{3}, AbstractMesh}
#2D primitives AKA sprites, since they are shapes mapped onto a 2D rectangle
const Sprites = Union{AbstractGeometry{2}, Shape, Char, Type}
const AllPrimitives = Union{AbstractGeometry, Shape, Char, AbstractMesh}

using Makie: RectanglePacker

# There is currently no way to get the two following two signatures
# under one function, which is why we delegate to meshparticle
function _default(
        p::Tuple{TOrSignal{Pr}, VectorTypes{P}}, s::Style, data::Dict
    ) where {Pr <: Primitives3D, P <: Point}
    return meshparticle(p, s, data)
end

function to_meshcolor(color::TOrSignal{Vector{T}}) where T <: Colorant
    TextureBuffer(color)
end

function to_meshcolor(color::TOrSignal{Matrix{T}}) where T <: Colorant
    Texture(color)
end
function to_meshcolor(color)
    color
end

function to_mesh(mesh::TOrSignal{<: GeometryPrimitive})
    return NativeMesh(const_lift(GeometryBasics.normal_mesh, mesh))
end

function to_mesh(mesh::TOrSignal{<: GeometryBasics.Mesh})
    return NativeMesh(mesh)
end

using Makie
using Makie: get_texture_atlas

vec2quaternion(rotation::StaticVector{4}) = rotation

function vec2quaternion(r::StaticVector{2})
    vec2quaternion(Vec3f(r[1], r[2], 0))
end
function vec2quaternion(rotation::StaticVector{3})
    Makie.rotation_between(Vec3f(0, 0, 1), Vec3f(rotation))
end

vec2quaternion(rotation::Vec4f) = rotation
vec2quaternion(rotation::VectorTypes) = const_lift(x-> vec2quaternion.(x), rotation)
vec2quaternion(rotation::Node) = lift(vec2quaternion, rotation)
vec2quaternion(rotation::Makie.Quaternion)= Vec4f(rotation.data)
vec2quaternion(rotation)= vec2quaternion(to_rotation(rotation))
GLAbstraction.gl_convert(rotation::Makie.Quaternion)= Vec4f(rotation.data)


"""
This is the main function to assemble particles with a GLNormalMesh as a primitive
"""
function meshparticle(p, s, data)
    rot = get!(data, :rotation, Vec4f(0, 0, 0, 1))
    rot = vec2quaternion(rot)
    delete!(data, :rotation)
    @gen_defaults! data begin
        primitive = p[1] => to_mesh
        position = p[2] => TextureBuffer
        position_x = nothing => TextureBuffer
        position_y = nothing => TextureBuffer
        position_z = nothing => TextureBuffer

        scale = Vec3f(1) => TextureBuffer
        scale_x = nothing => TextureBuffer
        scale_y = nothing => TextureBuffer
        scale_z = nothing => TextureBuffer

        rotation = rot => TextureBuffer
        texturecoordinates = nothing
        shading = true
    end

    @gen_defaults! data begin
        color_map = nothing => Texture
        color_norm = nothing
        intensity = nothing
        image = nothing
        color = if color_map == nothing
            default(RGBA{Float32}, s)
        else
            nothing
        end => to_meshcolor
        vertex_color = Vec4f(1)
        matcap = nothing => Texture
        fetch_pixel = false
        uv_scale = Vec2f(1)

        instances = const_lift(length, position)
        shading = true
        backlight = 0f0
        shader = GLVisualizeShader(
            "util.vert", "particles.vert", "fragment_output.frag", "standard.frag",
            view = Dict(
                "position_calc" => position_calc(position, position_x, position_y, position_z, TextureBuffer),
                "light_calc" => light_calc(shading)
            )
        )
    end
    if Makie.to_value(intensity) != nothing
        if Makie.to_value(position) != nothing
            data[:intensity] = intensity_convert_tex(intensity, position)
            data[:len] = const_lift(length, position)
        else
            data[:intensity] = intensity_convert_tex(intensity, position_x)
            data[:len] = const_lift(length, position_x)
        end
    end
    data
end

to_pointsize(x::Number) = Float32(x)
to_pointsize(x) = Float32(x[1])

struct PointSizeRender
    size::Observable
end
(x::PointSizeRender)() = glPointSize(to_pointsize(x.size[]))
"""
This is the most primitive particle system, which uses simple points as primitives.
This is supposed to be the fastest way of displaying particles!
"""
function _default(position::VectorTypes{T}, s::style"speed", data::Dict) where T <: Point
    @gen_defaults! data begin
        vertex       = position => GLBuffer
        color_map    = nothing  => Texture
        color        = (color_map == nothing ? default(RGBA{Float32}, s) : nothing) => GLBuffer
        color_norm   = nothing
        scale        = 2f0
        shader       = GLVisualizeShader("fragment_output.frag", "dots.vert", "dots.frag")
        gl_primitive = GL_POINTS
    end
    data[:prerender] = PointSizeRender(data[:scale])
    data
end

"""
returns the Shape for the distancefield algorithm
"""
primitive_shape(::Char) = DISTANCEFIELD
primitive_shape(x::X) where {X} = primitive_shape(X)
primitive_shape(::Type{T}) where {T <: Circle} = CIRCLE
primitive_shape(::Type{T}) where {T <: Rect2} = RECTANGLE
primitive_shape(x::Shape) = x

"""
Extracts the scale from a primitive.
"""
primitive_scale(prim::GeometryPrimitive) = Vec2f(widths(prim))
primitive_scale(::Union{Shape, Char}) = Vec2f(40)
primitive_scale(c) = Vec2f(0.1)

"""
Extracts the offset from a primitive.
"""
primitive_offset(x, scale::Nothing) = Vec2f(0) # default offset
primitive_offset(x, scale) = const_lift(/, scale, -2f0)  # default offset


"""
Extracts the uv offset and width from a primitive.
"""
primitive_uv_offset_width(c::Char) = glyph_uv_width!(c)
primitive_uv_offset_width(x) = Vec4f(0,0,1,1)

"""
Gets the texture atlas if primitive is a char.
"""
primitive_distancefield(x) = nothing
primitive_distancefield(::Char) = get_texture!(get_texture_atlas())
primitive_distancefield(::Node{Char}) = get_texture!(get_texture_atlas())

function _default(
        p::Tuple{TOrSignal{Matrix{C}}, VectorTypes{P}}, s::Style, data::Dict
    ) where {C <: Colorant, P <: Point}
    data[:image] = p[1] # we don't want this to be overwritten by user
    @gen_defaults! data begin
        scale = lift(x-> Vec2f(size(x)), p[1])
        shape = RECTANGLE
        offset = Vec2f(0)
    end
    sprites(p, s, data)
end

function _default(
        p::Tuple{TOrSignal{Matrix{C}}, VectorTypes{P}}, s::Style, data::Dict
    ) where {C <: AbstractFloat, P <: Point}
    data[:distancefield] = p[1] # we don't want this to be overwritten by user
    @gen_defaults! data begin
        scale = lift(x-> Vec2f(size(x)), p[1])
        shape = RECTANGLE
        offset = Vec2f(0)
    end
    sprites(p, s, data)
end

function _default(
        p::Tuple{VectorTypes{Matrix{C}}, VectorTypes{P}}, s::Style, data::Dict
    ) where {C <: Colorant, P <: Point}
    images = to_value(p[1])
    isempty(images) && error("Can not display empty vector of images as primitive")
    sizes = map(size, images)
    if !all(x-> x == sizes[1], sizes) # if differently sized
        # create texture atlas
        maxdims = sum(map(Vec{2, Int}, sizes))
        rectangles = map(x->Rect2(0, 0, x...), sizes)
        rpack = RectanglePacker(Rect2(0, 0, maxdims...))
        uv_coordinates = [push!(rpack, rect).area for rect in rectangles]
        max_xy = maximum(maximum.(uv_coordinates))
        texture_atlas = Texture(C, (max_xy...,))
        for (area, img) in zip(uv_coordinates, images)
            texture_atlas[area] = img #transfer to texture atlas
        end
        data[:uv_offset_width] = map(uv_coordinates) do uv
            m = max_xy .- 1
            mini = reverse((minimum(uv)) ./ m)
            maxi = reverse((maximum(uv) .- 1) ./ m)
            return Vec4f(mini..., maxi...)
        end
        images = texture_atlas
    end
    data[:image] = images # we don't want this to be overwritten by user
    @gen_defaults! data begin
        shape = RECTANGLE
        offset = Vec2f(0)
    end
    sprites(p, s, data)
end

# There is currently no way to get the two following two signatures
# under one function, which is why we delegate to sprites
_default(p::Tuple{TOrSignal{Pr}, VectorTypes{P}}, s::Style, data::Dict) where {Pr <: Sprites, P<:Point} =
    sprites(p,s,data)


function _default(
            p::Tuple{TOrSignal{Pr}, G}, s::Style, data::Dict
        ) where {Pr <: Sprites, G <: Tuple}
    @gen_defaults! data begin
        shape      = const_lift(primitive_shape, p[1])
        position   = nothing => GLBuffer
        position_x = p[2][1] => GLBuffer
        position_y = p[2][2] => GLBuffer
        position_z = length(p[2]) > 2 ? p[2][3] : 0f0 => GLBuffer
    end
    sprites(p, s, data)
end

"""
Main assemble functions for sprite particles.
Sprites are anything like distance fields, images and simple geometries
"""
function sprites(p, s, data)
    rot = get!(data, :rotation, Vec4f(0, 0, 0, 1))
    rot = vec2quaternion(rot)
    delete!(data, :rotation)

    @gen_defaults! data begin
        shape       = const_lift(x-> Int32(primitive_shape(x)), p[1])
        position    = p[2]    => GLBuffer
        position_x  = nothing => GLBuffer
        position_y  = nothing => GLBuffer
        position_z  = nothing => GLBuffer

        scale       = const_lift(primitive_scale, p[1]) => GLBuffer
        scale_x     = nothing => GLBuffer
        scale_y     = nothing => GLBuffer
        scale_z     = nothing => GLBuffer

        rotation    = rot => GLBuffer
        image       = nothing => Texture
    end
    # TODO don't make this dependant on some shady type dispatch
    if isa(to_value(p[1]), Char) && !isa(to_value(scale), Union{StaticVector, AbstractVector{<: StaticVector}}) # correct dimensions
        data[:scale] = const_lift(correct_scale, p[1], scale)
    end

    @gen_defaults! data begin
        offset          = primitive_offset(p[1], scale) => GLBuffer
        intensity       = nothing => GLBuffer
        color_map       = nothing => Texture
        color_norm      = nothing
        color           = (color_map == nothing ? default(RGBA, s) : nothing) => GLBuffer

        glow_color      = RGBA{Float32}(0,0,0,0) => GLBuffer
        stroke_color    = RGBA{Float32}(0,0,0,0) => GLBuffer
        stroke_width    = 0f0
        glow_width      = 0f0
        uv_offset_width = const_lift(primitive_uv_offset_width, p[1]) => GLBuffer

        distancefield   = primitive_distancefield(p[1]) => Texture
        indices         = const_lift(length, p[2]) => to_index_buffer
        # rotation and billboard don't go along
        billboard        = rotation == Vec4f(0,0,0,1) => "if `billboard` == true, particles will always face camera"
        fxaa             = false
        shader           = GLVisualizeShader(
            "fragment_output.frag", "util.vert", "sprites.geom",
            "sprites.vert", "distance_shape.frag",
            view = Dict("position_calc"=>position_calc(position, position_x, position_y, position_z, GLBuffer))
        )
        scale_primitive = true
        gl_primitive = GL_POINTS
    end
    # Exception for intensity, to make it possible to handle intensity with a
    # different length compared to position. Intensities will be interpolated in that case
    if position != nothing
        data[:intensity] = intensity_convert(intensity, position)
        data[:len] = const_lift(length, position)
    else
        data[:intensity] = intensity_convert(intensity, position_x)
        data[:len] = const_lift(length, position_x)
    end
    return data
end


"""
Transforms text into a particle system of sprites, by inferring the
texture coordinates in the texture atlas, widths and positions of the characters.
"""
function _default(main::Tuple{TOrSignal{S}, P}, s::Style, data::Dict) where {S <: AbstractString, P}
    data[:position] = main[2]
    _default(main[1], s, data)
end

function _default(main::TOrSignal{S}, s::Style, data::Dict) where S <: AbstractString
    @gen_defaults! data begin
        relative_scale  = 4 #
        start_position  = Point2f(0)
        atlas           = get_texture_atlas()
        distancefield   = get_texture!(atlas)
        stroke_width    = 0f0
        glow_width      = 0f0
        font            = to_font("default")
        scale_primitive = true
        position        = const_lift(calc_position, main, start_position, relative_scale, font, atlas)
        offset          = const_lift(calc_offset, main, relative_scale, font, atlas)
        prerender       = () -> begin
            glDisable(GL_DEPTH_TEST)
            glDepthMask(GL_TRUE)
            glDisable(GL_CULL_FACE)
            enabletransparency()
        end
        uv_offset_width = const_lift(main) do str
            Vec4f[glyph_uv_width!(atlas, c, font) for c = str]
        end
        scale = const_lift(main, relative_scale) do str, s
            Vec2f[glyph_scale!(atlas, c, font, s) for c = str]
        end
    end
    delete!(data, :font)
    _default((DISTANCEFIELD, position), s, data)
end
