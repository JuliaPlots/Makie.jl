using Makie: get_texture_atlas, glyph_uv_width!, transform_func_obs, apply_transform
using Makie: attribute_per_char, FastPixel, el32convert, Pixel
using Makie: convert_arguments, preprojected_glyph_arrays

convert_attribute(s::ShaderAbstractions.Sampler{RGBAf}, k::key"color") = s
function convert_attribute(s::ShaderAbstractions.Sampler{T, N}, k::key"color") where {T, N}
    ShaderAbstractions.Sampler(
        el32convert(s.data), minfilter = s.minfilter, magfilter = s.magfilter,
        x_repeat = s.repeat[1], y_repeat = s.repeat[min(2, N)], z_repeat = s.repeat[min(3, N)],
        anisotropic = s.anisotropic, color_swizzel = s.color_swizzel
    )
end

gpuvec(x) = GPUVector(GLBuffer(x))

to_range(x, y) = to_range.((x, y))
to_range(x::ClosedInterval) = (minimum(x), maximum(x))
to_range(x::VecTypes{2}) = x
to_range(x::AbstractRange) = (minimum(x), maximum(x))
to_range(x::AbstractVector) = (minimum(x), maximum(x))

function to_range(x::AbstractArray)
    if length(x) in size(x) # assert that just one dim != 1
        to_range(vec(x))
    else
        error("Can't convert to a range. Please supply a range/vector/interval or a tuple (min, max)")
    end
end

function to_glvisualize_key(k)
    k == :rotations && return :rotation
    k == :markersize && return :scale
    k == :glowwidth && return :glow_width
    k == :glowcolor && return :glow_color
    k == :strokewidth && return :stroke_width
    k == :strokecolor && return :stroke_color
    k == :positions && return :position
    k == :linewidth && return :thickness
    k == :marker_offset && return :offset
    k == :colormap && return :color_map
    k == :colorrange && return :color_norm
    k == :transform_marker && return :scale_primitive
    return k
end

make_context_current(screen::Screen) = GLFW.MakeContextCurrent(to_native(screen))

function cached_robj!(robj_func, screen, scene, x::AbstractPlot)
    # poll inside functions to make wait on compile less prominent
    pollevents(screen)
    robj = get!(screen.cache, objectid(x)) do

        filtered = filter(x.attributes) do (k, v)
            !(k in (:transformation, :tickranges, :ticklabels, :raw, :SSAO, :lightposition))
        end

        gl_attributes = Dict{Symbol, Any}(map(filtered) do key_value
            key, value = key_value
            gl_key = to_glvisualize_key(key)
            gl_value = lift_convert(key, value, x)
            gl_key => gl_value
        end)

        if haskey(gl_attributes, :markerspace)
            mspace = pop!(gl_attributes, :markerspace)
            gl_attributes[:use_pixel_marker] = lift(x-> x <: Pixel, mspace)
        end

        if haskey(x.attributes, :lightposition)
            eyepos = scene.camera.eyeposition
            gl_attributes[:lightposition] = lift(x.attributes[:lightposition], eyepos) do pos, eyepos
                return pos == :eyeposition ? eyepos : pos
            end
        end
        robj = robj_func(gl_attributes)
        for key in (:pixel_space, :view, :projection, :resolution, :eyeposition, :projectionview)
            if !haskey(robj.uniforms, key)
                robj[key] = getfield(scene.camera, key)
            end
        end

        if !haskey(gl_attributes, :normalmatrix)
            robj[:normalmatrix] = map(robj[:view], robj[:model]) do v, m
                i = SOneTo(3)
                return transpose(inv(v[i, i] * m[i, i]))
            end
        end

        !haskey(gl_attributes, :ssao) && (robj[:ssao] = Node(false))
        screen.cache2plot[robj.id] = x
        robj
    end
    push!(screen, scene, robj)
    robj
end

function remove_automatic!(attributes)
    filter!(attributes) do (k, v)
        to_value(v) != automatic
    end
