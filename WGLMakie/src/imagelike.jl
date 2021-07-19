using Makie: el32convert, surface_normals, get_dim

# Somehow we started using Nothing for some colors in Makie,
# but the convert leaves them at nothing -.-
# TODO clean this up in Makie
nothing_or_color(c) = to_color(c)
nothing_or_color(c::Nothing) = RGBAf(0, 0, 0, 1)

function draw_mesh(mscene::Scene, mesh, plot; uniforms...)
    uniforms = Dict(uniforms)

    colormap = if haskey(plot, :colormap)
        cmap = lift(el32convert ∘ to_colormap, plot.colormap)
        uniforms[:colormap] = Sampler(cmap)
    end

    colorrange = if haskey(plot, :colorrange)
        uniforms[:colorrange] = lift(Vec2f, plot.colorrange)
    end

    get!(uniforms, :colormap, false)
    get!(uniforms, :colorrange, false)
    get!(uniforms, :color, false)
    get!(uniforms, :model, plot.model)

    uniforms[:normalmatrix] = map(mscene.camera.view, plot.model) do v, m
        i = SOneTo(3)
        return transpose(inv(v[i, i] * m[i, i]))
    end
    return Program(WebGL(), lasset("mesh.vert"), lasset("mesh.frag"), mesh; uniforms...)
end

xy_convert(x::AbstractArray{Float32}, n) = copy(x)
xy_convert(x::AbstractArray, n) = el32convert(x)
xy_convert(x, n) = Float32[LinRange(extrema(x)..., n + 1);]

function limits_to_uvmesh(plot)
    px, py, pz = plot[1], plot[2], plot[3]
    px = map((x, z)-> xy_convert(x, size(z, 1)), px, pz)
    py = map((y, z)-> xy_convert(y, size(z, 2)), py, pz)
    # Special path for ranges of length 2 wich
    # can be displayed as a rectangle
    t = Makie.transform_func_obs(plot)[]
    identity_transform = t === identity || t isa Tuple && all(x-> x === identity, t)
    if length(px[]) == 2 && length(py[]) == 2 && identity_transform
        rect = lift(px, py) do x, y
            xmin, xmax = x
            ymin, ymax = y
            return Rect2(xmin, ymin, xmax - xmin, ymax - ymin)
        end
        positions = Buffer(lift(rect-> decompose(Point2f, rect), rect))
        faces = Buffer(lift(rect -> decompose(GLTriangleFace, rect), rect))
        uv = Buffer(lift(decompose_uv, rect))
    else
        function grid(x, y, z, trans)
            g = map(CartesianIndices((length(x), length(y)))) do i
                p = Point3f(get_dim(x, i, 1, size(z)), get_dim(y, i, 2, size(z)), 0.0)
                return apply_transform(trans, p)
            end
            return vec(g)
        end
        rect = lift(z -> Tesselation(Rect2(0f0, 0f0, 1f0, 1f0), size(z) .+ 1), pz)
        positions = Buffer(lift(grid, px, py, pz, t))
        faces = Buffer(lift(r -> decompose(GLTriangleFace, r), rect))
        uv = Buffer(lift(decompose_uv, rect))
    end

    vertices = GeometryBasics.meta(positions; uv=uv)

    return GeometryBasics.Mesh(vertices, faces)
end

function create_shader(mscene::Scene, plot::Surface)
    # TODO OWN OPTIMIZED SHADER ... Or at least optimize this a bit more ...
    px, py, pz = plot[1], plot[2], plot[3]
    function grid(x, y, z, trans)
        g = map(CartesianIndices(z)) do i
            p = Point3f(get_dim(x, i, 1, size(z)), get_dim(y, i, 2, size(z)), z[i])
            return apply_transform(trans, p)
        end
        return vec(g)
    end

    positions = Buffer(lift(grid, px, py, pz, transform_func_obs(plot)))
    rect = lift(z -> Tesselation(Rect2(0f0, 0f0, 1f0, 1f0), size(z)), pz)
    faces = Buffer(lift(r -> decompose(GLTriangleFace, r), rect))
    uv = Buffer(lift(decompose_uv, rect))
    pcolor = if haskey(plot, :color) && plot.color[] isa AbstractArray
        plot.color
    else
        pz
    end
    minfilter = to_value(get(plot, :interpolate, false)) ? :linear : :nearest
    color = Sampler(lift(x -> el32convert(x'), pcolor), minfilter=minfilter)
    normals = Buffer(lift(surface_normals, px, py, pz))
    vertices = GeometryBasics.meta(positions; uv=uv, normals=normals)
    mesh = GeometryBasics.Mesh(vertices, faces)
    return draw_mesh(mscene, mesh, plot; uniform_color=color, color=Vec4f(0),
                     shading=plot.shading, ambient=plot.ambient, diffuse=plot.diffuse,
                     specular=plot.specular, shininess=plot.shininess,
                     lightposition=Vec3f(1),
                     highclip=lift(nothing_or_color, plot.highclip),
                     lowclip=lift(nothing_or_color, plot.lowclip),
                     nan_color=lift(nothing_or_color, plot.nan_color))
end

function create_shader(mscene::Scene, plot::Union{Heatmap,Image})
    image = plot[3]
    color = Sampler(map(x -> el32convert(x'), image);
                    minfilter=to_value(get(plot, :interpolate, false)) ? :linear : :nearest)
    mesh = limits_to_uvmesh(plot)

    return draw_mesh(mscene, mesh, plot; uniform_color=color, color=Vec4f(0),
                     normals=Vec3f(0), shading=false, ambient=plot.ambient,
                     diffuse=plot.diffuse, specular=plot.specular,
                     colorrange=haskey(plot, :colorrange) ? plot.colorrange : false,
                     shininess=plot.shininess, lightposition=Vec3f(1),
                     highclip=lift(nothing_or_color, plot.highclip),
                     lowclip=lift(nothing_or_color, plot.lowclip),
                     nan_color=lift(nothing_or_color, plot.nan_color))
end

function create_shader(mscene::Scene, plot::Volume)
    x, y, z, vol = plot[1], plot[2], plot[3], plot[4]
    box = GeometryBasics.mesh(Rect3f(Vec3f(0), Vec3f(1)))
    cam = cameracontrols(mscene)
    model2 = lift(plot.model, x, y, z) do m, xyz...
        mi = minimum.(xyz)
        maxi = maximum.(xyz)
        w = maxi .- mi
        m2 = Mat4f(w[1], 0, 0, 0, 0, w[2], 0, 0, 0, 0, w[3], 0, mi[1], mi[2], mi[3], 1)
        return convert(Mat4f, m) * m2
    end

    modelinv = lift(inv, model2)
    algorithm = lift(x -> Cuint(convert_attribute(x, key"algorithm"())), plot.algorithm)

    return Program(WebGL(), lasset("volume.vert"), lasset("volume.frag"), box,
                   volumedata=Sampler(lift(Makie.el32convert, vol)),
                   modelinv=modelinv, colormap=Sampler(lift(to_colormap, plot.colormap)),
                   colorrange=lift(Vec2f, plot.colorrange),
                   isovalue=lift(Float32, plot.isovalue),
                   isorange=lift(Float32, plot.isorange),
                   absorption=lift(Float32, get(plot, :absorption, Observable(1f0))),
                   algorithm=algorithm, ambient=plot.ambient,
                   diffuse=plot.diffuse, specular=plot.specular, shininess=plot.shininess,
                   model=model2,
                   # these get filled in later by serialization, but we need them
                   # as dummy values here, so that the correct uniforms are emitted
                   lightposition=Vec3f(1), eyeposition=Vec3f(1))
end
