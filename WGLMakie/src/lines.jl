topoint(x::AbstractVector{Point{N,Float32}}) where {N} = x

# GRRR STUPID SubArray, with eltype different from getindex(x, 1)
topoint(x::SubArray) = topoint([el for el in x])

function topoint(x::AbstractArray{<:Point{N,T}}) where {T,N}
    return topoint(Point{N,Float32}.(x))
end

function topoint(x::AbstractArray{<:Tuple{P,P}}) where {P<:Point}
    return topoint(reinterpret(P, x))
end

function create_shader(scene::Scene, plot::Union{Lines,LineSegments})
    # Potentially per instance attributes
    positions = lift(plot[1], transform_func_obs(plot)) do points, trans
        points = apply_transform(trans, topoint(points))
        if plot isa LineSegments
            return points
        else
            # Repeat every second point to connect the lines !
            return topoint(TupleView{2, 1}(points))
        end
        trans
    end
    startr = lift(p -> 1:2:(length(p) - 1), positions)
    endr = lift(p -> 2:2:length(p), positions)
    p_start_end = lift(positions) do positions
        return (positions[startr[]], positions[endr[]])
    end

    per_instance = Dict{Symbol,Any}(:segment_start => Buffer(lift(first, p_start_end)),
                                    :segment_end => Buffer(lift(last, p_start_end)))
    uniforms = Dict{Symbol,Any}()
    for k in (:linewidth, :color)
        attribute = lift(plot[k]) do x
            x = convert_attribute(x, Key{k}(), key"lines"())
            if plot isa LineSegments
                return x
            else
                # Repeat every second point to connect the lines!
                return isscalar(x) ? x : reinterpret(eltype(x), TupleView{2, 1}(x))
            end
        end
        if isscalar(attribute)
            uniforms[k] = attribute
            uniforms[Symbol("$(k)_start")] = attribute
            uniforms[Symbol("$(k)_end")] = attribute
        else
            if attribute[] isa AbstractVector{<:Number} && haskey(plot, :colorrange)
                attribute = lift(array2color, attribute, plot.colormap, plot.colorrange)
            end
            per_instance[Symbol("$(k)_start")] = Buffer(lift(x -> x[startr[]], attribute))
            per_instance[Symbol("$(k)_end")] = Buffer(lift(x -> x[endr[]], attribute))
        end
    end

    uniforms[:resolution] = scene.camera.resolution
    uniforms[:model] = plot.model
    positions = meta(Point2f[(0, -1), (0, 1), (1, -1), (1, 1)],
                     uv=Vec2f[(0, 0), (0, 0), (0, 0), (0, 0)])
    instance = GeometryBasics.Mesh(positions, GLTriangleFace[(1, 2, 3), (2, 4, 3)])
    return InstancedProgram(WebGL(), lasset("line_segments.vert"),
                            lasset("line_segments.frag"), instance,
                            VertexArray(; per_instance...); uniforms...)
end