end

index1D(x::SubArray) = parentindices(x)[1]

handle_view(array::AbstractVector, attributes) = array
handle_view(array::Node, attributes) = array

function handle_view(array::SubArray, attributes)
    A = parent(array)
    indices = index1D(array)
    attributes[:indices] = indices
    return A
end

function handle_view(array::Node{T}, attributes) where T <: SubArray
    A = lift(parent, array)
    indices = lift(index1D, array)
    attributes[:indices] = indices
    return A
end

function lift_convert(key, value, plot)
    return lift_convert_inner(value, Key{key}(), Key{Makie.plotkey(plot)}(), plot)
end

function lift_convert_inner(value, key, plot_key, plot)
    return lift(value) do value
        return convert_attribute(value, key, plot_key)
    end
end

to_vec4(val::RGB) = RGBAf(val, 1.0)
to_vec4(val::RGBA) = RGBAf(val)

function lift_convert_inner(value, ::key"highclip", plot_key, plot)
    return lift(value, plot.colormap) do value, cmap
        val = value === nothing ? to_colormap(cmap)[end] : to_color(value)
        return to_vec4(val)
    end
end

function lift_convert_inner(value, ::key"lowclip", plot_key, plot)
    return lift(value, plot.colormap) do value, cmap
        val = value === nothing ? to_colormap(cmap)[1] : to_color(value)
        return to_vec4(val)
    end
end

pixel2world(scene, msize::Number) = pixel2world(scene, Point2f(msize))[1]

function pixel2world(scene, msize::StaticVector{2})
    # TODO figure out why Vec(x, y) doesn't work correctly
    p0 = Makie.to_world(scene, Point2f(0.0))
    p1 = Makie.to_world(scene, Point2f(msize))
    diff = p1 - p0
    return diff
end

pixel2world(scene, msize::AbstractVector) = pixel2world.(scene, msize)

function handle_intensities!(attributes)
    if haskey(attributes, :color) && attributes[:color][] isa AbstractVector{<: Number}
        c = pop!(attributes, :color)
        attributes[:intensity] = lift(x-> convert(Vector{Float32}, x), c)
    else
        delete!(attributes, :intensity)
        delete!(attributes, :color_map)
        delete!(attributes, :color_norm)
    end
end

function Base.insert!(screen::GLScreen, scene::Scene, @nospecialize(x::Combined))
    # poll inside functions to make wait on compile less prominent
    pollevents(screen)
    if isempty(x.plots) # if no plots inserted, this truly is an atomic
        draw_atomic(screen, scene, x)
    else
        foreach(x.plots) do x
            # poll inside functions to make wait on compile less prominent
            pollevents(screen)
            insert!(screen, scene, x)
        end
    end
end

function draw_atomic(screen::GLScreen, scene::Scene, @nospecialize(x::Union{Scatter, MeshScatter}))
    robj = cached_robj!(screen, scene, x) do gl_attributes
        # signals not supported for shading yet
        gl_attributes[:shading] = to_value(get(gl_attributes, :shading, true))
        marker = lift_convert(:marker, pop!(gl_attributes, :marker), x)
        if isa(x, Scatter)
            gl_attributes[:billboard] = map(rot-> isa(rot, Billboard), x.rotations)
            gl_attributes[:distancefield][] == nothing && delete!(gl_attributes, :distancefield)
            gl_attributes[:uv_offset_width][] == Vec4f(0) && delete!(gl_attributes, :uv_offset_width)
        end

        positions = handle_view(x[1], gl_attributes)
        positions = apply_transform(transform_func_obs(x), positions)

        if marker[] isa FastPixel
            filter!(gl_attributes) do (k, v,)
                k in (:color_map, :color, :color_norm, :scale, :fxaa, :model)
            end
            if !(gl_attributes[:color][] isa AbstractVector{<: Number})
                delete!(gl_attributes, :color_norm)
                delete!(gl_attributes, :color_map)
            end
            visualize(positions, Style(:speed), Dict{Symbol, Any}(gl_attributes))
        else
            handle_intensities!(gl_attributes)
            visualize((marker, positions), Style(:default), Dict{Symbol, Any}(gl_attributes))
        end
    end
