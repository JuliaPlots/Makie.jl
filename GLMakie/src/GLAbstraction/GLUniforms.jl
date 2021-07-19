# Uniforms are OpenGL variables that stay the same for the entirety of a drawcall.
# There are a lot of functions, to upload them, as OpenGL doesn't rely on multiple dispatch.
# here is my approach, to handle all of the uniforms with one function, namely gluniform
# For uniforms, the Vector and Matrix types from ImmutableArrays should be used, as they map the relation almost 1:1

const GLSL_COMPATIBLE_NUMBER_TYPES = (GLfloat, GLint, GLuint, GLdouble)
const NATIVE_TYPES = Union{
    StaticArray, GLSL_COMPATIBLE_NUMBER_TYPES...,
    ZeroIndex{GLint}, ZeroIndex{GLuint},
    GLBuffer, GPUArray, Shader, GLProgram, NativeMesh
}

opengl_prefix(T)  = error("Object $T is not a supported uniform element type")
opengl_postfix(T) = error("Object $T is not a supported uniform element type")


opengl_prefix(x::Type{T}) where {T <: Union{FixedPoint, Float32, Float16}} = ""
opengl_prefix(x::Type{T}) where {T <: Float64} = "d"
opengl_prefix(x::Type{Cint}) = "i"
opengl_prefix(x::Type{T}) where {T <: Union{Cuint, UInt8, UInt16}} = "u"

opengl_postfix(x::Type{Float64}) = "dv"
opengl_postfix(x::Type{Float32}) = "fv"
opengl_postfix(x::Type{Cint})    = "iv"
opengl_postfix(x::Type{Cuint})   = "uiv"


function uniformfunc(typ::DataType, dims::Tuple{Int})
    Symbol(string("glUniform", first(dims), opengl_postfix(typ)))
end
function uniformfunc(typ::DataType, dims::Tuple{Int, Int})
    M, N = dims
    Symbol(string("glUniformMatrix", M == N ? "$M" : "$(M)x$(N)", opengl_postfix(typ)))
end

function gluniform(location::Integer, x::FSA) where FSA <: Union{StaticArray, Colorant}
    xref = [x]
    gluniform(location, xref)
end

_size(p) = size(p)
_size(p::Colorant) = (length(p),)
_size(p::Type{T}) where {T <: Colorant} = (length(p),)
_ndims(p) = ndims(p)
_ndims(p::Type{T}) where {T <: Colorant} = 1

@generated function gluniform(location::Integer, x::Vector{FSA}) where FSA <: Union{StaticArray, Colorant}
    func = uniformfunc(eltype(FSA), _size(FSA))
    callexpr = if _ndims(FSA) == 2
        :($func(location, length(x), GL_FALSE, x))
    else
        :($func(location, length(x), x))
    end
    quote
        $callexpr
    end
end


#Some additional uniform functions, not related to Imutable Arrays
gluniform(location::Integer, target::Integer, t::Texture) = gluniform(GLint(location), GLint(target), t)
gluniform(location::Integer, target::Integer, t::GPUVector) = gluniform(GLint(location), GLint(target), t.buffer)
gluniform(location::Integer, target::Integer, t::Node) = gluniform(GLint(location), GLint(target), to_value(t))
gluniform(location::Integer, target::Integer, t::TextureBuffer) = gluniform(GLint(location), GLint(target), t.texture)
function gluniform(location::GLint, target::GLint, t::Texture)
    activeTarget = GL_TEXTURE0 + UInt32(target)
    glActiveTexture(activeTarget)
    glBindTexture(t.texturetype, t.id)
    gluniform(location, target)
end
gluniform(location::Integer, x::Enum) = gluniform(GLint(location), GLint(x))

function gluniform(loc::Integer, x::Node{T}) where T
    gluniform(GLint(loc), to_value(x))
end

gluniform(location::Integer, x::Union{GLubyte, GLushort, GLuint}) = glUniform1ui(GLint(location), x)
gluniform(location::Integer, x::Union{GLbyte, GLshort, GLint, Bool}) = glUniform1i(GLint(location),  x)
gluniform(location::Integer, x::GLfloat) = glUniform1f(GLint(location),  x)
gluniform(location::Integer, x::GLdouble) = glUniform1d(GLint(location),  x)

#Uniform upload functions for julia arrays...
gluniform(location::GLint, x::Vector{Float32}) = glUniform1fv(location,  length(x), x)
gluniform(location::GLint, x::Vector{GLdouble}) = glUniform1dv(location,  length(x), x)
gluniform(location::GLint, x::Vector{GLint}) = glUniform1iv(location,  length(x), x)
gluniform(location::GLint, x::Vector{GLuint}) = glUniform1uiv(location, length(x), x)

