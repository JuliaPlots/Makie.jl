using Colors, ColorVectorSpace, StaticArrays
using GeometryTypes, Interpolations


@inline function edge_function(a, b, c)
    (c[1] - a[1]) * (b[2] - a[2]) - (c[2] - a[2]) * (b[1] - a[1])
end

@inline function src_alpha(c::T) where T <: Colorant
    a = alpha(c)
    a == 0.0 && return zero(T)
    c ./ a
end

one_minus_alpha(c::T) where {T <: Colorant} = one(T) .- src_alpha(c)
blend(source, dest, src_func, dest_func) = clamp01(src_func(source) .+ dest_func(dest))
ColorTypes.alpha(x::StaticVector) = x[4]
function standard_transparency(source, dest::T) where T
    (alpha(source) .* source) .+ ((one(eltype(T)) - alpha(source)) .* dest)
end


mutable struct FixedGeomView{GeomOut, VT}
    buffer::Vector{GeomOut}
    view::VT
    idx::Int
end

function FixedGeomView(T, max_primitives, primitive_in, primitive_out)
    buffer = Vector{Tuple{Point4f, T}}(max_primitives)
    # TODO implement primitive_in and out correctly
    # this is for triangle_strip and 4 max_primitives
    if max_primitives != 4 || primitive_out != :triangle_strip
        error("Not implemented for max_primitives == $max_primitives and primitive_out == $primitive_out.")
    end
    geometry_view = if primitive_out == :triangle_strip
        view(buffer, [TriangleFace(1, 2, 3), TriangleFace(3, 2, 4)])
    else
        error("$primitive_out not supported. Only :triangle_strip supported right now")
    end
    FixedGeomView(buffer, geometry_view, 1)
end

function reset!(A::FixedGeomView)
    A.idx = 1
end
function Base.push!(A::FixedGeomView, element)
    if A.idx > length(A.buffer)
        error("Emit called more often than max_primitives. max_primitives: $(length(A.buffer))")
    end
    A.buffer[A.idx] = element
    A.idx += 1
    return
end

struct JLRasterizer{Vertex, Args, FragN, VS, FS, GS, GV, EF}
    vertexshader::VS
    fragmentshader::FS

    geometryshader::GS
    geometry_view::GV
    emit::EF
end

function JLRasterizer{Vertex, Args, FragN}(
        vertexshader::VS,
        fragmentshader::FS,
        geometryshader::GS,
        geometry_view::GV,
        emit::EF
    ) where {Vertex, Args, FragN, VS, FS, GS, GV, EF}
    JLRasterizer{Vertex, Args, FragN, VS, FS, GS, GV, EF}(
        vertexshader,
        fragmentshader,
        geometryshader,
        geometry_view,
        emit
    )
end

function geometry_return_type(vertex_array, vertexshader, geometryshader, uniforms)
    typ = Any
    emit_t(position, ::T) where {T} = (typ = T)
    face1 = first(vertex_array)
    vertex_stage = map(reverse(face1)) do f
        vertexshader(f, uniforms...)
    end
    geometryshader(emit_t, vertex_stage, uniforms...) # figure out typ
    typ
end

arglength(::Type{T}) where {T <: Tuple} = length(T.parameters)
arglength(::Type{T}) where {T <: AbstractArray} = 1
arglength(::Type{T}) where {T} = nfields(T)