end

function draw_atomic(screen::GLScreen, scene::Scene, @nospecialize(x::Lines))
    robj = cached_robj!(screen, scene, x) do gl_attributes
        linestyle = pop!(gl_attributes, :linestyle)
        data = Dict{Symbol, Any}(gl_attributes)
        ls = to_value(linestyle)
        if isnothing(ls)
            data[:pattern] = ls
        else
            linewidth = gl_attributes[:thickness]
            data[:pattern] = ls .* (to_value(linewidth) * 0.25)
        end
        positions = handle_view(x[1], data)
        positions = apply_transform(transform_func_obs(x), positions)
        handle_intensities!(data)
        visualize(positions, Style(:lines), data)
    end
end

function draw_atomic(screen::GLScreen, scene::Scene, @nospecialize(x::LineSegments))
    robj = cached_robj!(screen, scene, x) do gl_attributes
        linestyle = pop!(gl_attributes, :linestyle)
        data = Dict{Symbol, Any}(gl_attributes)
        ls = to_value(linestyle)
        if isnothing(ls)
            data[:pattern] = ls
        else
            linewidth = gl_attributes[:thickness]
            data[:pattern] = ls .* (to_value(linewidth) * 0.25)
        end
        positions = handle_view(x.converted[1], data)
        positions = apply_transform(transform_func_obs(x), positions)
        if haskey(data, :color) && data[:color][] isa AbstractVector{<: Number}
            c = pop!(data, :color)
            data[:color] = el32convert(c)
        else
            delete!(data, :color_map)
            delete!(data, :color_norm)
        end
        visualize(positions, Style(:linesegment), data)
    end
end

value_or_first(x::AbstractArray) = first(x)
value_or_first(x::StaticArray) = x
value_or_first(x) = x

