using Makie: MouseButtonEvent, KeyEvent

macro print_error(expr)
    return quote
        try
            $(esc(expr))
        catch e
            println(stderr, "Error in callback:")
            # TODO is it fine to call catch_backtrace inside C call?
            Base.showerror(stderr, e, Base.catch_backtrace())
            println(stderr)
        end
    end
end

"""
Returns a signal, which is true as long as the window is open.
returns `Node{Bool}`
[GLFW Docs](http://www.glfw.org/docs/latest/group__window.html#gaade9264e79fae52bdb78e2df11ee8d6a)
"""
window_open(scene::Scene, screen) = window_open(scene, to_native(screen))
function window_open(scene::Scene, window::GLFW.Window)
    event = scene.events.window_open
    function windowclose(win)
        @print_error begin
            event[] = false
        end
    end
    disconnect!(window, window_open)
    event[] = isopen(window)
    GLFW.SetWindowCloseCallback(window, windowclose)
end

function disconnect!(window::GLFW.Window, ::typeof(window_open))
    GLFW.SetWindowCloseCallback(window, nothing)
end

function window_position(window::GLFW.Window)
    xy = GLFW.GetWindowPos(window)
    (xy.x, xy.y)
end

function window_area(scene::Scene, screen::Screen)
    window = to_native(screen)
    event = scene.events.window_area
    dpievent = scene.events.window_dpi

    disconnect!(window, window_area)
    monitor = GLFW.GetPrimaryMonitor()
    props = MonitorProperties(monitor)
    dpievent[] = minimum(props.dpi)

    on(screen.render_tick) do _
        rect = event[]
        # TODO put back window position, but right now it makes more trouble than it helps#
        # x, y = GLFW.GetWindowPos(window)
        # if minimum(rect) != Vec(x, y)
        #     event[] = Recti(x, y, framebuffer_size(window))
        # end
        w, h = GLFW.GetFramebufferSize(window)
        if Vec(w, h) != widths(rect)
            monitor = GLFW.GetPrimaryMonitor()
            props = MonitorProperties(monitor)
            # dpi of a monitor should be the same in x y direction.
            # if not, minimum seems to be a fair default
            dpievent[] = minimum(props.dpi)
            event[] = Recti(minimum(rect), w, h)
        end
    end
    return
end

function disconnect!(window::GLFW.Window, ::typeof(window_area))
    GLFW.SetWindowPosCallback(window, nothing)
    GLFW.SetFramebufferSizeCallback(window, nothing)
end


"""
Registers a callback for the mouse buttons + modifiers
returns `Node{NTuple{4, Int}}`
[GLFW Docs](http://www.glfw.org/docs/latest/group__input.html#ga1e008c7a8751cea648c8f42cc91104cf)
"""
mouse_buttons(scene::Scene, screen) = mouse_buttons(scene, to_native(screen))
function mouse_buttons(scene::Scene, window::GLFW.Window)
    event = scene.events.mousebutton
    function mousebuttons(window, button, action, mods)
        @print_error begin
            event[] = MouseButtonEvent(Mouse.Button(Int(button)), Mouse.Action(Int(action)))
        end
    end
    disconnect!(window, mouse_buttons)
    GLFW.SetMouseButtonCallback(window, mousebuttons)
end
function disconnect!(window::GLFW.Window, ::typeof(mouse_buttons))
    GLFW.SetMouseButtonCallback(window, nothing)
end
keyboard_buttons(scene::Scene, screen) = keyboard_buttons(scene, to_native(screen))
function keyboard_buttons(scene::Scene, window::GLFW.Window)
    event = scene.events.keyboardbutton
    function keyoardbuttons(window, button, scancode::Cint, action, mods::Cint)
        @print_error begin
            event[] = KeyEvent(Keyboard.Button(Int(button)), Keyboard.Action(Int(action)))
        end
    end
    disconnect!(window, keyboard_buttons)
    GLFW.SetKeyCallback(window, keyoardbuttons)
end

function disconnect!(window::GLFW.Window, ::typeof(keyboard_buttons))
    GLFW.SetKeyCallback(window, nothing)
end

"""
Registers a callback for drag and drop of files.
returns `Node{Vector{String}}`, which are absolute file paths
[GLFW Docs](http://www.glfw.org/docs/latest/group__input.html#gacc95e259ad21d4f666faa6280d4018fd)
"""
dropped_files(scene::Scene, screen) = dropped_files(scene, to_native(screen))
function dropped_files(scene::Scene, window::GLFW.Window)
    event = scene.events.dropped_files
    function droppedfiles(window, files)
        @print_error begin
            event[] = String.(files)
        end
    end
    disconnect!(window, dropped_files)
    event[] = String[]
    GLFW.SetDropCallback(window, droppedfiles)
end
function disconnect!(window::GLFW.Window, ::typeof(dropped_files))
    GLFW.SetDropCallback(window, nothing)
end

"""
Registers a callback for keyboard unicode input.
returns an `Node{Vector{Char}}`,
containing the pressed char. Is empty, if no key is pressed.
[GLFW Docs](http://www.glfw.org/docs/latest/group__input.html#ga1e008c7a8751cea648c8f42cc91104cf)
"""
unicode_input(scene::Scene, screen) = unicode_input(scene, to_native(screen))
function unicode_input(scene::Scene, window::GLFW.Window)
    event = scene.events.unicode_input
    function unicodeinput(window, c::Char)
        @print_error begin
            event[] = c
        end
    end
    disconnect!(window, unicode_input)
    # x = Char[]; sizehint!(x, 1)
    # event[] = x
    GLFW.SetCharCallback(window, unicodeinput)
