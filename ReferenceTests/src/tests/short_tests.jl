@cell arc(Point2f(0), 10f0, 0f0, pi, linewidth=20)

@cell mesh(Recti(0, 0, 200, 200))

@cell poly(Recti(0, 0, 200, 200), strokewidth=20, strokecolor=:red, color=(:black, 0.4))

@cell begin
    scene = poly([Rect(0, 0, 20, 20)])
    scatter!(Rect(0, 0, 20, 20), color=:red, markersize=20)
    current_figure()
end

@cell begin
    lines(Rect(0, 0, 1, 1), linewidth=4, scale_plot=false)
    scatter!([Point2f(0.5, 0.5)], markersize=1, markerspace=SceneSpace, marker='I', scale_plot=false)
    current_figure()
end

@cell lines(RNG.rand(10), RNG.rand(10), color=RNG.rand(10), linewidth=10)
@cell lines(RNG.rand(10), RNG.rand(10), color=RNG.rand(RGBAf, 10), linewidth=10)
@cell scatter(0..1, RNG.rand(10), markersize=RNG.rand(10) .* 20)
@cell scatter(LinRange(0, 1, 10), RNG.rand(10))
@cell scatter(RNG.rand(10), LinRange(0, 1, 10))

@cell begin
    angles = range(0, stop=2pi, length=20)
    pos = Point2f.(sin.(angles), cos.(angles))
    scatter(pos, markersize=0.2, markerspace=SceneSpace, rotations=-angles, marker='▲', axis=(;aspect = DataAspect()))
    scatter!(pos, markersize=10, color=:red, axis=(;aspect = DataAspect()))
    current_figure()
end

@cell heatmap(RNG.rand(50, 50), colormap=:RdBu, alpha=0.2)

@cell contour(RNG.rand(10, 100))
@cell contour(RNG.rand(100, 10))
@cell contour(RNG.randn(100, 90), levels=3)

@cell contour(RNG.randn(100, 90), levels=[0.1, 0.5, 0.8])
@cell contour(RNG.randn(100, 90), levels=[0.1, 0.5, 0.8], color=:black)
@cell contour(RNG.randn(33, 30), levels=[0.1, 0.5, 0.9], color=[:black, :green, (:blue, 0.4)], linewidth=2)
@cell contour(RNG.randn(33, 30), levels=[0.1, 0.5, 0.9], colormap=:Spectral)
@cell contour(
    RNG.rand(33, 30) .* 6 .- 3, levels=[-2.5, 0.4, 0.5, 0.6, 2.5],
    colormap=[(:black, 0.2), :red, :blue, :green, (:black, 0.2)],
    colorrange=(0.2, 0.8)
)

@cell lines(Circle(Point2f(0), Float32(1)); scale_plot=false, resolution=(800, 1000))

@cell begin
    v(x::Point2{T}) where T = Point2{T}(x[2], 4 * x[1])
    streamplot(v, -2..2, -2..2)
end

@cell lines(-1..1, x -> x^2)
@cell scatter(-1..1, x -> x^2)

@cell begin
    r = range(-3pi, stop=3pi, length=100)
    fig, ax, vplot = volume(r, r, r, (x, y, z) -> cos(x) + sin(y) + cos(z), algorithm=:iso, isorange=0.1f0, show_axis=false)
    v2 = volume!(ax, r, r, r, (x, y, z) -> cos(x) + sin(y) + cos(z), algorithm=:mip, show_axis=false)
    translate!(v2, Vec3f(6pi, 0, 0))
    fig
end

@cell meshscatter(RNG.rand(10), RNG.rand(10), RNG.rand(10), color=RNG.rand(10))
@cell meshscatter(RNG.rand(10), RNG.rand(10), RNG.rand(10), color=RNG.rand(RGBAf, 10))

@cell begin
    s1 = uv_mesh(Sphere(Point3f(0), 1f0))
    mesh(uv_mesh(Sphere(Point3f(0), 1f0)), color=RNG.rand(50, 50))
    # ugh, bug In GeometryTypes for UVs of non unit spheres.
    s2 = uv_mesh(Sphere(Point3f(0), 1f0))
    s2.position .= s2.position .+ (Point3f(0, 2, 0),)
    mesh!(s2, color=RNG.rand(RGBAf, 50, 50))
    current_figure()
end

@cell "Unequal x and y sizes in surface" begin
    #
    NL = 15
    NR = 31
    function xy_data(x, y)
        r = sqrt(x^2 + y^2)
        r == 0.0 ? 1f0 : (sin(r) / r)
    end
    lspace = range(-10, stop=10, length=NL)
    rspace = range(-10, stop=10, length=NR)

    z = Float32[xy_data(x, y) for x in lspace, y in rspace]
    l = range(0, stop=3, length=NL)
    r = range(0, stop=3, length=NR)
    surface(
        l, r, z,
        colormap=:Spectral
    )
end

@cell "Matrices of data in surfaces" begin
    NL = 30
    NR = 31
    function xy_data(x, y)
        r = sqrt(x^2 + y^2)
        r == 0.0 ? 1f0 : (sin(r) / r)
    end
    lspace = range(-10, stop=10, length=NL)
    rspace = range(-10, stop=10, length=NR)

    z = Float32[xy_data(x, y) for x in lspace, y in rspace]
    l = range(0, stop=3, length=NL)
    r = range(0, stop=3, length=NR)
    surface(
        [l for l in l, r in r], [r for l in l, r in r], z,
        colormap=:Spectral
    )
end

@cell "heatmaps & surface" begin
    data =
        hcat(LinRange(2, 3, 4), LinRange(2, 2.5, 4), LinRange(2.5, 3, 4), [1, NaN, NaN, 5])

    fig = Figure()
    heatmap(
        fig[1, 1],
        data,
        colorrange = (2, 3),
        highclip = :red,
        lowclip = :black,
        nan_color = (:green, 0.5),
    )
    surface(
        fig[1, 2],
        zeros(size(data)),
        color = data,
        colorrange = (2, 3),
        highclip = :red,
        lowclip = :black,
        nan_color = (:green, 0.5),
        shading = false,
    )
    surface!(
        Axis(fig[2, 2]),
        data,
        colorrange = (2, 3),
        highclip = :red,
        lowclip = :black,
        nan_color = (:green, 0.5),
        shading = false,
    )
    fig
end

@cell "log10 heatmap" begin
    heatmap(RNG.rand(10, 5), axis = (yscale = log10, xscale=log10))
end

@cell "reverse range heatmap" begin
    x = [1 0
         2 3]
    heatmap(1:2, 1:-1:0, x)
end