function draw_atomic(screen::GLScreen, scene::Scene,
        x::Text{<:Tuple{<:Union{<:Makie.GlyphCollection, <:AbstractVector{<:Makie.GlyphCollection}}}})

    robj = cached_robj!(screen, scene, x) do gl_attributes
        glyphcollection = x[1]
        liftkeys = (:position, :rotation, :model, :space, :offset)
        args = getindex.(Ref(gl_attributes), liftkeys)

        # TODO: This is a hack before we get better updating of plot objects and attributes going.
        # Here we only update the glyphs when the glyphcollection changes, if it's a singular glyphcollection.
        # The if statement will be compiled away depending on the parameter of Text.
        # This means that updates of a text vector and a separate position vector will still not work if only the text
        # vector is triggered, but basically all internal objects use the vector of tuples version, and that triggers
        # both glyphcollection and position, so it still works
        if glyphcollection[] isa Makie.GlyphCollection
            # here we lift the glyph collection
            collect_glyph_data = (gcollection, projview, transfunc, pos, rotation, model, space, offset) -> begin
                res = Vec2f(widths(pixelarea(scene)[]))
                preprojected_glyph_arrays(pos, gcollection, space, projview, res, offset, transfunc)
            end
            glyph_data = lift(collect_glyph_data, glyphcollection, scene.camera.projectionview, Makie.transform_func_obs(scene), args...)
        else
            # and here we don't because it triggers dimension mismatches
            collect_glyph_data = (projview, transfunc, pos, rotation, model, space, offset) -> begin
                gcollection = glyphcollection[]
                res = Vec2f(widths(pixelarea(scene)[]))
                preprojected_glyph_arrays(pos, gcollection, space, projview, res, offset, transfunc)
            end
            glyph_data = lift(collect_glyph_data, scene.camera.projectionview, Makie.transform_func_obs(scene), args...)
        end


        # unpack values from the one signal:
        positions, offset, uv_offset_width, scale = map((1, 2, 3, 4)) do i
            lift(getindex, glyph_data, i)
        end

        atlas = get_texture_atlas()
        keys = (:color, :strokecolor, :rotation)

        signals = map(keys) do key
            Makie.get_attribute(x, key)
        end

        filter!(gl_attributes) do (k, v)
            # These are liftkeys without model
            !(k in (
                :position, :space, :font,
                :textsize, :rotation, :justification
            ))
        end

        gl_attributes[:color] = lift(glyphcollection) do gc
            if gc isa AbstractArray
                reduce(vcat, (Makie.collect_vector(g.colors, length(g.glyphs)) for g in gc),
                    init = RGBAf[])
            else
                Makie.collect_vector(gc.colors, length(gc.glyphs))
            end
        end
        gl_attributes[:stroke_color] = lift(glyphcollection) do gc
            if gc isa AbstractArray
                reduce(vcat, (Makie.collect_vector(g.strokecolors, length(g.glyphs)) for g in gc),
                    init = RGBAf[])
            else
                Makie.collect_vector(gc.strokecolors, length(gc.glyphs))
            end
        end
        gl_attributes[:rotation] = lift(glyphcollection) do gc
            if gc isa AbstractArray
                reduce(vcat, (Makie.collect_vector(g.rotations, length(g.glyphs)) for g in gc),
                    init = Quaternionf[])
            else
                Makie.collect_vector(gc.rotations, length(gc.glyphs))
            end
        end

        gl_attributes[:scale] = scale
        gl_attributes[:offset] = offset
        gl_attributes[:uv_offset_width] = uv_offset_width
        gl_attributes[:distancefield] = get_texture!(atlas)
        gl_attributes[:visible] = x.visible

        robj = visualize((DISTANCEFIELD, positions), Style(:default), gl_attributes)
        # Draw text in screenspace
        if x.space[] == :screen
            robj[:view] = Observable(Mat4f(I))
            robj[:projection] = scene.camera.pixel_space
            robj[:projectionview] = scene.camera.pixel_space
        end

        return robj
    end
    return robj
end

# el32convert doesn't copy for array of Float32
# But we assume that xy_convert copies when we use it
xy_convert(x::AbstractArray{Float32}, n) = copy(x)
xy_convert(x::AbstractArray, n) = el32convert(x)
xy_convert(x, n) = Float32[LinRange(extrema(x)..., n + 1);]

function draw_atomic(screen::GLScreen, scene::Scene, x::Heatmap)
    return cached_robj!(screen, scene, x) do gl_attributes
        t = Makie.transform_func_obs(scene)
        mat = x[3]
        xypos = map(t, x[1], x[2]) do t, x, y
            x1d = xy_convert(x, size(mat[], 1))
            y1d = xy_convert(y, size(mat[], 2))
            # Only if transform doesn't do anything, we can stay linear in 1/2D
            if t === identity || t isa Tuple && all(x-> x === identity, t)
                return (x1d, y1d)
            else
                # If we do any transformation, we have to assume things aren't on the grid anymore
                # so x + y need to become matrices.
                map!(x1d, x1d) do x
                    return apply_transform(t, Point(x, 0))[1]
                end
                map!(y1d, y1d) do y
                    return apply_transform(t, Point(0, y))[2]
                end
                return (x1d, y1d)
            end
        end
        xpos = map(first, xypos)
        ypos = map(last, xypos)
        gl_attributes[:position_x] = Texture(xpos, minfilter = :nearest)
        gl_attributes[:position_y] = Texture(ypos, minfilter = :nearest)
        # number of planes used to render the heatmap
        gl_attributes[:instances] = map(xpos, ypos) do x, y
            (length(x)-1) * (length(y)-1)
        end
        interp = to_value(pop!(gl_attributes, :interpolate))
        interp = interp ? :linear : :nearest
        if !(to_value(mat) isa ShaderAbstractions.Sampler)
            tex = Texture(el32convert(mat), minfilter = interp)
        else
            tex = to_value(mat)
        end
        pop!(gl_attributes, :color)
        gl_attributes[:stroke_width] = pop!(gl_attributes, :thickness)
        # gl_attributes[:color_map] = Texture(gl_attributes[:color_map], minfilter=:nearest)
        GLVisualize.assemble_shader(GLVisualize.gl_heatmap(tex, gl_attributes))
    end
