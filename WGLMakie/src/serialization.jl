using Colors
using ShaderAbstractions: InstancedProgram, Program
using Makie: Key, plotkey
using Colors: N0f8

Makie.plotkey(::Nothing) = :scatter

function lift_convert(key, value, plot)
    val = lift(value) do value
        return wgl_convert(value, Key{key}(), Key{plotkey(plot)}())
    end
    if key == :colormap && val[] isa AbstractArray
        return ShaderAbstractions.Sampler(val)
    else
        return val
    end
end

function Base.pairs(mesh::GeometryBasics.Mesh)
    return (kv for kv in GeometryBasics.attributes(mesh))
end

function GeometryBasics.faces(x::VertexArray)
    return GeometryBasics.faces(getfield(x, :data))
end

tlength(T) = length(T)
tlength(::Type{<:Real}) = 1

serialize_three(val::Number) = val
serialize_three(val::Vec2f) = convert(Vector{Float32}, val)
serialize_three(val::Vec3f) = convert(Vector{Float32}, val)
serialize_three(val::Vec4f) = convert(Vector{Float32}, val)
serialize_three(val::Quaternion) = convert(Vector{Float32}, collect(val.data))
serialize_three(val::RGB) = Float32[red(val), green(val), blue(val)]
serialize_three(val::RGBA) = Float32[red(val), green(val), blue(val), alpha(val)]
serialize_three(val::Mat4f) = vec(val)
serialize_three(val::Mat3) = vec(val)

function serialize_three(observable::Observable)
    return Dict(:type => "Observable", :id => observable.id,
                :value => serialize_three(observable[]))
end

function serialize_three(array::AbstractArray)
    return serialize_three(flatten_buffer(array))
end

function serialize_three(array::Buffer)
    return serialize_three(flatten_buffer(array))
end

function serialize_three(array::AbstractArray{UInt8})
    return Dict(:type => "Uint8Array", :data => array)
end

function serialize_three(array::AbstractArray{Int32})
    return Dict(:type => "Int32Array", :data => array)
end

function serialize_three(array::AbstractArray{UInt32})
    return Dict(:type => "Uint32Array", :data => array)
end

function serialize_three(array::AbstractArray{Float32})
    return Dict(:type => "Float32Array", :data => array)
end

function serialize_three(array::AbstractArray{Float16})
    return Dict(:type => "Float32Array", :data => array)
end

function serialize_three(array::AbstractArray{Float64})
    return Dict(:type => "Float64Array", :data => array)
end

function serialize_three(color::Sampler{T,N}) where {T,N}
    tex = Dict(:type => "Sampler", :data => serialize_three(color.data),
               :size => [size(color.data)...], :three_format => three_format(T),
               :three_type => three_type(eltype(T)),
               :minFilter => three_filter(color.minfilter),
               :magFilter => three_filter(color.magfilter),
               :wrapS => three_repeat(color.repeat[1]), :anisotropy => color.anisotropic)
    if N > 1
        tex[:wrapT] = three_repeat(color.repeat[2])
    end
    if N > 2
        tex[:wrapR] = three_repeat(color.repeat[3])
    end
    return tex
end

function serialize_uniforms(dict::Dict)
    result = Dict{Symbol,Any}()
    for (k, v) in dict
        result[k] = serialize_three(to_value(v))
    end
    return result
end

three_format(::Type{<:Real}) = "RedFormat"
three_format(::Type{<:RGB}) = "RGBFormat"
three_format(::Type{<:RGBA}) = "RGBAFormat"

three_type(::Type{Float16}) = "FloatType"
three_type(::Type{Float32}) = "FloatType"
three_type(::Type{N0f8}) = "UnsignedByteType"

function three_filter(sym)
    sym == :linear && return "LinearFilter"
    return sym == :nearest && return "NearestFilter"
end

function three_repeat(s::Symbol)
    s == :clamp_to_edge && return "ClampToEdgeWrapping"
    s == :mirrored_repeat && return "MirroredRepeatWrapping"
    return s == :repeat && return "RepeatWrapping"
end

"""
    flatten_buffer(array::AbstractArray)
Flattens `array` array to be a 1D Vector of Float32 / UInt8.
If presented with AbstractArray{<: Colorant/Tuple/SVector}, it will flatten those
to their element type.
"""
function flatten_buffer(array::AbstractArray{<: Number})
    return array
end

function flatten_buffer(array::Buffer)
    return flatten_buffer(getfield(array, :data))
end

function flatten_buffer(array::AbstractArray{T}) where {T<:N0f8}
    return reinterpret(UInt8, array)
end

function flatten_buffer(array::AbstractArray{T}) where {T}
    return flatten_buffer(reinterpret(eltype(T), array))
end

lasset(paths...) = read(joinpath(@__DIR__, "..", "assets", paths...), String)

isscalar(x::StaticArrays.StaticArray) = true
isscalar(x::AbstractArray) = false
isscalar(x::Billboard) = isscalar(x.rotation)
isscalar(x::Observable) = isscalar(x[])
isscalar(x) = true

function ShaderAbstractions.type_string(::ShaderAbstractions.AbstractContext,
                                        ::Type{<:Makie.Quaternion})
    return "vec4"
end

function ShaderAbstractions.convert_uniform(::ShaderAbstractions.AbstractContext,
                                            t::Quaternion)
    return convert(Quaternion, t)
end

function wgl_convert(value, key1, key2)
    val = Makie.convert_attribute(value, key1, key2)
    return if val isa AbstractArray{<:Float64}
        return Makie.el32convert(val)
    else
        return val
    end
end

function wgl_convert(value::AbstractMatrix, ::key"colormap", key2)
    return ShaderAbstractions.Sampler(value)