function rasterizer(
        vertexarray::AbstractArray,
        uniforms::Tuple,
        vertexshader::Function,
        fragmentshader::Function;
        geometryshader = nothing,
        max_primitives = 4,
        primitive_in = :points,
        primitive_out = :triangle_strip,
    )

    emit, geometry_view = nothing, nothing
    fragment_in_ndim = if geometryshader != nothing
        T = geometry_return_type(vertexarray, vertexshader, geometryshader, uniforms)
        geometry_view = FixedGeomView(T, max_primitives, primitive_in, primitive_out)
        emit = (position, fragment_args) -> push!(geometry_view, (position, fragment_args))
        arglength(T)
    else
        # when we don't have a geometry shader, vertex shader will feed fragment shader
        T = Base.Core.Inference.return_type(vertexshader, Tuple{eltype(vertexarray), map(typeof, uniforms)...})
        if T <: Tuple
            # TODO error handling
            arglength(T.parameters[2])
        else # if not a tuple, vertex shader doesn't pass any arguments to fragment shader
            0
        end
    end

    raster = JLRasterizer{eltype(vertexarray), typeof(uniforms), fragment_in_ndim}(
        vertexshader,
        fragmentshader,
        geometryshader,
        geometry_view,
        emit
    )
    raster, (vertexarray, uniforms)
end


Base.@pure Next(::Val{N}) where {N} = Val(N - 1)
@inline function interpolate(bary, face::NTuple{N, T}, vn::Val{0}, aggregate) where {N, T}
    if T <: Tuple
        aggregate
    else
        T(aggregate...)
    end
end
@inline function interpolate(bary, face, vn::Val{N}, aggregate = ()) where N
    @inbounds begin
        res = (
            bary[1] * getfield(face[1], N) .+
            bary[2] * getfield(face[2], N) .+
            bary[3] * getfield(face[3], N)
        )
    end
    interpolate(bary, face, Next(vn), (res, aggregate...))
end

broadcastmin(a, b) = min.(a, b)
broadcastmax(a, b) = max.(a, b)


function clip2pixel_space(position, resolution)
    clipspace = position / position[4]
    p = clipspace[Vec(1, 2)]
    (((p + 1f0) / 2f0) .* (resolution - 1f0)) + 1f0, clipspace[3]
end


function (r::JLRasterizer{Vert, Args, FragN})(
        canvas, vertex_array::AbstractArray{Vert}, uniforms::Args
    ) where {Vert, Args, FragN}
    framebuffers = canvas.color; depthbuffer = canvas.depth
    resolution = Vec2f(size(framebuffers[1]))
    # hoisting out functions... Seems to help inference a bit. Or not?
    vshader = r.vertexshader
    gshader = r.geometryshader
    fshader = r.fragmentshader
    FragNVal = Val(FragN)
    fragments_drawn = 0
    for face in vertex_array
        vertex_stage = map(reverse(face)) do f
            vshader(f, uniforms...)
        end
        geom_stage = if isa(r.geometryshader, Nothing)
            (vertex_stage,)
        else
            reset!(r.geometry_view)
            gshader(r.emit, vertex_stage, uniforms...)
            r.geometry_view.view
        end
        for geom_face in geom_stage
            fdepth = map(geom_face) do vert
                fv = first(vert)
                clip2pixel_space(fv, resolution)
            end
            f = map(first, fdepth)
            depths = map(last, fdepth)
            vertex_out = map(last, geom_face)
            # Bounding rectangle
            mini = max.(reduce(broadcastmin, f), 1f0)
            maxi = min.(reduce(broadcastmax, f), resolution)
            area = edge_function(f[1], f[2], f[3])
            for y = mini[2]:maxi[2]
                for x = mini[1]:maxi[1]
                    p = Vec(x, y)
                    w = Vec(
                        edge_function(f[2], f[3], p),
                        edge_function(f[3], f[1], p),
                        edge_function(f[1], f[2], p)
                    )
                    yi, xi = round(Int, y), round(Int, x)
                    if all(w-> w >= 0f0, w) && checkbounds(Bool, framebuffers[1], yi, xi)

                        bary = w / area
                        depth = bary[1] * depths[1] + bary[2] * depths[2] + bary[3] * depths[3]

                        if depth <= depthbuffer[yi, xi]
                            depthbuffer[yi, xi] = depth
                            fragment_in = interpolate(bary, vertex_out, FragNVal)
                            fragment_out = fshader(fragment_in, uniforms...)
                            for i = eachindex(fragment_out)
                                src_color = framebuffers[i][yi, xi]
                                dest_color = fragment_out[i]
                                fragments_drawn += 1
                                framebuffers[i][yi, xi] = standard_transparency(
                                    src_color,
                                    RGBA{Float32}(dest_color[1], dest_color[2], dest_color[3], dest_color[4])
                                )
                            end
                        end
                    end
                end
            end
        end
    end
    println("fragments drawn: ", fragments_drawn)
    return
