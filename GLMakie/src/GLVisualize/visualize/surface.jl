
# surface(::Matrix, ::Matrix, ::Matrix)
function _default(main::Tuple{MatTypes{T}, MatTypes{T}, MatTypes{T}}, s::Style{:surface}, data::Dict) where T <: AbstractFloat
    @gen_defaults! data begin
        position_x = main[1] => (Texture, "x position, must be a `Matrix{Float}`")
        position_y = main[2] => (Texture, "y position, must be a `Matrix{Float}`")
        position_z = main[3] => (Texture, "z position, must be a `Matrix{Float}`")
        scale = Vec3f(0) => "scale must be 0, for a surfacemesh"
    end
    surface(position_z, s, data)
end

# surface(Vector or Range, Vector or Range, ::Matrix)
function _default(main::Tuple{VectorTypes{T}, VectorTypes{T}, MatTypes{T}}, s::Style{:surface}, data::Dict) where T <: AbstractFloat
    @gen_defaults! data begin
        position_x = main[1] => (Texture, "x position, must be a `Vector{Float}`")
        position_y = main[2] => (Texture, "y position, must be a `Vector{Float}`")
        position_z = main[3] => (Texture, "z position, must be a `Matrix{Float}`")
        scale = Vec3f(0) => "scale must be 0, for a surfacemesh"
    end
    surface(position_z, s, data)
end

# surface(::Matrix)
function _default(main::MatTypes{T}, s::Style{:surface}, data::Dict) where T <: AbstractFloat
    @gen_defaults! data begin
        ranges = ((-1f0, 1f0), (-1f0,1f0)) => "x, and y position given as `(start, endvalue)` or any `Range`"
    end
    delete!(data, :ranges) # no need to have them in the OpenGL data
    _default((Grid(to_value(main), to_value(ranges)), main), s, data)
end

# surface(::Matrix)
function _default(main::Tuple{G, MatTypes{T}}, s::Style{:surface}, data::Dict) where {G <: Grid{2}, T <: AbstractFloat}
    xrange = main[1].dims[1]; yrange = main[1].dims[2]
    xscale = (maximum(xrange) - minimum(xrange)) / (length(xrange)-1)
    yscale = (maximum(yrange) - minimum(yrange)) / (length(yrange)-1)
    @gen_defaults! data begin
        position    = main[1] =>" Position given as a `Grid{2}`.
        Can be constructed e.g. `Grid(LinRange(0,2,N1), LinRange(0,3, N2))`"
        position_z  = main[2] => (Texture, "height offset for the surface, must be `Matrix{Float}`")
        scale       = Vec3f(xscale, yscale, 1) => "scale of the grid planes forming the surface. Can be made smaller, to let the grid show"
    end
    surface(position_z, s, data)
end

_extrema(x::Rect3f) = Vec2f(minimum(x)[3], maximum(x)[3])
nothing_or_vec(x) = x
nothing_or_vec(x::Array) = vec(x)

function normal_calc(x::Bool, invert_normals::Bool = false)
    i = invert_normals ? "-" : ""
    if x
        "$(i)getnormal(position, position_x, position_y, position_z, o_uv);"
        # "getnormal_fast(position_z, ind2sub(dims, index1D));"
    else
        "vec3(0, 0, $(i)1);"
    end
end

function light_calc(x::Bool)
    if x
        """
        vec3 L      = normalize(o_lightdir);
        vec3 N      = normalize(o_normal);
        vec3 light1 = blinnphong(N, o_camdir, L, color.rgb);
        vec3 light2 = blinnphong(N, o_camdir, -L, color.rgb);
        color       = vec4(ambient * color.rgb + light1 + backlight * light2, color.a);
        """
    else
        ""
    end
end

function native_triangle_mesh(mesh)
    return gl_convert(triangle_mesh(mesh))
end

function surface(main, s::Style{:surface}, data::Dict)

    @gen_defaults! data begin
        primitive = Rect2(0f0,0f0,1f0,1f0) => native_triangle_mesh
        scale = nothing
        position = nothing
        position_x = nothing => Texture
        position_y = nothing => Texture
        position_z = nothing => Texture
        image = nothing => Texture
        shading = true
        normal = shading
        invert_normals = false
        backlight = 0f0
    end
    @gen_defaults! data begin
        color = nothing => Texture
        color_map = nothing => Texture
        color_norm = nothing
        fetch_pixel = false
        matcap = nothing => Texture

        nan_color = RGBAf(1, 0, 0, 1)
        highclip = RGBAf(0, 0, 0, 0)
        lowclip = RGBAf(0, 0, 0, 0)

        uv_scale = Vec2f(1)
        instances = const_lift(x->(size(x,1)-1) * (size(x,2)-1), main) => "number of planes used to render the surface"
        shader = GLVisualizeShader(
            "fragment_output.frag", "util.vert", "surface.vert",
            "standard.frag",
            view = Dict(
                "position_calc" => position_calc(position, position_x, position_y, position_z, Texture),
                "normal_calc" => normal_calc(normal, to_value(invert_normals)),
                "light_calc" => light_calc(shading),
            )
        )
    end
    return data
end

function position_calc(x...)
    _position_calc(Iterators.filter(x->!isa(x, Nothing), x)...)
end

function _position_calc(
        position_x::MatTypes{T}, position_y::MatTypes{T}, position_z::MatTypes{T}, target::Type{Texture}
    ) where T<:AbstractFloat
    """
    int index1D = index + offseti.x + offseti.y * dims.x + (index/(dims.x-1));
    ivec2 index2D = ind2sub(dims, index1D);
    vec2 index01 = vec2(index2D) / (vec2(dims)-1.0);
    pos = vec3(
        texelFetch(position_x, index2D, 0).x,
        texelFetch(position_y, index2D, 0).x,
        texelFetch(position_z, index2D, 0).x
    );
    """
end

function _position_calc(
        position_x::VectorTypes{T}, position_y::VectorTypes{T}, position_z::MatTypes{T},
        target::Type{Texture}
    ) where T<:AbstractFloat
    """
    int index1D = index + offseti.x + offseti.y * dims.x + (index/(dims.x-1));
    ivec2 index2D = ind2sub(dims, index1D);
    vec2 index01 = vec2(index2D) / (vec2(dims)-1.0);
    pos = vec3(
        texelFetch(position_x, index2D.x, 0).x,
        texelFetch(position_y, index2D.y, 0).x,
        texelFetch(position_z, index2D, 0).x
    );
    """
end

function _position_calc(
        position_xyz::VectorTypes{T}, target::Type{TextureBuffer}
    ) where T <: StaticVector
    "pos = texelFetch(position, index).xyz;"
end

function _position_calc(
        position_xyz::VectorTypes{T}, target::Type{GLBuffer}
    ) where T <: StaticVector
    len = length(T)
    filler = join(ntuple(x->0, 3-len), ", ")
    needs_comma = len != 3 ? ", " : ""
    "pos = vec3(position $needs_comma $filler);"
end

function _position_calc(
        grid::Grid{2}, position_z::MatTypes{T}, target::Type{Texture}
    ) where T<:AbstractFloat
    """
    int index1D = index + offseti.x + offseti.y * dims.x + (index/(dims.x-1));
    ivec2 index2D = ind2sub(dims, index1D);
    vec2 index01 = vec2(index2D) / (vec2(dims)-1.0);
    float height = texture(position_z, index01).x;
    pos = vec3(grid_pos(position, index01), height);
    """
end
