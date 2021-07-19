using Makie: PriorityObservable, MouseButtonEvent, KeyEvent

@testset "PriorityObservable" begin
    po = PriorityObservable(0)

    first = Node(0.0)
    second = Node(0.0)
    third = Node(0.0)

    on(po, priority=1) do x
        sleep(0)
        first[] = time()
    end
    on(po, priority=0) do x
        sleep(0)
        second[] = time()
        return Consume(isodd(x))
    end
    on(po, priority=-1) do x
        sleep(0)
        third[] = time()
        return Consume(false)
    end

    x = setindex!(po, 1)
    @test x == true
    @test first[] < second[]
    @test third[] == 0.0

    x = setindex!(po, 2)
    @test x == false
    @test first[] < second[] < third[]
end


@testset "Events" begin
    @testset "Mouse and Keyboard state" begin
        events = Makie.Events()
        @test isempty(events.mousebuttonstate)
        @test isempty(events.keyboardstate)

        events.mousebutton[] = MouseButtonEvent(Mouse.left, Mouse.press)
        events.keyboardbutton[] = KeyEvent(Keyboard.a, Keyboard.press)
        @test events.mousebuttonstate == Set([Mouse.left])
        @test events.keyboardstate == Set([Keyboard.a])

        events.mousebutton[] = MouseButtonEvent(Mouse.right, Mouse.press)
        events.keyboardbutton[] = KeyEvent(Keyboard.b, Keyboard.press)
        @test events.mousebuttonstate == Set([Mouse.left, Mouse.right])
        @test events.keyboardstate == Set([Keyboard.a, Keyboard.b])

        events.mousebutton[] = MouseButtonEvent(Mouse.left, Mouse.release)
        events.keyboardbutton[] = KeyEvent(Keyboard.a, Keyboard.release)
        @test events.mousebuttonstate == Set([Mouse.right])
        @test events.keyboardstate == Set([Keyboard.b])

        events.mousebutton[] = MouseButtonEvent(Mouse.right, Mouse.release)
        events.keyboardbutton[] = KeyEvent(Keyboard.b, Keyboard.release)
        @test isempty(events.mousebuttonstate)
        @test isempty(events.keyboardstate)
    end

    # This testset is based on the results the current camera system has. If
    # cam3d! is updated this is likely to break.
    @testset "cam3d!" begin
        scene = Scene(resolution=(800, 600));
        e = events(scene)
        cam3d!(scene, fixed_axis=true, cad=false, zoom_shift_lookat=false)
        cc = cameracontrols(scene)

        # Verify initial camera state
        @test cc.lookat[]       == Vec3f(0)
        @test cc.eyeposition[]  == Vec3f(3)
        @test cc.upvector[]     == Vec3f(0, 0, 1)

        # Rotation
        # 1) In scene, in drag
        e.mouseposition[] = (400, 250)
        e.mousebutton[] = MouseButtonEvent(Mouse.left, Mouse.press)
        e.mouseposition[] = (600, 250)
        @test cc.lookat[]       ≈ Vec3f(0)
        @test cc.eyeposition[]  ≈ Vec3f(4.14532, -0.9035063, 3.0)
        @test cc.upvector[]     ≈ Vec3f(0, 0, 1)

        # 2) Outside scene, in drag
        e.mouseposition[] = (1000, 450)
        @test cc.lookat[]       ≈ Vec3f(0)
        @test cc.eyeposition[]  ≈ Vec3f(-2.8912058, -3.8524969, -1.9491522)
        @test cc.upvector[]     ≈ Vec3f(-0.5050875, -0.6730229, 0.5403024)

        # 3) not in drag
        e.mousebutton[] = MouseButtonEvent(Mouse.left, Mouse.release)
        e.mouseposition[] = (400, 250)
        @test cc.lookat[]       ≈ Vec3f(0)
        @test cc.eyeposition[]  ≈ Vec3f(-2.8912058, -3.8524969, -1.9491522)
        @test cc.upvector[]     ≈ Vec3f(-0.5050875, -0.6730229, 0.5403024)



        # Reset state so this is indepentent from the last checks
        scene = Scene(resolution=(800, 600));
        e = events(scene)
        cam3d!(scene, fixed_axis=true, cad=false, zoom_shift_lookat=false)
        cc = cameracontrols(scene)

        # Verify initial camera state
        @test cc.lookat[]       == Vec3f(0)
        @test cc.eyeposition[]  == Vec3f(3)
        @test cc.upvector[]     == Vec3f(0, 0, 1)

        # translation
        # 1) In scene, in drag
        e.mousebutton[] = MouseButtonEvent(Mouse.right, Mouse.press)
        e.mouseposition[] = (600, 250)
        @test cc.lookat[]       ≈ Vec3f(4.409082, -4.409082, -2.598076)
        @test cc.eyeposition[]  ≈ Vec3f(7.409082, -1.4090819, 0.4019239)
        @test cc.upvector[]     ≈ Vec3f(0.0, 0.0, 1.0)

        # 2) Outside scene, in drag
        e.mouseposition[] = (1000, 450)
        @test cc.lookat[]       ≈ Vec3f(7.3484697, -7.3484697, -4.676537)
        @test cc.eyeposition[]  ≈ Vec3f(10.34847, -4.3484697, -1.676537)
        @test cc.upvector[]     ≈ Vec3f(0.0, 0.0, 1.0)

        # 3) not in drag
        e.mousebutton[] = MouseButtonEvent(Mouse.right, Mouse.release)
        e.mouseposition[] = (400, 250)
        @test cc.lookat[]       ≈ Vec3f(7.3484697, -7.3484697, -4.676537)
        @test cc.eyeposition[]  ≈ Vec3f(10.34847, -4.3484697, -1.676537)
        @test cc.upvector[]     ≈ Vec3f(0.0, 0.0, 1.0)



        # Reset state
        scene = Scene(resolution=(800, 600));
        e = events(scene)
        cam3d!(scene, fixed_axis=true, cad=false, zoom_shift_lookat=false)
        cc = cameracontrols(scene)

        # Verify initial camera state
        @test cc.lookat[]       == Vec3f(0)
        @test cc.eyeposition[]  == Vec3f(3)
        @test cc.upvector[]     == Vec3f(0, 0, 1)
        @test cc.zoom_mult[]    == 1f0

        # Zoom
        e.scroll[] = (0.0, 4.0)
        @test cc.lookat[]       ≈ Vec3f(0)
        @test cc.eyeposition[]  ≈ Vec3f(3)
        @test cc.upvector[]     ≈ Vec3f(0.0, 0.0, 1.0)
        @test cc.zoom_mult[]    ≈ 0.6830134f0

        # should not work outside the scene
        e.mouseposition[] = (1000, 450)
        e.scroll[] = (0.0, 4.0)
        @test cc.lookat[]       ≈ Vec3f(0)
        @test cc.eyeposition[]  ≈ Vec3f(3)
        @test cc.upvector[]     ≈ Vec3f(0.0, 0.0, 1.0)
        @test cc.zoom_mult[]    ≈ 0.6830134f0
    end

    @testset "mouse state machine" begin
        scene = Scene(resolution=(800, 600));
        e = events(scene)
        bbox = Node(Rect2(200, 200, 400, 300))
        msm = addmouseevents!(scene, bbox, priority=typemax(Int8))
        eventlog = MouseEvent[]
        on(x -> begin push!(eventlog, x); false end, msm.obs)

        e.mouseposition[] = (0, 200)
        @test isempty(eventlog)

        # move inside
        e.mouseposition[] = (300, 200)
        @test length(eventlog) == 1
        @test eventlog[1].type == MouseEventTypes.enter
        @test eventlog[1].px == Point2f(300, 200)
        @test eventlog[1].prev_px == Point2f(0, 200)
        empty!(eventlog)

        # over
        e.mouseposition[] = (300, 300)
        @test length(eventlog) == 1
        @test eventlog[1].type == MouseEventTypes.over
        @test eventlog[1].px == Point2f(300, 300)
        @test eventlog[1].prev_px == Point2f(300, 200)
        empty!(eventlog)

        for button in (:left, :middle, :right)
            # click
            e.mousebutton[] = MouseButtonEvent(getfield(Mouse, button), Mouse.press)
            e.mousebutton[] = MouseButtonEvent(getfield(Mouse, button), Mouse.release)
            @test length(eventlog) == 3
            for (i, t) in enumerate((
                    getfield(MouseEventTypes, Symbol(button, :down)),
                    getfield(MouseEventTypes, Symbol(button, :click)),
                    getfield(MouseEventTypes, Symbol(button, :up))
                ))
                @test eventlog[i].type == t
                @test eventlog[i].px == Point2f(300, 300)
                @test eventlog[i].prev_px == Point2f(300, 300)
            end
            empty!(eventlog)

            # doubleclick
            e.mousebutton[] = MouseButtonEvent(getfield(Mouse, button), Mouse.press)
            e.mousebutton[] = MouseButtonEvent(getfield(Mouse, button), Mouse.release)
            @test length(eventlog) == 3
            for (i, t) in enumerate((
                    getfield(MouseEventTypes, Symbol(button, :down)),
                    getfield(MouseEventTypes, Symbol(button, :doubleclick)),
                    getfield(MouseEventTypes, Symbol(button, :up))
                ))
                @test eventlog[i].type == t
                @test eventlog[i].px == Point2f(300, 300)
                @test eventlog[i].prev_px == Point2f(300, 300)
            end
            empty!(eventlog)

            # triple click = click
            e.mousebutton[] = MouseButtonEvent(getfield(Mouse, button), Mouse.press)
            e.mousebutton[] = MouseButtonEvent(getfield(Mouse, button), Mouse.release)
            @test length(eventlog) == 3
            for (i, t) in enumerate((
                    getfield(MouseEventTypes, Symbol(button, :down)),
                    getfield(MouseEventTypes, Symbol(button, :click)),
                    getfield(MouseEventTypes, Symbol(button, :up))
                ))
                @test eventlog[i].type == t
                @test eventlog[i].px == Point2f(300, 300)
                @test eventlog[i].prev_px == Point2f(300, 300)
            end
            empty!(eventlog)

            # drag
            e.mousebutton[] = MouseButtonEvent(getfield(Mouse, button), Mouse.press)
            e.mouseposition[] = (500, 300)
            e.mouseposition[] = (700, 200)
            e.mousebutton[] = MouseButtonEvent(getfield(Mouse, button), Mouse.release)
            @test length(eventlog) == 6
            prev_px = Point2f[(300, 300), (300, 300), (300, 300), (500, 300), (700, 200), (700, 200)]
            px      = Point2f[(300, 300), (500, 300), (500, 300), (700, 200), (700, 200), (700, 200)]
            for (i, t) in enumerate((
                    getfield(MouseEventTypes, Symbol(button, :down)),
                    getfield(MouseEventTypes, Symbol(button, :dragstart)),
                    getfield(MouseEventTypes, Symbol(button, :drag)),
                    getfield(MouseEventTypes, Symbol(button, :drag)),
                    getfield(MouseEventTypes, Symbol(button, :dragstop)),
                    getfield(MouseEventTypes, :out),
                    # TODO this is kinda missing an "up outside"
                ))
                @test eventlog[i].type == t
                @test eventlog[i].px == px[i]
                @test eventlog[i].prev_px == prev_px[i]
            end
            e.mouseposition[] = (300, 300)
            empty!(eventlog)
        end

        # TODO: This should probably be:
        # left down > right down > right click > right up > left up
        e.mousebutton[] = MouseButtonEvent(Mouse.left, Mouse.press)
        e.mousebutton[] = MouseButtonEvent(Mouse.right, Mouse.press)
        e.mousebutton[] = MouseButtonEvent(Mouse.right, Mouse.release)
        e.mousebutton[] = MouseButtonEvent(Mouse.left, Mouse.release)
        @test length(eventlog) == 3
        @test eventlog[1].type == MouseEventTypes.leftdown
        @test eventlog[2].type == MouseEventTypes.leftclick
        @test eventlog[3].type == MouseEventTypes.leftup
        empty!(eventlog)

        # double left up? :(
        e.mousebutton[] = MouseButtonEvent(Mouse.left, Mouse.press)
        e.mousebutton[] = MouseButtonEvent(Mouse.right, Mouse.press)
        e.mousebutton[] = MouseButtonEvent(Mouse.left, Mouse.release)
        e.mousebutton[] = MouseButtonEvent(Mouse.right, Mouse.release)
        @test length(eventlog) == 4
        @test eventlog[1].type == MouseEventTypes.leftdown
        @test eventlog[2].type == MouseEventTypes.leftdoubleclick
        @test eventlog[3].type == MouseEventTypes.leftup
        @test eventlog[4].type == MouseEventTypes.leftup
        empty!(eventlog)

        # This should probably be a leftdragstop on right down
        e.mouseposition[] = (300, 300)
        empty!(eventlog)
        e.mousebutton[] = MouseButtonEvent(Mouse.left, Mouse.press)
        e.mouseposition[] = (350, 350)
        e.mousebutton[] = MouseButtonEvent(Mouse.right, Mouse.press)
        e.mouseposition[] = (350, 400)
        e.mousebutton[] = MouseButtonEvent(Mouse.right, Mouse.release)
        e.mouseposition[] = (400, 400)
        e.mousebutton[] = MouseButtonEvent(Mouse.left, Mouse.release)
        @test length(eventlog) == 7
        @test eventlog[1].type == MouseEventTypes.leftdown
        @test eventlog[2].type == MouseEventTypes.leftdragstart
        @test eventlog[3].type == MouseEventTypes.leftdrag
        @test eventlog[4].type == MouseEventTypes.leftdrag
        @test eventlog[5].type == MouseEventTypes.over
        @test eventlog[6].type == MouseEventTypes.leftdragstop
        @test eventlog[7].type == MouseEventTypes.leftup
        @test eventlog[1].px == Point2f(300, 300)
        @test eventlog[2].px == Point2f(350, 350)
        @test eventlog[3].px == Point2f(350, 350)
        @test eventlog[4].px == Point2f(350, 400)
        @test eventlog[5].px == Point2f(400, 400)
        @test eventlog[6].px == Point2f(400, 400)
        @test eventlog[7].px == Point2f(400, 400)
        empty!(eventlog)
    end
end