end

function serialize_buffer_attribute(buffer::AbstractVector{T}) where {T}
    return Dict(:flat => serialize_three(buffer), :type_length => tlength(T))
end

function serialize_named_buffer(buffer)
    return Dict(map(pairs(buffer)) do (name, buff)
                    return name => serialize_buffer_attribute(buff)
                end)
end

function register_geometry_updates(update_buffer::Observable, named_buffers)
    for (name, buffer) in pairs(named_buffers)
        if buffer isa Buffer
            on(ShaderAbstractions.updater(buffer).update) do (f, args)
                # update to replace the whole buffer!
                if f === (setindex!) && args[1] isa AbstractArray && args[2] isa Colon
                    new_array = args[1]
                    flat = flatten_buffer(new_array)
                    update_buffer[] = [name, serialize_three(flat), length(new_array)]
                end
                return
            end
        end
    end
    return update_buffer
end

function register_geometry_updates(update_buffer::Observable, program::Program)
    return register_geometry_updates(update_buffer, program.vertexarray)
end

function register_geometry_updates(update_buffer::Observable, program::InstancedProgram)
    return register_geometry_updates(update_buffer, program.per_instance)
end

function uniform_updater(uniforms::Dict)
    updater = Observable(Any[:none, []])
    for (name, value) in uniforms
        if value isa Sampler
            on(ShaderAbstractions.updater(value).update) do (f, args)
                if args[2] isa Colon && f == setindex!
                    updater[] = [name, serialize_three(args[1])]
                end
                return
            end
        else
            value isa Observable || continue
            on(value) do value
                updater[] = [name, serialize_three(value)]
                return
            end
        end
    end
    return updater
end

function serialize_three(ip::InstancedProgram)
    program = serialize_three(ip.program)
    program[:instance_attributes] = serialize_named_buffer(ip.per_instance)
    register_geometry_updates(program[:attribute_updater], ip)
    return program
end

function serialize_three(program::Program)
    indices = GeometryBasics.faces(program.vertexarray)
    indices = reinterpret(UInt32, indices)
    uniforms = serialize_uniforms(program.uniforms)
    attribute_updater = Observable(["", [], 0])
    register_geometry_updates(attribute_updater, program)
    return Dict(:vertexarrays => serialize_named_buffer(program.vertexarray),
                :faces => indices, :uniforms => uniforms,
                :vertex_source => program.vertex_source,
                :fragment_source => program.fragment_source,
                :uniform_updater => uniform_updater(program.uniforms),
                :attribute_updater => attribute_updater)
end

function serialize_scene(scene::Scene, serialized_scenes=[])
    hexcolor(c) = "#" * hex(Colors.color(to_color(c)))
    pixel_area = lift(area -> [minimum(area)..., widths(area)...], pixelarea(scene))
    cam_controls = cameracontrols(scene)
    cam3d_state = if cam_controls isa Camera3D
        fields = (:lookat, :upvector, :eyeposition, :fov, :near, :far)
        Dict((f => serialize_three(getfield(cam_controls, f)[]) for f in fields))
    else
        nothing
    end
    serialized = Dict(:pixelarea => pixel_area,
                      :backgroundcolor => lift(hexcolor, scene.backgroundcolor),
                      :clearscene => scene.clear,
                      :camera => serialize_camera(scene),
                      :plots => serialize_plots(scene, scene.plots),
                      :cam3d_state => cam3d_state,
                      :visible => scene.visible,
                      :uuid => js_uuid(scene))

    push!(serialized_scenes, serialized)
    foreach(child -> serialize_scene(child, serialized_scenes), scene.children)

    return serialized_scenes
end

function serialize_plots(scene::Scene, plots::Vector{T}, result=[]) where {T<:AbstractPlot}
    for plot in plots
        # if no plots inserted, this truely is an atomic
        if isempty(plot.plots)
            plot_data = serialize_three(scene, plot)
            plot_data[:uuid] = js_uuid(plot)
            push!(result, plot_data)
        else
            serialize_plots(scene, plot.plots, result)
        end
    end
    return result
end

function serialize_three(scene::Scene, plot::AbstractPlot)
    program = create_shader(scene, plot)
    mesh = serialize_three(program)
    mesh[:name] = string(Makie.plotkey(plot)) * "-" * string(objectid(plot))
    mesh[:visible] = plot.visible
    mesh[:uuid] = js_uuid(plot)
    mesh[:transparency] = plot.transparency
    mesh[:overdraw] = plot.overdraw
    uniforms = mesh[:uniforms]
    updater = mesh[:uniform_updater]

    delete!(uniforms, :lightposition)

    if haskey(plot, :lightposition)
        eyepos = scene.camera.eyeposition
        lightpos = lift(Vec3f, plot.lightposition, eyepos) do pos, eyepos
            return ifelse(pos == :eyeposition, eyepos, pos)::Vec3f
        end
        uniforms[:lightposition] = serialize_three(lightpos[])
        on(lightpos) do value
            updater[] = [:lightposition, serialize_three(value)]
            return
        end
    end
    if haskey(plot, :space)
        mesh[:space] = plot.space[]
    end

    return mesh
end

function serialize_camera(scene::Scene)
    cam = scene.camera
    return lift(cam.view, cam.projection, cam.resolution) do v, p, res
        # projectionview updates with projection & view
        pv = cam.projectionview[]
        # same goes for eyeposition, since an eyepos change will trigger
        # a view matrix change!
        ep = cam.eyeposition[]
        pixel_space = cam.pixel_space[]
        return [serialize_three.((v, p, pv, res, ep, pixel_space))...]
    end
end
