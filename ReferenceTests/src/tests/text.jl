using LaTeXStrings

@cell "heatmap_with_labels" begin
    fig = Figure(resolution = (600, 600))
    ax = fig[1, 1] = Axis(fig)
    values = RNG.rand(10, 10)

    heatmap!(ax, values)

    text!(ax,
        string.(round.(vec(values'), digits = 2)),
        position = [Point2f(x, y) for x in 1:10 for y in 1:10],
        align = (:center, :center),
        color = ifelse.(vec(values') .< 0.3, :white, :black),
        textsize = 12)
    fig
end

@cell "data space" begin
    pos = [Point2f(0, 0), Point2f(10, 10)]
    fig = text(
        ["0 is the ORIGIN of this", "10 says hi"],
        position = pos,
        axis = (aspect = DataAspect(),),
        space = :data,
        align = (:center, :center),
        textsize = 2)
    scatter!(pos)
    fig
end

@cell "single_strings_single_positions" begin
    scene = Scene(camera = campixel!, show_axis = false, resolution = (800, 800))

    points = [Point(x, y) .* 200 for x in 1:3 for y in 1:3]
    scatter!(scene, points, marker = :circle, markersize = 10px)

    i = 1
    for halign in (:right, :center, :left), valign in (:top, :center, :bottom)

        for rotation in (-pi/6, 0.0, pi/6)
            text!(scene, string(halign) * "/" * string(valign) *
                    " " * string(round(rad2deg(rotation), digits = 0)) * "°",
                color = (:black, 0.5),
                position = points[i],
                align = (halign, valign),
                rotation = rotation)
        end
        i += 1
    end
    scene
end


@cell "multi_strings_multi_positions" begin
    scene = Scene(camera = campixel!, show_axis = false, resolution = (800, 800))

    angles = (-pi/6, 0.0, pi/6)
    points = [Point(x, y) .* 200 for x in 1:3 for y in 1:3 for angle in angles]
    aligns = [(halign, valign) for halign in
        (:right, :center, :left) for valign in (:top, :center, :bottom) for rotation in angles]
    rotations = [rotation for _ in
        (:right, :center, :left) for _ in (:top, :center, :bottom) for rotation in angles]

    strings = [string(halign) * "/" * string(valign) *
        " " * string(round(rad2deg(rotation), digits = 0)) * "°"
            for halign in (:right, :center, :left)
            for valign in (:top, :center, :bottom)
            for rotation in angles]

    scatter!(scene, points, marker = :circle, markersize = 10px)


    text!(scene, strings, position = points, align = aligns, rotation = rotations,
        color = [(:black, alpha) for alpha in LinRange(0.3, 0.7, length(points))])

    scene
end

@cell "single_strings_single_positions_justification" begin
    scene = Scene(camera = campixel!, show_axis = false, resolution = (800, 800))

    points = [Point(x, y) .* 200 for x in 1:3 for y in 1:3]
    scatter!(scene, points, marker = :circle, markersize = 10px)

    symbols = (:left, :center, :right)

    for ((justification, halign), point) in zip(Iterators.product(symbols, symbols), points)

        t = text!(scene, "a\nshort\nparagraph",
            color = (:black, 0.5),
            position = point,
            align = (halign, :center),
            justification = justification)

        bb = boundingbox(t)
        wireframe!(scene, bb, color = (:red, 0.2))
    end

    for (p, al) in zip(points[3:3:end], (:left, :center, :right))
        text!(scene, "align :" * string(al), position = p .+ (0, 80),
            align = (:center, :baseline))
    end

    for (p, al) in zip(points[7:9], (:left, :center, :right))
        text!(scene, "justification\n:" * string(al), position = p .+ (80, 0),
            align = (:center, :top), rotation = pi/2)
    end

    scene
end

@cell "multi_boundingboxes" begin
    scene = Scene(camera = campixel!, show_axis = false, resolution = (800, 800))

    t1 = text!(scene,
        fill("makie", 4),
        position = [(200, 200) .+ 60 * Point2f(cos(a), sin(a)) for a in pi/4:pi/2:7pi/4],
        rotation = pi/4:pi/2:7pi/4,
        align = (:left, :center),
        textsize = 30,
        space = :data
    )

    wireframe!(scene, boundingbox(t1), color = (:blue, 0.3))

    t2 = text!(scene,
        fill("makie", 4),
        position = [(200, 600) .+ 60 * Point2f(cos(a), sin(a)) for a in pi/4:pi/2:7pi/4],
        rotation = pi/4:pi/2:7pi/4,
        align = (:left, :center),
        textsize = 30,
        space = :screen
    )

    wireframe!(scene, boundingbox(t2), color = (:red, 0.3))

    scene
end

@cell "single_boundingboxes" begin
    scene = Scene(camera = campixel!, show_axis = false, resolution = (800, 800))

    for a in pi/4:pi/2:7pi/4

        t = text!(scene,
            "makie",
            position = (200, 200) .+ 60 * Point2f(cos(a), sin(a)),
            rotation = a,
            align = (:left, :center),
            textsize = 30,
            space = :data
        )

        wireframe!(scene, boundingbox(t), color = (:blue, 0.3))

        t2 = text!(scene,
            "makie",
            position = (200, 600) .+ 60 * Point2f(cos(a), sin(a)),
            rotation = a,
            align = (:left, :center),
            textsize = 30,
            space = :screen
        )

        # these boundingboxes should be invisible because they only enclose the anchor
        wireframe!(scene, boundingbox(t2), color = (:red, 0.3))

    end
    scene
end

@cell "text_in_3d_axis" begin
    text(
        fill("Makie", 7),
        rotation = [i / 7 * 1.5pi for i in 1:7],
        position = [Point3f(0, 0, i/2) for i in 1:7],
        color = [cgrad(:viridis)[x] for x in LinRange(0, 1, 7)],
        align = (:left, :baseline),
        textsize = 1,
        space = :data
    )
end

@cell "empty_lines" begin
    scene = Scene(camera = campixel!, show_axis = false, resolution = (800, 800))

    t1 = text!(scene, "Line1\nLine 2\n\nLine4",
        position = (200, 400), align = (:center, :center), space = :data)

    wireframe!(scene, boundingbox(t1), color = (:red, 0.3))

    t2 = text!(scene, "\nLine 2\nLine 3\n\n\nLine6\n\n",
        position = (400, 400), align = (:center, :center), space = :data)

    wireframe!(scene, boundingbox(t2), color = (:blue, 0.3))

    scene
end


@cell "3D screenspace annotations" begin
    positions = RNG.rand(Point3f, 10)
    fig, ax, p = meshscatter(positions, color=:white)
    text!(
        fill("Annotation", 10),
        position = positions,
        align = (:center, :center),
        textsize = 20,
        space = :screen,
        overdraw=false)
    fig
end


@cell "Text offset" begin
    f = Figure(resolution = (1000, 1000))
    barplot(f[1, 1], 3:5)
    text!("bar 1", position = (1, 3), offset = (0, 10), align = (:center, :baseline))
    text!(["bar 2", "bar 3"], position = [(2, 4), (3, 5)],
        offset = [(0, -10), (0, -20)],
        align = (:center, :top), color = :white)

    scatter(f[1, 2], Point2f(0, 0))
    text!("hello", position = (0, 0), offset = (40, 0), align = (:left, :center))
    text!("hello", position = (0, 0), offset = (40, 0), align = (:left, :center),
        rotation = -pi/4)
    text!("hello", position = (0, 0), offset = (40, 0), align = (:left, :center),
        rotation = pi/4)

    scatter(f[2, 1], Point2f[(0, 0), (10, 0), (20, 10)])
    text!("ABC", space = :data, offset = (0, 0), color = (:red, 0.3), align = (:left, :baseline))
    text!("ABC", space = :data, offset = (10, 0), color = (:green, 0.3), align = (:left, :baseline))
    text!("ABC", space = :data, offset = (20, 10), color = (:blue, 0.3), align = (:left, :baseline))

    LScene(f[2, 2], scenekw = (show_axis = false,))
    scatter!(Point3f[(0, 0, 0), (2, 2, 2)])
    text!("hello", position = Point3f(1, 1, 1), offset = (10, 10))

    f
end


@cell "Log10 text" begin
    barplot([1, 10, 100], fillto = 0.1, axis = (yscale = log10,))
    text!(["bar 1", "bar 2", "bar 3"], position = [(1, 1), (2, 10), (3, 100)],
        offset = (0, -10), color = :white, align = (:center, :top))
    tightlimits!(current_axis(), Bottom())
    current_figure()
end

@cell "latex strings" begin
    f, ax , l = lines(cumsum(RNG.randn(1000)),
        axis = (
                title = L"\sum_k{x y_k}",
                xlabel = L"\lim_{x →\infty} A^j v_{(a + b)_k}^i \sqrt{23.5} x!= \sqrt{\frac{1+6}{4+a+g}}\int_{0}^{2π} \sin(x) dx",
                ylabel = L"x + y - sin(x) × tan(y) + \sqrt{2}",
            ),
        figure = (fontsize = 18,)
    )
    text!(L"\int_{0}^{2π} \sin(x) dx", position = (500, 0))
    Legend(f[1, 2], [l, l, l], [L"\sum{xy}", L"a\int_0^5x^2+2ab", L"||x-y||^2"])
    f
end

@cell "latex simple" begin
    s = Scene(camera = campixel!)
    t = text!(s,
        L"\sqrt{2}",
        position = (50, 50),
        rotation = pi/2,
        show_axis = false,
        space = :data)
    s
end

@cell "latex bb" begin
    s = Scene(camera = campixel!)
    t = text!(s,
        L"\int_0^5x^2+2ab",
        position = Point2f(50, 50),
        rotation = 0.0,
        show_axis = false,
        space = :data)
    wireframe!(s, boundingbox(t))
    s
end

@cell "latex updates" begin
    s = Scene(camera = campixel!)
    st = Stepper(s)
    textnode = Node([L"\int_0^5x^2+2ab", L"\int_0^5x^2+2ab"])
    posnode = Node(Point2f[(50, 50), (100, 100)])

    t = text!(s,
        textnode,
        position = posnode,
        rotation = 0.0,
        show_axis = false,
        space = :data)

    Makie.step!(st)
    ## change lengths
    textnode.val = push!(textnode[], L"\int_0^5x^2+2ab")
    posnode[] = push!(posnode[], Point2f(150, 150))
    Makie.step!(st)
    st
end

@cell "update annotation style" begin
    s = Scene(camera = campixel!)
    st = Stepper(s)
    textposnode = Node([
        (L"\int_0^5x^2+2ab", Point2f(50, 50)),
        (L"\int_0^5x^2+2ab", Point2f(100, 100)),
    ])

    t = text!(s,
        textposnode,
        show_axis = false,
        space = :data)

    Makie.step!(st)
    ## change lengths
    textposnode[] = push!(textposnode[], (L"\int_0^5x^2+2ab", Point2f(150, 150)))
    Makie.step!(st)
    st
end

@cell "latex ticks" begin
    lines(0..25, x -> 4 * sin(x) / (cos(3x) + 4), figure = (fontsize = 25,),
        axis = (
            xticks = (0:10:20, [L"10^{-3.5}", L"10^{-4.5}", L"10^{-5.5}"]),
            yticks = ([-1, 0, 1], [L"\sum_%$i{xy}" for i in 1:3]),
            yticklabelrotation = pi/8,
            title = L"\int_0^1{x^2}",
            xlabel = L"\sum_k{x_k ⋅ y_k}",
            ylabel = L"\int_a^b{\sqrt{abx}}"
        ),
    )
end


@cell "dynamic latex ticks" begin
    lines(0..25, x -> 4 * sin(x) / (cos(3x) + 4),
        figure = (fontsize = 16,),
        axis = (xtickformat = (xs -> [L"e^{\sqrt{%$x}}+\sum" for x in xs]), ))
end