end
circle(uv::Vec{2, T}) where {T} = T(0.5) - norm(uv)
"""
smoothstep performs smooth Hermite interpolation between 0 and 1 when edge0 < x < edge1. This is useful in cases where a threshold function with a smooth transition is desired. smoothstep is equivalent to:
```
    t = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
```
Results are undefined if edge0 ≥ edge1.
"""
function smoothstep(edge0, edge1, x::T) where T
    t = clamp.((x .- edge0) ./ (edge1 .- edge0), T(0), T(1))
    return t * t * (T(3) - T(2) * t)
end
function aastep(threshold1::T, value) where T
    afwidth = norm(Vec2f(dFdx(value), dFdy(value))) * T(1.05);
    smoothstep(threshold1 - afwidth, threshold1 + afwidth, value)
end
function aastep(threshold1::T, threshold2::T, value::T) where T
    afwidth = norm(Vec2f(dFdx(value), dFdy(value))) * T(1.05);
    return (
        smoothstep(threshold1 - afwidth, threshold1 + afwidth, value) -
        smoothstep(threshold2 - afwidth, threshold2 + afwidth, value)
    )
end

"""
Gradient in x direction
This is sadly a bit hard to implement for a pure CPU versions, since it's pretty much backed into the GPU hardware.
How it seems to work is, that it takes the values from neighboring registers, which work in parallel on the pixels
of the triangle, so they actually do hold the neighboring values needed to calculate the gradient.
"""
dFdx(value::T) where {T} = T(0.001) # just default to a small gradient if it's called on the CPU
dFdy(value::T) where {T} = T(0.001) # just default to a small gradient if it's called on the CPU

mutable struct Uniforms{F}
    projection::Mat4f
    strokecolor::Vec4f
    glowcolor::Vec4f
    distance_func::F
end

mutable struct TextUniforms
    projection::Mat4f
    strokecolor::Vec4f
    glowcolor::Vec4f
end


struct VertexCS{N, T}
    position::Vec{N, T}
    color::Vec4f
    scale::Vec2f
end

struct Vertex2Geom
    uvrect::Vec4f
    color::Vec4f
    rect::Vec4f
end

function vert_particles(vertex, uniforms)
    p = vertex.position
    scale = vertex.scale
    return Vertex2Geom(
        Vec4f(0,0,1,1),
        vertex.color,
        Vec4f(p[1], p[2], scale[1], scale[2])
    )
end


"""
Emits a vertex with
"""
function emit_vertex(emit!, vertex, uv, arg, pos, uniforms)
    datapoint = uniforms.projection * Vec4f(pos[1], pos[2], 0, 1)
    final_position = uniforms.projection * Vec4f(vertex[1], vertex[2], 0, 0)
    emit!(datapoint .+ final_position, (uv, arg.color))
    return
end

function geom_particles(emit!, vertex_out, uniforms, image)
    geom_particles(emit!, vertex_out, uniforms)
    return
end
function geom_particles(emit!, vertex_out, uniforms)
    # get arguments from first face
    # (there is only one in there anywas, since primitive type is point)
    # (position, vertex_out)
    arg = vertex_out[1]
    # emit quad as triangle strip
    # v3. ____ . v4
    #    |\   |
    #    | \  |
    #    |  \ |
    #    |___\|
    # v1*      * v2
    pos_scale = arg.rect
    pos = pos_scale[Vec(1, 2)]
    scale = pos_scale[Vec(3, 4)]
    quad = Vec4f(0f0, 0f0, scale[1], scale[2])
    uv = arg.uvrect
    emit_vertex(emit!, quad[Vec(1, 2)], uv[Vec(1, 4)], arg, pos, uniforms)
    emit_vertex(emit!, quad[Vec(1, 4)], uv[Vec(1, 2)], arg, pos, uniforms)
    emit_vertex(emit!, quad[Vec(3, 2)], uv[Vec(3, 4)], arg, pos, uniforms)
    emit_vertex(emit!, quad[Vec(3, 4)], uv[Vec(3, 2)], arg, pos, uniforms)
    return
