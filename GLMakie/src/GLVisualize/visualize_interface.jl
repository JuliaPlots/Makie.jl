@enum Shape CIRCLE RECTANGLE ROUNDED_RECTANGLE DISTANCEFIELD TRIANGLE
@enum CubeSides TOP BOTTOM FRONT BACK RIGHT LEFT

struct Grid{N,T <: AbstractRange}
    dims::NTuple{N,T}
end
Base.ndims(::Grid{N,T}) where {N,T} = N

Grid(ranges::AbstractRange...) = Grid(ranges)
function Grid(a::Array{T,N}) where {N,T}
    s = Vec{N,Float32}(size(a))
    smax = maximum(s)
    s = s ./ smax
    Grid(ntuple(Val{N}) do i
        range(0, stop=s[i], length=size(a, i))
    end)
end

Grid(a::AbstractArray, ranges...) = Grid(a, ranges)

"""
This constructor constructs a grid from ranges given as a tuple.
Due to the approach, the tuple `ranges` can consist of NTuple(2, T)
and all kind of range types. The constructor will make sure that all ranges match
the size of the dimension of the array `a`.
"""
function Grid(a::AbstractArray{T,N}, ranges::Tuple) where {T,N}
    length(ranges) = ! N && throw(ArgumentError(
        "You need to supply a range for every dimension of the array. Given: $ranges
        given Array: $(typeof(a))"
    ))
    Grid(ntuple(Val(N)) do i
        range(first(ranges[i]), stop=last(ranges[i]), length=size(a, i))
    end)
end

Base.length(p::Grid) = prod(size(p))
Base.size(p::Grid) = map(length, p.dims)
function Base.getindex(p::Grid{N,T}, i) where {N,T}
    inds = ind2sub(size(p), i)
    return Point{N,eltype(T)}(ntuple(Val(N)) do i
        p.dims[i][inds[i]]
    end)
end

Base.iterate(g::Grid, i=1) = i <= length(g) ? (g[i], i + 1) : nothing

GLAbstraction.isa_gl_struct(x::Grid) = true
GLAbstraction.toglsltype_string(t::Grid{N,T}) where {N,T} = "uniform Grid$(N)D"
function GLAbstraction.gl_convert_struct(g::Grid{N,T}, uniform_name::Symbol) where {N,T}
    return Dict{Symbol,Any}(
        Symbol("$uniform_name.start") => Vec{N,Float32}(minimum.(g.dims)),
        Symbol("$uniform_name.stop") => Vec{N,Float32}(maximum.(g.dims)),
        Symbol("$uniform_name.lendiv") => Vec{N,Cint}(length.(g.dims) .- 1),
        Symbol("$uniform_name.dims") => Vec{N,Cint}(map(length, g.dims))
    )
end
function GLAbstraction.gl_convert_struct(g::Grid{1,T}, uniform_name::Symbol) where T
    x = g.dims[1]
    return Dict{Symbol,Any}(
        Symbol("$uniform_name.start") => Float32(minimum(x)),
        Symbol("$uniform_name.stop") => Float32(maximum(x)),
        Symbol("$uniform_name.lendiv") => Cint(length(x) - 1),
        Symbol("$uniform_name.dims") => Cint(length(x))
    )
end

struct GLVisualizeShader <: AbstractLazyShader
    paths::Tuple
    kw_args::Dict{Symbol,Any}
    function GLVisualizeShader(paths::String...; view=Dict{String,String}(), kw_args...)
        # TODO properly check what extensions are available
        @static if !Sys.isapple()
            view["GLSL_EXTENSIONS"] = "#extension GL_ARB_conservative_depth: enable"
            view["SUPPORTED_EXTENSIONS"] = "#define DETPH_LAYOUT"
        end
        view["buffers"] = get_buffers()
        view["buffer_writes"] = get_buffer_writes()
        args = Dict{Symbol, Any}(kw_args)
        args[:view] = view
        args[:fragdatalocation] = [(0, "fragment_color"), (1, "fragment_groupid")]
        new(map(x -> loadshader(x), paths), args)
    end
end

function assemble_robj(data, program, bb, primitive, pre_fun, post_fun)
    transp = get(data, :transparency, Node(false))
    overdraw = get(data, :overdraw, Node(false))
    pre = if pre_fun != nothing
        _pre_fun = GLAbstraction.StandardPrerender(transp, overdraw)
        function ()
            _pre_fun()
            pre_fun()
        end
    else
        GLAbstraction.StandardPrerender(transp, overdraw)
    end
    robj = RenderObject(data, program, pre, nothing, bb, nothing)
    post = if haskey(data, :instances)
        GLAbstraction.StandardPostrenderInstanced(data[:instances], robj.vertexarray, primitive)
    else
        GLAbstraction.StandardPostrender(robj.vertexarray, primitive)
    end
    robj.postrenderfunction = if post_fun !== nothing
        () -> begin
            post()
            post_fun()
        end
    else
        post
    end
    robj
end

function assemble_shader(data)
    shader = data[:shader]
    delete!(data, :shader)
    glp = get(data, :gl_primitive, GL_TRIANGLES)
    return assemble_robj(
        data, shader, Rect3f(), glp,
        get(data, :prerender, nothing),
        get(data, :postrender, nothing)
    )
end

"""
Converts index arrays to the OpenGL equivalent.
"""
to_index_buffer(x::GLBuffer) = x
to_index_buffer(x::TOrSignal{Int}) = x
to_index_buffer(x::VecOrSignal{UnitRange{Int}}) = x
to_index_buffer(x::TOrSignal{UnitRange{Int}}) = x
"""
For integers, we transform it to 0 based indices
"""
to_index_buffer(x::AbstractVector{I}) where {I <: Integer} = indexbuffer(Cuint.(x .- 1))
function to_index_buffer(x::Node{<: AbstractVector{I}}) where I <: Integer
    indexbuffer(lift(x -> Cuint.(x .- 1), x))
end

"""
If already GLuint, we assume its 0 based (bad heuristic, should better be solved with some Index type)
"""
function to_index_buffer(x::VectorTypes{I}) where I <: Union{GLuint,LineFace{GLIndex}}
    indexbuffer(x)
end

to_index_buffer(x) = error(
    "Not a valid index type: $(typeof(x)).
    Please choose from Int, Vector{UnitRange{Int}}, Vector{Int} or a signal of either of them"
)

"""
Creates a default visualization for any value.
The defaults can be customized via the key word arguments and the style parameter.
The style can change the the look completely (e.g points displayed as lines, or particles),
while the key word arguments just alter the parameters of one visualization.
Always returns a context, which can be displayed on a window via view(::Context, [display]).
"""
visualize(@nospecialize(main), s::Symbol=:default; kw_args...) = visualize(main, Style{s}(), Dict{Symbol,Any}(kw_args))


function visualize(@nospecialize(main), @nospecialize(s), @nospecialize(data))
    data = _default(main, s, copy(data))
    @gen_defaults! data begin # make sure every object has these!
        model = Mat4f(I)
    end
    return assemble_shader(data)
end

# Make changes to fragment_output to match what's needed for postprocessing
using ..GLMakie: enable_SSAO
function get_buffers()
    if enable_SSAO[]
        """
        layout(location=2) out vec4 fragment_position;
        layout(location=3) out vec3 fragment_normal_occlusion;
        """
    else
        ""
    end
end

function get_buffer_writes()
    if enable_SSAO[]
        """
        fragment_position = o_view_pos;
        fragment_normal_occlusion.xyz = o_normal;
        """
    else
        ""
    end
end
