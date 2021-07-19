function print_with_lines(out::IO, text::AbstractString)
    io = IOBuffer()
    for (i,line) in enumerate(split(text, "\n"))
        println(io, @sprintf("%-4d: %s", i, line))
    end
    write(out, take!(io))
end
print_with_lines(text::AbstractString) = print_with_lines(stdout, text)

"""
Style Type, which is used to choose different visualization/editing styles via multiple dispatch
Usage pattern:
visualize(::Style{:Default}, ...)           = do something
visualize(::Style{:MyAwesomeNewStyle}, ...) = do something different
"""
struct Style{StyleValue}
end
Style(x::Symbol) = Style{x}()
Style() = Style{:Default}()
mergedefault!(style::Style{S}, styles, customdata) where {S} = merge!(copy(styles[S]), Dict{Symbol, Any}(customdata))
macro style_str(string)
    Style{Symbol(string)}
end
export @style_str

"""
splats keys from a dict into variables
"""
macro materialize(dict_splat)
    keynames, dict = dict_splat.args
    keynames = isa(keynames, Symbol) ? [keynames] : keynames.args
    dict_instance = gensym()
    kd = [:($key = $dict_instance[$(Expr(:quote, key))]) for key in keynames]
    kdblock = Expr(:block, kd...)
    expr = quote
        $dict_instance = $dict # handle if dict is not a variable but an expression
        $kdblock
    end
    esc(expr)
end

"""
splats keys from a dict into variables and removes them
"""
macro materialize!(dict_splat)
    keynames, dict = dict_splat.args
    keynames = isa(keynames, Symbol) ? [keynames] : keynames.args
    dict_instance = gensym()
    kd = [:($key = pop!($dict_instance, $(Expr(:quote, key)))) for key in keynames]
    kdblock = Expr(:block, kd...)
    expr = quote
        $dict_instance = $dict # handle if dict is not a variable but an expression
        $kdblock
    end
    esc(expr)
end

"""
Needed to match the lazy gl_convert exceptions.
    `Target`: targeted OpenGL type
    `x`: the variable that gets matched
"""
matches_target(::Type{Target}, x::T) where {Target, T} = applicable(gl_convert, Target, x) || T <: Target  # it can be either converted to Target, or it's already the target
matches_target(::Type{Target}, x::Node{T}) where {Target, T} = applicable(gl_convert, Target, x)  || T <: Target
matches_target(::Function, x) = true
matches_target(::Function, x::Nothing) = false

signal_convert(T1, y::T2) where {T2<:Node} = lift(convert, Node(T1), y)