glsl_typename(x::T) where {T} = glsl_typename(T)
glsl_typename(t::DataType) = error("Datatype $(t) not supported")
glsl_typename(t::Type{Nothing}) = "Nothing"
glsl_typename(t::Type{GLfloat}) = "float"
glsl_typename(t::Type{GLdouble}) = "double"
glsl_typename(t::Type{GLuint}) = "uint"
glsl_typename(t::Type{GLint}) = "int"
glsl_typename(t::Type{T}) where {T <: Union{StaticVector, Colorant}} = string(opengl_prefix(eltype(T)), "vec", length(T))
glsl_typename(t::Type{TextureBuffer{T}}) where {T} = string(opengl_prefix(eltype(T)), "samplerBuffer")

function glsl_typename(t::Texture{T, D}) where {T, D}
    str = string(opengl_prefix(eltype(T)), "sampler", D, "D")
    t.texturetype == GL_TEXTURE_2D_ARRAY && (str *= "Array")
    str
end

function glsl_typename(t::Type{T}) where T <: SMatrix
    M, N = size(t)
    string(opengl_prefix(eltype(t)), "mat", M==N ? M : string(M, "x", N))
end
toglsltype_string(t::Node) = toglsltype_string(to_value(t))
toglsltype_string(x::T) where {T<:Union{Real, StaticArray, Texture, Colorant, TextureBuffer, Nothing}} = "uniform $(glsl_typename(x))"
#Handle GLSL structs, which need to be addressed via single fields
function toglsltype_string(x::T) where T
    if isa_gl_struct(x)
        string("uniform ", T.name.name)
    else
        error("can't splice $T into an OpenGL shader. Make sure all fields are of a concrete type and isbits(FieldType)-->true")
    end
end
toglsltype_string(t::Union{GLBuffer{T}, GPUVector{T}}) where {T} = string("in ", glsl_typename(T))
# Gets used to access a
function glsl_variable_access(keystring, t::Texture{T, D}) where {T,D}
    fields = SubString("rgba", 1, length(T))
    if t.texturetype == GL_TEXTURE_BUFFER
        return string("texelFetch(", keystring, "index).", fields, ";")
    end
    return string("getindex(", keystring, "index).", fields, ";")
end
function glsl_variable_access(keystring, ::Union{Real, GLBuffer, GPUVector, StaticArray, Colorant})
    string(keystring, ";")
end
function glsl_variable_access(keystring, s::Node)
    glsl_variable_access(keystring, to_value(s))
end
function glsl_variable_access(keystring, t::Any)
    error("no glsl variable calculation available for : ", keystring, " of type ", typeof(t))
end

function uniform_name_type(program::GLuint)
    uniformLength = glGetProgramiv(program, GL_ACTIVE_UNIFORMS)
    Dict{Symbol, GLenum}(ntuple(uniformLength) do i # take size and name
        name, typ = glGetActiveUniform(program, i-1)
    end)
end
function attribute_name_type(program::GLuint)
    uniformLength = glGetProgramiv(program, GL_ACTIVE_ATTRIBUTES)
    Dict{Symbol, GLenum}(ntuple(uniformLength) do i
    	name, typ = glGetActiveAttrib(program, i-1)
    end)
end
function istexturesampler(typ::GLenum)
    return (
        typ == GL_SAMPLER_BUFFER || typ == GL_INT_SAMPLER_BUFFER || typ == GL_UNSIGNED_INT_SAMPLER_BUFFER ||
    	typ == GL_IMAGE_2D ||
        typ == GL_SAMPLER_1D || typ == GL_SAMPLER_2D || typ == GL_SAMPLER_3D ||
        typ == GL_UNSIGNED_INT_SAMPLER_1D || typ == GL_UNSIGNED_INT_SAMPLER_2D || typ == GL_UNSIGNED_INT_SAMPLER_3D ||
        typ == GL_INT_SAMPLER_1D || typ == GL_INT_SAMPLER_2D || typ == GL_INT_SAMPLER_3D ||
        typ == GL_SAMPLER_1D_ARRAY || typ == GL_SAMPLER_2D_ARRAY ||
        typ == GL_UNSIGNED_INT_SAMPLER_1D_ARRAY || typ == GL_UNSIGNED_INT_SAMPLER_2D_ARRAY ||
        typ == GL_INT_SAMPLER_1D_ARRAY || typ == GL_INT_SAMPLER_2D_ARRAY
    )
end


gl_promote(x::Type{T}) where {T <: Integer} = Cint
gl_promote(x::Type{Union{Int16, Int8}}) = x

gl_promote(x::Type{T}) where {T <: Unsigned} = Cuint
gl_promote(x::Type{Union{UInt16, UInt8}}) = x

gl_promote(x::Type{T}) where {T <: AbstractFloat} = Float32
gl_promote(x::Type{Float16}) = x

gl_promote(x::Type{T}) where {T <: Normed} = N0f32
gl_promote(x::Type{N0f16}) = x
gl_promote(x::Type{N0f8}) = x