end

function vec2color(colors, cmap, crange)
    Makie.interpolated_getindex.((to_colormap(cmap),), colors, (crange,))
end

function get_image(plot)
    if isa(plot[:color][], AbstractMatrix{<: Number})
        lift(vec2color, pop!.(Ref(plot), (:color, :color_map, :color_norm))...)
    else
        delete!(plot, :color_norm)
        delete!(plot, :color_map)
        return pop!(plot, :color)
    end
end

function draw_atomic(screen::GLScreen, scene::Scene, x::Image)
    robj = cached_robj!(screen, scene, x) do gl_attributes
        gl_attributes[:ranges] = lift(to_range, x[1], x[2])
        img = get_image(gl_attributes)
        interp = to_value(pop!(gl_attributes, :interpolate))
        interp = interp ? :linear : :nearest
        tex = Texture(el32convert(img), minfilter = interp)
        visualize(tex, Style(:default), gl_attributes)
    end
end

convert_mesh_color(c::AbstractArray{<: Number}, cmap, crange) = vec2color(c, cmap, crange)
convert_mesh_color(c, cmap, crange) = c

function update_positions(mesh::GeometryBasics.Mesh, positions)
    points = coordinates(mesh)
    attr = GeometryBasics.attributes(points)
    delete!(attr, :position) # position == metafree(points)
    return GeometryBasics.Mesh(meta(positions; attr...), faces(mesh))
end

function draw_atomic(screen::GLScreen, scene::Scene, meshplot::Mesh)
    robj = cached_robj!(screen, scene, meshplot) do gl_attributes
        # signals not supported for shading yet
        gl_attributes[:shading] = to_value(pop!(gl_attributes, :shading))
        color = pop!(gl_attributes, :color)
        # cmap = get(gl_attributes, :color_map, Node(nothing)); delete!(gl_attributes, :color_map)
        # crange = get(gl_attributes, :color_norm, Node(nothing)); delete!(gl_attributes, :color_norm)
        mesh = meshplot[1]

        if to_value(color) isa Colorant
            gl_attributes[:vertex_color] = color
            delete!(gl_attributes, :color_map)
            delete!(gl_attributes, :color_norm)
        elseif to_value(color) isa Makie.AbstractPattern
            img = lift(x -> el32convert(Makie.to_image(x)), color)
            gl_attributes[:image] = ShaderAbstractions.Sampler(img, x_repeat=:repeat, minfilter=:nearest)
            haskey(gl_attributes, :fetch_pixel) || (gl_attributes[:fetch_pixel] = true)
        elseif to_value(color) isa AbstractMatrix{<:Colorant}
            gl_attributes[:image] = color
            delete!(gl_attributes, :color_map)
            delete!(gl_attributes, :color_norm)
        elseif to_value(color) isa AbstractMatrix{<: Number}
            cmap = pop!(gl_attributes, :color_map)
            crange = pop!(gl_attributes, :color_norm)
            mesh = lift(mesh, color, cmap, crange) do mesh, color, cmap, crange
                color_sampler = convert_mesh_color(color, cmap, crange)
                mesh, uv = GeometryBasics.pop_pointmeta(mesh, :uv)
                uv_sampler = Makie.sampler(color_sampler, uv)
                return GeometryBasics.pointmeta(mesh, color=uv_sampler)
            end
        elseif to_value(color) isa AbstractVector{<: Union{Number, Colorant}}
            mesh = lift(mesh, color) do mesh, color
                return GeometryBasics.pointmeta(mesh, color=el32convert(color))
            end
        end

        mesh = map(mesh, transform_func_obs(meshplot)) do mesh, func
            if func ∉ (identity, (identity, identity), (identity, identity, identity))
                return update_positions(mesh, apply_transform.(Ref(func), mesh.position))
            end
            return mesh
        end
        visualize(mesh, Style(:default), gl_attributes)
    end