"""
Takes a dict and inserts defaults, if not already available.
The variables are made accessible in local scope, so things like this are possible:
gen_defaults! dict begin
    a = 55
    b = a * 2 # variables, like a, will get made visible in local scope
    c::JuliaType = X # `c` needs to be of type JuliaType. `c` will be made available with it's original type and then converted to JuliaType when inserted into `dict`
    d = x => GLType # OpenGL convert target. Get's only applied if `x` is convertible to GLType. Will only be converted when passed to RenderObject
    d = x => \"doc string\"
    d = x => (GLType, \"doc string and gl target\")
end
"""
macro gen_defaults!(dict, args)
    args.head == :block || error("second argument needs to be a block of form
    begin
        a = 55
        b = a * 2 # variables, like a, will get made visible in local scope
        c::JuliaType = X # c needs to be of type JuliaType. c will be made available with it's original type and then converted to JuliaType when inserted into data
        d = x => GLType # OpenGL convert target. Get's only applied if x is convertible to GLType. Will only be converted when passed to RenderObject
    end")
    tuple_list = args.args
    dictsym = gensym()
    return_expression = Expr(:block)
    push!(return_expression.args, :($dictsym = $dict)) # dict could also be an expression, so we need to asign it to a variable at the beginning
    push!(return_expression.args, :(gl_convert_targets = get!($dictsym, :gl_convert_targets, Dict{Symbol, Any}()))) # exceptions for glconvert.
    push!(return_expression.args, :(doc_strings = get!($dictsym, :doc_string, Dict{Symbol, Any}()))) # exceptions for glconvert.
    # @gen_defaults can be used multiple times, so we need to reuse gl_convert_targets if already in here
    for (i, elem) in enumerate(tuple_list)
        opengl_convert_target = :() # is optional, so first is an empty expression
        convert_target        = :() # is optional, so first is an empty expression
        doc_strings           = :()
        if Meta.isexpr(elem, :(=))
            key_name, value_expr = elem.args
            if isa(key_name, Expr) && key_name.head == :(::) # we need to convert to a julia type
                key_name, convert_target = key_name.args
                convert_target = :(GLAbstraction.signal_convert($convert_target, $key_name))
            else
                convert_target = :($key_name)
            end
            key_sym = Expr(:quote, key_name)
            if isa(value_expr, Expr) && value_expr.head == :call && value_expr.args[1] == :(=>)  # we might need to insert a convert target
                value_expr, target = value_expr.args[2:end]
                undecided = []
                if isa(target, Expr)
                    undecided = target.args
                else
                    push!(undecided, target)
                end
                for elem in undecided
                    isa(elem, Expr) && continue #
                    if isa(elem, AbstractString) # only docstring
                        doc_strings = :(doc_strings[$key_sym] = $elem)
                    elseif isa(elem, Symbol)
                        opengl_convert_target = quote
                            if GLAbstraction.matches_target($elem, $key_name)
                                gl_convert_targets[$key_sym] = $elem
                            end
                        end
                    end
                end
            end
            expr = quote
                $key_name = if haskey($dictsym, $key_sym)
                    $dictsym[$key_sym]
                else
                    $value_expr # in case that evaluating value_expr is expensive, we use a branch instead of get(dict, key, default)
                end
                $dictsym[$key_sym] = $convert_target
                $opengl_convert_target
                $doc_strings
            end
            push!(return_expression.args, expr)
        end
    end
    #push!(return_expression.args, :($dictsym[:gl_convert_targets] = gl_convert_targets)) #just pass the targets via the dict
    push!(return_expression.args, :($dictsym)) #return dict
    esc(return_expression)
end
export @gen_defaults!

makesignal(s::Node) = s
makesignal(v) = Node(v)

@inline const_lift(f::Union{DataType, Type, Function}, inputs...) = lift(f, map(makesignal, inputs)...)
export const_lift

isnotempty(x) = !isempty(x)
AND(a,b) = a&&b
OR(a,b) = a||b

#Meshtype holding native OpenGL data.
struct NativeMesh{MeshType <: GeometryBasics.Mesh}
    data::Dict{Symbol, Any}
end

export NativeMesh

NativeMesh(m::T) where {T <: GeometryBasics.Mesh} = NativeMesh{T}(m)
NativeMesh(m::Observable{T}) where {T <: GeometryBasics.Mesh} = NativeMesh{T}(m)

convert_texcoordinates(uv::AbstractVector{Vec2f}) = uv
convert_texcoordinates(x::AbstractVector{<:Number}) = convert(Vector{Float32}, x)

function NativeMesh{T}(mesh::T) where T <: GeometryBasics.Mesh
    result = Dict{Symbol, Any}()
    attribs = GeometryBasics.attributes(mesh)
    result[:faces] = indexbuffer(faces(mesh))
    if isempty(attribs)
        # TODO position only shows up as attribute
        # when it has meta informtion
        result[:vertices] = GLBuffer(collect(metafree(coordinates(mesh))))
    end
    for (field, val) in attribs
        if val isa Makie.Sampler
            result[:image] = Texture(val.colors)
            result[:texturecoordinates] = GLBuffer(convert_texcoordinates(val.values))
            if val.scaling.range !== nothing
                result[:color_norm] = Observable(Vec2f(val.scaling.range))
            end
        elseif field in (:position, :uv, :uvw, :normals, :attribute_id, :color)
            if field == :color
                field = :vertex_color
            elseif field in (:uv, :uvw)
                field = :texturecoordinates
            elseif field == :position
                field = :vertices
            end
            if val isa AbstractVector
                result[field] = GLBuffer(metafree(val))
            end
        else
            result[field] = Texture(val)
        end
    end
    return NativeMesh{T}(result)
end


function NativeMesh{T}(m::Node{T}) where T <: GeometryBasics.Mesh
    result = NativeMesh{T}(m[])
    on(m) do mesh

        attribs = GeometryBasics.attributes(mesh)

        update!(result.data[:faces], faces(mesh))

        if isempty(attribs)
            # TODO position only shows up as attribute
            # when it has meta informtion
            update!(result.data[:vertices], metafree(coordinates(mesh)))
        end

        for (field, val) in attribs
            if val isa Makie.Sampler
                update!(result.data[:image], val.colors)
                update!(result.data[:texturecoordinates], convert_texcoordinates(val.values))
                if val.scaling.range !== nothing
                    result.data[:color_norm][] = Vec2f(val.scaling.range)
                end
            else
                field == :color && (field = :vertex_color)
                field == :uv && (field = :texturecoordinates)
                field == :position && (field = :vertices)
                haskey(result.data, field) && update!(result.data[field], val)
            end
        end
    end
    return result
end
