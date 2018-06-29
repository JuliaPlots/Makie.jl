macro gputime(codeblock)
    quote
        local const query        = GLuint[1]
        local const elapsed_time = GLuint64[1]
        local const done         = GLint[0]
        glGenQueries(1, query)
        glBeginQuery(GL_TIME_ELAPSED, query[1])
        $(esc(codeblock))
        glEndQuery(GL_TIME_ELAPSED)

        while (done[1] != 1)
            glGetQueryObjectiv(
                query[1],
                GL_QUERY_RESULT_AVAILABLE,
                done
            )
        end
        glGetQueryObjectui64v(query[1], GL_QUERY_RESULT, elapsed_time)
        println("Time Elapsed: ", elapsed_time[1] / 1000000.0, "ms")
    end
end

struct IterOrScalar{T}
    val::T
end

minlenght(a::Tuple{Vararg{IterOrScalar}}) = foldl(typemax(Int), a) do len, elem
    isa(elem.val, AbstractArray) && len > length(elem.val) && return length(elem.val)
    len
end
getindex(A::IterOrScalar{T}, i::Integer) where {T<:AbstractArray} = A.val[i]
getindex(A::IterOrScalar, i::Integer) = A.val

#Some mapping functions for dictionaries
function mapvalues(func, collection::Dict)
    Dict([(key, func(value)) for (key, value) in collection])
end
function mapkeys(func, collection::Dict)
    Dict([(func(key), value) for (key, value) in collection])
end

function print_with_lines(out::IO, text::AbstractString)
    io = IOBuffer()
    for (i,line) in enumerate(split(text, "\n"))
        println(io, @sprintf("%-4d: %s", i, line))
    end
    write(out, take!(io))
end
print_with_lines(text::AbstractString) = print_with_lines(STDOUT, text)


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
matches_target(::Type{Target}, x::Signal{T}) where {Target, T} = applicable(gl_convert, Target, x)  || T <: Target
matches_target(::Function, x) = true
matches_target(::Function, x::Void) = false
export matches_target


signal_convert(T, y) = convert(T, y)
signal_convert(T1, y::T2) where {T2<:Signal} = map(convert, Signal(T1), y)
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
        if Base.is_linenumber(elem)
            push!(return_expression.args, elem)
            continue
        end
        opengl_convert_target = :() # is optional, so first is an empty expression
        convert_target        = :() # is optional, so first is an empty expression
        doc_strings           = :()
        if elem.head == :(=)
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
                            if matches_target($elem, $key_name)
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
        else
            error("all nodes need to be of form a = b OR a::Type = b OR a = b => Type, where a needs to be a var and b any expression. Found: $elem")
        end
    end
    #push!(return_expression.args, :($dictsym[:gl_convert_targets] = gl_convert_targets)) #just pass the targets via the dict
    push!(return_expression.args, :($dictsym)) #return dict
    esc(return_expression)
end
export @gen_defaults!

makesignal(s::Signal) = s
makesignal(v) = Signal(v)

@inline const_lift(f::Union{DataType, Type, Function}, inputs...) = map(f, map(makesignal, inputs)...)
export const_lift

function close_to_square(n::Real)
    # a cannot be greater than the square root of n
    # b cannot be smaller than the square root of n
    # we get the maximum allowed value of a
    amax = floor(Int, sqrt(n));
    if 0 == rem(n, amax)
        # special case where n is a square number
        return (amax, div(n, amax))
    end
    # Get its prime factors of n
    primeFactors  = factor(n);
    # Start with a factor 1 in the list of candidates for a
    candidates = Int[1]
    for (f, _) in primeFactors
        # Add new candidates which are obtained by multiplying
        # existing candidates with the new prime factor f
        # Set union ensures that duplicate candidates are removed
        candidates  = union(candidates, f .* candidates);
        # throw out candidates which are larger than amax
        filter!(x-> x <= amax, candidates)
    end
    # Take the largest factor in the list d
    (candidates[end], div(n, candidates[end]))
end



isnotempty(x) = !isempty(x)
AND(a,b) = a&&b
OR(a,b) = a||b