const Color3{T} = Colorant{T, 3}
const Color4{T} = Colorant{T, 4}

gl_promote(x::Type{Bool})                  = GLboolean
gl_promote(x::Type{T}) where {T <: Gray} = Gray{gl_promote(eltype(T))}
gl_promote(x::Type{T}) where {T <: Color3} = RGB{gl_promote(eltype(T))}
gl_promote(x::Type{T}) where {T <: Color4} = RGBA{gl_promote(eltype(T))}
gl_promote(x::Type{T}) where {T <: BGRA} = BGRA{gl_promote(eltype(T))}
gl_promote(x::Type{T}) where {T <: BGR} = BGR{gl_promote(eltype(T))}


gl_promote(x::Type{T}) where {T <: StaticVector} = similar_type(T, gl_promote(eltype(T)))

gl_promote(x::Type{T}) where {T <: GeometryBasics.Mesh} = NativeMesh{T}

gl_convert(x::AbstractVector{Vec3f}) = x

gl_convert(x::T) where {T <: Number} = gl_promote(T)(x)
gl_convert(x::T) where {T <: Colorant} = gl_promote(T)(x)
gl_convert(x::T) where {T <: AbstractMesh} = gl_convert(x)
gl_convert(x::T) where {T <: GeometryBasics.Mesh} = gl_promote(T)(x)
gl_convert(x::Node{T}) where {T <: GeometryBasics.Mesh} = gl_promote(T)(x)

gl_convert(s::Vector{Matrix{T}}) where {T<:Colorant} = Texture(s)
gl_convert(s::Nothing) = s


isa_gl_struct(x::AbstractArray) = false
isa_gl_struct(x::NATIVE_TYPES) = false
isa_gl_struct(x::Colorant) = false
function isa_gl_struct(x::T) where T
    !isconcretetype(T) && return false
    if T <: Tuple
        return false
    end
    fnames = fieldnames(T)
    !isempty(fnames) && all(name -> isconcretetype(fieldtype(T, name)) && isbits(getfield(x, name)), fnames)
end
function gl_convert_struct(x::T, uniform_name::Symbol) where T
    if isa_gl_struct(x)
        return Dict{Symbol, Any}(map(fieldnames(x)) do name
            (Symbol("$uniform_name.$name") => gl_convert(getfield(x, name)))
        end)
    else
        error("can't convert $x to a OpenGL type. Make sure all fields are of a concrete type and isbits(FieldType)-->true")
    end
end


# native types don't need convert!
gl_convert(a::T) where {T <: NATIVE_TYPES} = a
gl_convert(s::Node{T}) where {T <: NATIVE_TYPES} = s
gl_convert(s::Node{T}) where T = const_lift(gl_convert, s)
gl_convert(x::StaticVector{N, T}) where {N, T} = map(gl_promote(T), x)
gl_convert(x::SMatrix{N, M, T}) where {N, M, T} = map(gl_promote(T), x)
gl_convert(a::AbstractVector{<: AbstractFace}) = indexbuffer(s)
gl_convert(t::Type{T}, a::T; kw_args...) where T <: NATIVE_TYPES = a
gl_convert(::Type{<: GPUArray}, a::StaticVector) = gl_convert(a)

function gl_convert(T::Type{<: GPUArray}, a::AbstractArray{X, N}; kw_args...) where {X, N}
    T(convert(AbstractArray{gl_promote(X), N}, a); kw_args...)
end

gl_convert(::Type{<: GLBuffer}, x::GLBuffer; kw_args...) = x
gl_convert(::Type{Texture}, x::Texture) = x
gl_convert(::Type{<: GPUArray}, x::GPUArray) = x

function gl_convert(::Type{T}, a::Vector{Array{X, 2}}; kw_args...) where {T <: Texture, X}
    T(a; kw_args...)
end
gl_convert(::Type{<: GPUArray}, a::Node{<: StaticVector}) = gl_convert(a)

function gl_convert(::Type{T}, a::Node{<: AbstractArray{X, N}}; kw_args...) where {T <: GPUArray, X, N}
    TGL = gl_promote(X)
    s = (X == TGL) ? a : lift(x-> convert(Array{TGL, N}, x), a)
    T(s; kw_args...)
end

lift_convert(a::AbstractArray, T, N) = lift(x -> convert(Array{T, N}, x), a)
function lift_convert(a::ShaderAbstractions.Sampler, T, N)
    ShaderAbstractions.Sampler(
        lift(x -> convert(Array{T, N}, x.data), a),
        minfilter = a[].minfilter, magfilter = a[].magfilter,
        x_repeat = a[].repeat[1],
        y_repeat = a[].repeat[min(2, N)],
        z_repeat = a[].repeat[min(3, N)],
        anisotropic = a[].anisotropic, swizzle_mask = a[].swizzle_mask
    )
end

gl_convert(f::Function, a) = f(a)