end

function draw_atomic(screen::GLScreen, scene::Scene, x::Surface)
    robj = cached_robj!(screen, scene, x) do gl_attributes
        color = pop!(gl_attributes, :color)
        img = nothing
        # signals not supported for shading yet
        # We automatically insert x[3] into the color channel, so if it's equal we don't need to do anything
        if isa(to_value(color), AbstractMatrix{<: Number}) && to_value(color) !== to_value(x[3])
            img = el32convert(color)
        elseif to_value(color) isa Makie.AbstractPattern
            pattern_img = lift(x -> el32convert(Makie.to_image(x)), color)
            img = ShaderAbstractions.Sampler(pattern_img, x_repeat=:repeat, minfilter=:nearest)
            haskey(gl_attributes, :fetch_pixel) || (gl_attributes[:fetch_pixel] = true)
            gl_attributes[:color_map] = nothing
            gl_attributes[:color] = nothing
            gl_attributes[:color_norm] = nothing
        elseif isa(to_value(color), AbstractMatrix{<: Colorant})
            img = color
            gl_attributes[:color_map] = nothing
            gl_attributes[:color] = nothing
            gl_attributes[:color_norm] = nothing
        end

        gl_attributes[:image] = img
        gl_attributes[:shading] = to_value(get(gl_attributes, :shading, true))

        @assert to_value(x[3]) isa AbstractMatrix
        types = map(v -> typeof(to_value(v)), x[1:2])

        if all(T -> T <: Union{AbstractMatrix, AbstractVector}, types)
            t = Makie.transform_func_obs(scene)
            mat = x[3]
            xypos = map(t, x[1], x[2]) do t, x, y
                x1d = xy_convert(x, size(mat[], 1))
                y1d = xy_convert(y, size(mat[], 2))
                # Only if transform doesn't do anything, we can stay linear in 1/2D
                if t === identity
                    return (x1d, y1d)
                else
                    # If we do any transformation, we have to assume things aren't on the grid anymore
                    # so x + y need to become matrices.
                    matrix = [apply_transform(t, Point(x, y)) for x in x1d, y in y1d]
                    return (first.(matrix), last.(matrix))
                end
            end
            xpos = map(first, xypos)
            ypos = map(last, xypos)
            args = map((xpos, ypos, mat)) do arg
                Texture(el32convert(arg); minfilter=:nearest)
            end
            return visualize(args, Style(:surface), gl_attributes)
        else
            gl_attributes[:ranges] = to_range.(to_value.(x[1:2]))
            z_data = Texture(el32convert(x[3]); minfilter=:nearest)
            return visualize(z_data, Style(:surface), gl_attributes)
        end
    end
    return robj
end

function draw_atomic(screen::GLScreen, scene::Scene, vol::Volume)
    robj = cached_robj!(screen, scene, vol) do gl_attributes
        model = vol[:model]
        x, y, z = vol[1], vol[2], vol[3]
        gl_attributes[:model] = lift(model, x, y, z) do m, xyz...
            mi = minimum.(xyz)
            maxi = maximum.(xyz)
            w = maxi .- mi
            m2 = Mat4f(
                w[1], 0, 0, 0,
                0, w[2], 0, 0,
                0, 0, w[3], 0,
                mi[1], mi[2], mi[3], 1
            )
            return convert(Mat4f, m) * m2
        end
        return visualize(vol[4], Style(:default), gl_attributes)
    end
end