end
function disconnect!(window::GLFW.Window, ::typeof(unicode_input))
    GLFW.SetCharCallback(window, nothing)
end

# TODO memoise? Or to bug ridden for the small performance gain?
function retina_scaling_factor(w, fb)
    (w[1] == 0 || w[2] == 0) && return (1.0, 1.0)
    fb ./ w
end

# TODO both of these methods are slow!
# ~90µs, ~80µs
# This is too slow for events that may happen 100x per frame
function framebuffer_size(window::GLFW.Window)
    wh = GLFW.GetFramebufferSize(window)
    (wh.width, wh.height)
end
function window_size(window::GLFW.Window)
    wh = GLFW.GetWindowSize(window)
    (wh.width, wh.height)
end
function retina_scaling_factor(window::GLFW.Window)
    w, fb = window_size(window), framebuffer_size(window)
    retina_scaling_factor(w, fb)
end

function correct_mouse(window::GLFW.Window, w, h)
    ws, fb = window_size(window), framebuffer_size(window)
    s = retina_scaling_factor(ws, fb)
    (w * s[1], fb[2] - (h * s[2]))
end

"""
Registers a callback for the mouse cursor position.
returns an `Node{Vec{2, Float64}}`,
which is not in scene coordinates, with the upper left window corner being 0
[GLFW Docs](http://www.glfw.org/docs/latest/group__input.html#ga1e008c7a8751cea648c8f42cc91104cf)
"""
function mouse_position(scene::Scene, screen::Screen)
    window = to_native(screen)
    e = events(scene)
    on(screen.render_tick) do _
        !e.hasfocus[] && return
        x, y = GLFW.GetCursorPos(window)
        pos = correct_mouse(window, x, y)
        if pos != e.mouseposition[]
            @print_error e.mouseposition[] = pos
            # notify!(e.mouseposition)
        end
        return
    end

    # function cursorposition(window, w::Cdouble, h::Cdouble)
    #     @print_error begin
    #         pos = correct_mouse(window, w, h)
    #         @timeit "triggerless mouseposition" begin
    #             e.mouseposition.val = pos
    #         end
    #         return
    #     end
    # end
    # disconnect!(window, mouse_position)
    # GLFW.SetCursorPosCallback(window, cursorposition)

    return
end
function disconnect!(window::GLFW.Window, ::typeof(mouse_position))
    GLFW.SetCursorPosCallback(window, nothing)
    nothing
end

"""
Registers a callback for the mouse scroll.
returns an `Node{Vec{2, Float64}}`,
which is an x and y offset.
[GLFW Docs](http://www.glfw.org/docs/latest/group__input.html#gacc95e259ad21d4f666faa6280d4018fd)
"""
scroll(scene::Scene, screen) = scroll(scene, to_native(screen))
function scroll(scene::Scene, window::GLFW.Window)
    event = scene.events.scroll
    function scrollcb(window, w::Cdouble, h::Cdouble)
        @print_error begin
            event[] = (w, h)
        end
    end
    disconnect!(window, scroll)
    GLFW.SetScrollCallback(window, scrollcb)
end
function disconnect!(window::GLFW.Window, ::typeof(scroll))
    GLFW.SetScrollCallback(window, nothing)
end

"""
Registers a callback for the focus of a window.
returns an `Node{Bool}`,
which is true whenever the window has focus.
[GLFW Docs](http://www.glfw.org/docs/latest/group__window.html#ga6b5f973531ea91663ad707ba4f2ac104)
"""
hasfocus(scene::Scene, screen) = hasfocus(scene, to_native(screen))
function hasfocus(scene::Scene, window::GLFW.Window)
    event = scene.events.hasfocus
    function hasfocuscb(window, focus::Bool)
        @print_error begin
            event[] = focus
        end
    end
    disconnect!(window, hasfocus)
    GLFW.SetWindowFocusCallback(window, hasfocuscb)
    event[] = GLFW.GetWindowAttrib(window, GLFW.FOCUSED)
    nothing
end
function disconnect!(window::GLFW.Window, ::typeof(hasfocus))
    GLFW.SetWindowFocusCallback(window, nothing)
end

"""
Registers a callback for if the mouse has entered the window.
returns an `Node{Bool}`,
which is true whenever the cursor enters the window.
[GLFW Docs](http://www.glfw.org/docs/latest/group__input.html#ga762d898d9b0241d7e3e3b767c6cf318f)
"""
entered_window(scene::Scene, screen) = entered_window(scene, to_native(screen))
function entered_window(scene::Scene, window::GLFW.Window)
    event = scene.events.entered_window
    function enteredwindowcb(window, entered::Bool)
        @print_error begin
            event[] = entered
        end
    end
    disconnect!(window, entered_window)
    GLFW.SetCursorEnterCallback(window, enteredwindowcb)
end

function disconnect!(window::GLFW.Window, ::typeof(entered_window))
    GLFW.SetCursorEnterCallback(window, nothing)
end