#Meshtype holding native OpenGL data.
struct NativeMesh{MeshType <: HomogenousMesh}
    data::Dict{Symbol, Any}
end
export NativeMesh

NativeMesh(m::T) where {T <: HomogenousMesh} = NativeMesh{T}(m)


function (MT::Type{NativeMesh{T}})(m::T) where T <: HomogenousMesh
    result = Dict{Symbol, Any}()
    attribs = attributes(m)
    @materialize! vertices, faces = attribs
    result[:vertices] = Buffer(vertices)
    result[:faces]    = indexbuffer(faces)
    for (field, val) in attribs
        if field in (:texturecoordinates, :normals, :attribute_id, :color)
            if field == :color
                field = :vertex_color
            end
            if isa(val, Vector)
                result[field] = Buffer(val)
            end
        else
            result[field] = Texture(val)
        end
    end
    MT(result)
end

function (MT::Type{NativeMesh{T}})(m::Signal{T}) where T <: HomogenousMesh
    result = Dict{Symbol, Any}()
    mv = Reactive.value(m)
    attribs = attributes(mv)
    @materialize! vertices, faces = attribs
    result[:vertices] = Buffer(vertices)
    result[:faces]    = indexbuffer(faces)
    for (field, val) in attribs
        if field in (:texturecoordinates, :normals, :attribute_id, :color)
            if field == :color
                field = :vertex_color
            end
            if isa(val, Vector)
                result[field] = Buffer(val)
            end
        else
            result[field] = Texture(val)
        end
    end
    foreach(m) do mesh
        for (field, val) in attributes(mesh)
            if field == :color
                field = :vertex_color
            end
            if haskey(result, field)
                update!(result[field], val)
            end
        end
    end
    MT(result)
end

## added utils from refactor...
function glasserteltype(::Type{T}) where T
    try
        length(T)
    catch
        error("Error only types with well defined lengths are allowed")
    end
end



#TODO vertexarraycleanup: transform the instanced data into the correct one.
function gl_convert_data!(data)
    # position I think are the vertices

    # gl_convert_targets are what everythign should be converted to!
    targets = get(data, :gl_convert_targets, Dict())
    delete!(data, :gl_convert_targets)
    passthrough = Dict{Symbol, Any}() # we also save a few non opengl related values in data
    for (k,v) in data # convert everything to OpenGL compatible types
        if haskey(targets, k)
            # glconvert is designed to just convert everything to a fitting opengl datatype, but sometimes exceptions are needed
            # e.g. Texture{T,1} and Buffer{T} are both usable as an native conversion canditate for a Julia's Array{T, 1} type.
            # but in some cases we want a Texture, sometimes a Buffer or TextureBuffer
            data[k] = gl_convert(targets[k], v)
        else
            k in (:indices, :visible) && continue
            if isa_gl_struct(v) # structs are treated differently, since they have to be composed into their fields
                merge!(data, gl_convert_struct(v, k))
            elseif applicable(gl_convert, v) # if can't be converted to an OpenGL datatype,
                data[k] = gl_convert(v)
            else # put it in passthrough
                delete!(data, k)
                passthrough[k] = v
            end
        end
    end
    # handle meshes seperately, since they need expansion
    meshs = filter((key, value) -> isa(value, NativeMesh), data)
    if !isempty(meshs)
        merge!(data, [v.data for (k,v) in meshs]...)
    end
    for (k, v) in data
        if isa(v, Reactive.Signal) #NO REACTIVE ERROR
        # if isa(v, Reactive.Signal) && (typeof(value(v))<: Vector || k ==:indices)         #REACTIVE ERROR
            data[k] = Reactive.value(v)
        end
    end
    #TODO renderobjectioncleanup: ugly crap here!

    passthrough[:shader] = gl_convert(Reactive.value(passthrough[:shader]), data)
    #TODO shadercleanup. This needs to not be inside the robj, and also not done here very hacky!!!!!!
    merge!(data, passthrough) # in the end, we insert back the non opengl data, to keep things simple lelkek
end
