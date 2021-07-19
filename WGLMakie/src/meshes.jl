function vertexbuffer(x, trans)
    pos = decompose(Point, x)
    return apply_transform(trans,  pos)
end

function vertexbuffer(x::Observable, p)
    return Buffer(lift(vertexbuffer, x, transform_func_obs(p)))
end

facebuffer(x) = facebuffer(GeometryBasics.faces(x))
facebuffer(x::Observable) = Buffer(lift(facebuffer, x))
function facebuffer(x::AbstractArray{GLTriangleFace})
    return x
end

function array2color(colors, cmap, crange)
    cmap = RGBAf.(Colors.color.(to_colormap(cmap)), 1.0)
    return Makie.interpolated_getindex.((cmap,), colors, (crange,))
end

function array2color(colors::AbstractArray{<:Colorant}, cmap, crange)
    return RGBAf.(colors)
end

function converted_attribute(plot::AbstractPlot, key::Symbol)
    return lift(plot[key]) do value
        return convert_attribute(value, Key{key}(), Key{plotkey(plot)}())
    end
end

function create_shader(scene::Scene, plot::Makie.Mesh)
    # Potentially per instance attributes
    mesh_signal = plot[1]
    mattributes = GeometryBasics.attributes
    get_attribute(mesh, key) = lift(x -> getproperty(x, key), mesh)
    data = mattributes(mesh_signal[])

    uniforms = Dict{Symbol,Any}()
    attributes = Dict{Symbol,Any}()

    for (key, default) in (:uv => Vec2f(0), :normals => Vec3f(0))
        if haskey(data, key)
            attributes[key] = Buffer(get_attribute(mesh_signal, key))
        else
            uniforms[key] = Observable(default)
        end
    end

    if haskey(data, :attributes) && data[:attributes] isa AbstractVector
        attr = get_attribute(mesh_signal, :attributes)
        attr_id = get_attribute(mesh_signal, :attribute_id)
        color = lift((c, id) -> c[Int.(id) .+ 1], attr_id)
        attributes[:color] = Buffer(color)
        uniforms[:uniform_color] = false
    else
        color_signal = converted_attribute(plot, :color)
        color = color_signal[]
        mesh_color = color_signal[]
        uniforms[:uniform_color] = Observable(false) # this is the default

        if color isa Colorant && haskey(data, :color)
            color_signal = get_attribute(mesh_signal, :color)
            color = color_signal[]
        end

        if color isa AbstractArray
            c_converted = if color isa AbstractArray{<:Colorant}
                color_signal
            elseif color isa AbstractArray{<:Number}
                lift(array2color, color_signal, plot.colormap, plot.colorrange)
            else
                error("Unsupported color type: $(typeof(color))")
            end
            if c_converted[] isa AbstractVector
                attributes[:color] = Buffer(c_converted) # per vertex colors
            else
                uniforms[:uniform_color] = Sampler(c_converted) # Texture
                !haskey(attributes, :uv) &&
                    @warn "Mesh doesn't use Texturecoordinates, but has a Texture. Colors won't map"
            end
        elseif color isa Colorant && !haskey(attributes, :color)
            uniforms[:uniform_color] = color_signal
        else
            error("Unsupported color type: $(typeof(color))")
        end
    end

    if !haskey(attributes, :color)
        uniforms[:color] = Vec4f(0) # make sure we have a color attribute
    end

    uniforms[:shading] = plot.shading

    for key in (:ambient, :diffuse, :specular, :shininess)
        uniforms[key] = plot[key]
    end

    faces = facebuffer(mesh_signal)
    positions = vertexbuffer(mesh_signal, plot)
    instance = GeometryBasics.Mesh(GeometryBasics.meta(positions; attributes...), faces)

    get!(uniforms, :colorrange, true)
    get!(uniforms, :colormap, true)
    get!(uniforms, :model, plot.model)
    get!(uniforms, :lightposition, Vec3f(1))

    get!(uniforms, :nan_color, RGBAf(0, 0, 0, 0))
    get!(uniforms, :highclip, RGBAf(0, 0, 0, 0))
    get!(uniforms, :lowclip, RGBAf(0, 0, 0, 0))

    uniforms[:normalmatrix] = map(scene.camera.view, plot.model) do v, m
        i = SOneTo(3)
        return transpose(inv(v[i, i] * m[i, i]))
    end

    return Program(WebGL(), lasset("mesh.vert"), lasset("mesh.frag"), instance; uniforms...)
end
