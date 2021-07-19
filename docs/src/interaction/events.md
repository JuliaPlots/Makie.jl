# Events

Interactive backends such as `GLMakie` and `WGLMakie` pass events to an `Events`
struct in the currently active scene. There they trigger a number of slightly
modified observables of type `PriorityObservable`. By reacting to those one can
build up custom interactions.

## PriorityObservables

Much like the name suggests a `PriorityObservable` adds a priority to its
listeners. Furthermore it allows for each listener to stop execution of lower
priority listeners by returning `Consume(true)` or simply `Consume()`. Every
other return value will be handled as `Consume(false)` meaning that the 
listener does not block other listeners.

To understand how a `PriorityObserable` works you may try this example:

```julia
using Makie: PriorityObservable

po = PriorityObservable(0)

on(po, priority = -1) do x
    println("Low priority: $x")
end
po[] = 1

on(po, priority = 0) do x
    println("Medium blocking priority: $x")
    return Consume()
end
po[] = 2

on(po, priority = 1) do x
    println("High Priority: $x")
    return Consume(false)
end
po[] = 3
```

With only the first listener connected you should see `Low priority: 1` getting
printed. With the second you should only see a reaction from the medium priority
listener, as it blocks execution of the lower priority by returning `Consume()`. 
With all three connected you should see two prints, first the high priority, 
than the medium priority.

## The Events struct

Events from the backend are stored in `PriorityObservables` within the `Events`
struct. You can access it from any scene via `events(scene)` and via
`events(figure.scene)` or `events(axis.scene)` from a figure or axis. The struct
contains the following fields you may react to.

- `window_area::PriorityObservable{Rect2i}`: Contains the current size of the window in pixels.
- `window_dpi::PriorityObservable{Float64}`: Contains the DPI of the window.
- `window_open::PriorityObservable{Bool}`: Contains `true` as long as the window is open.
- `hasfocus::PriorityObservable{Bool}`: Contains `true` if the window is focused (in the foreground).
- `entered_window::PriorityObservable{Bool}`: Contains true if the mouse is within the window (regarless of whether it is focused), i.e. when it is hovered.
- `mousebutton::PriorityObservable{MouseButtonEvent}`: Contains the most recent `MouseButtonEvent` which holds the relevant `button::Mouse.Button` and `action::Mouse.Action`.
- `mousebuttonstate::Set{Mouse.Button}`: Contains all currently pressed mouse buttons.
- `mouseposition::PriorityObservable{NTuple{2, Float64}}`: Contains the most recent cursor position in pixel units relative to the root scene/window.
- `scroll::PriorityObservable{NTuple{2, Float64}}`: Contains the most recent scroll offset.
- `keyboardbutton::PriorityObservable{KeyEvent}`: Contains the most recent `KeyEvent` which holds the relevant `key::Keyboard.Button` and `action::Keyboard.Action`.
- `keyboardstate::PriorityObservable{Keyboard.Button}`: Contains all currently pressed keys.
- `unicode_input::PriorityObservable{Char}`: Contains the most recently typed character.
- `dropped_files::PriorityObservable{Vector{String}}`: Contains a list of filepaths to a collection files dragged into the window.

## Mouse Interaction

There are three mouse events one can react to:

- `events.mousebutton` which holds a `MouseButtonEvent` with relevant `button` and `action`
- `events.mouseposition` which holds the current cursor position relative to the window as `NTuple{2, Float64}` in pixel
- `events.scroll` which holds an `NTuple{2, Float64}` of the last scroll change

For example, we can react to a left click with:

```julia
on(events(fig).mousebutton, priority = 0) do event
    if event.button == Mouse.left
        if event.action == Mouse.press
            # do something
        else
            # do something else when the mouse button is released
        end
    end
    # Do not consume the event
    return Consume(false)
end
```

There are also a bunch of convenience function for mouse interactions:

- `hovered_scene()` returns the currently hovered scene.
- `mouseposition_px([scene])` returns the cursor position in pixel units relative to the given or currently hovered scene.
- `mouseposition([scene])` returns the cursor position of the given or hovered scene in data coordinates.
- `mouseover(scene, plots...)` returns true if the mouse is over any of the given plots.
- `mouse_selection(scene[, range])` returns the plot under your cursor.
- `onpick(f, scene, plots...[; range=1])` allows you to define a callback `f` when one of the given plots is hovered (or the closest within range of the cursor).
- `pick(scene, position[, range])` returns the plot under the given position (or the closest within range)
- `Makie.pick_closest(scene, position, range)` returns all plots within range, sorted by distance to the given position.

## Keyboard Interaction

You can use `events.keyboardbutton` to react to a `KeyEvent` and
`events.unicode_input` to react to specific characters being typed.

For example we may react to specific keys being pressed or held with

```julia
on(events(fig).keyboardbutton) do event
    if event.action in (Keyboard.press, Keyboard.repeat)
        event.key == Keyboard.left   && move_left()
        event.key == Keyboard.up     && move_up()
        event.key == Keyboard.right  && move_right()
        event.key == Keyboard.down   && move_down()
    end
    # Let the event reach other listeners
    return Consume(false)
end
```

## Interactive Widgets

Makie has a couple of useful interactive widgets like sliders, buttons and menus, which you can read about in the [Layoutables](@ref) section.

## Recording Animations with Interactions

You can record a `Scene` while you're interacting with it.
Just use the [`record`](@ref) function (also see the [Animations](@ref) page) and allow interaction by `sleep`ing in the loop.

In this example, we sample from the Scene `scene` for 10 seconds, at a rate of 10 frames per second.

```julia
fps = 10
record(scene, "test.mp4"; framerate = fps) do io
    for i = 1:100
        sleep(1/fps)
        recordframe!(io)
    end
end
```