end


function sdf2color(dist, bg_color, color)
    inside = aastep(0f0, dist)
    mix(bg_color, color, inside)
end
function frag_particles(geom_out, uniforms, image)
    uv = geom_out[1]; color = geom_out[2]
    dist = -image[uv][1]
    bg_color = Vec4f(0f0, 0f0, 0f0, 0f0)
    (sdf2color(dist, bg_color, color), )
end
function frag_particles(geom_out, uniforms)
    uv = geom_out[1]; color = geom_out[2]
    dist = uniforms.distance_func(uv)
    bg_color = Vec4f(0f0, 0f0, 0f0, 0f0)
    (sdf2color(dist, bg_color, color), )
end

function orthographicprojection(wh::Rect2, near::T, far::T) where T
    orthographicprojection(zero(T), T(wh.w), zero(T), T(wh.h), near, far)
end
function orthographicprojection(
        ::Type{T}, wh::Rect2, near::Number, far::Number
    ) where T
    orthographicprojection(wh, T(near), T(far))
end

function orthographicprojection(
        left  ::T, right::T,
        bottom::T, top  ::T,
        znear ::T, zfar ::T
    ) where T
    (right==left || bottom==top || znear==zfar) && return Mat{4,4,T}(I)
    T0, T1, T2 = zero(T), one(T), T(2)
    Mat{4}(
        T2/(right-left), T0, T0,  T0,
        T0, T2/(top-bottom), T0,  T0,
        T0, T0, -T2/(zfar-znear), T0,
        -(right+left)/(right-left), -(top+bottom)/(top-bottom), -(zfar+znear)/(zfar-znear), T1
    )
end
function orthographicprojection(::Type{T},
        left  ::Number, right::Number,
        bottom::Number, top  ::Number,
        znear ::Number, zfar ::Number
    ) where T
    orthographicprojection(
        T(left),   T(right),
        T(bottom), T(top),
        T(znear),  T(zfar)
    )
end

proj = orthographicprojection(Rect2(0, 0, resolution...), -10_000f0, 10_000f0)

uniforms = Uniforms(
    proj,
    Vec4f(1, 0, 0, 1),
    Vec4f(1, 0, 1, 1),
    circle
)


N = 10
middle = Vec2f(resolution) / 2f0
radius = min(resolution...) / 2f0
vertices = [(VertexCS(
    Vec2f((sin(2pi * (i / N)) , cos(2pi * (i / N))) .* radius) .+ middle,
    Vec4f(1, i/N, 0, 1),
    Vec2f(40, 40)
),) for i = 1:N]


raster, rest = rasterizer(
    vertices,
    (uniforms,),
    vert_particles,
    frag_particles;
    geometryshader = geom_particles,
    max_primitives = 4,
    primitive_in = :points,
    primitive_out = :triangle_strip,
)

struct Canvas{N}
    color::NTuple{N, Matrix{RGBA{Float32}}}
    depth::Matrix{Float32}
end
function canvas(xdim::Integer, ydim::Integer)
    color = Matrix{RGBA{Float32}}(xdim, ydim)
    color .= identity.(RGBA{Float32}(0,0,0,0))
    depth = ones(Float32, xdim, ydim)
    Canvas((color,), depth)
end

w = canvas(1024, 1024)


mix(x, y, a::T) where {T} = x .* (T(1) .- a) .+ y .* a

fract(x) = x - floor(x)
fabs(x::AbstractFloat) = abs(x)
raster(w, vertices, (uniforms,))
using Imagesp
w.color[1]
