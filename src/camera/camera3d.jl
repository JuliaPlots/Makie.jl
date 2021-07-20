struct Camera3D <: AbstractCamera
    eyeposition::Node{Vec3f0}
    lookat::Node{Vec3f0}
    upvector::Node{Vec3f0}

    zoom_mult::Node{Float32}
    fov::Node{Float32} # WGLMakie compat
    near::Node{Float32}
    far::Node{Float32}
    pulser::Node{Float64}

    attributes::Attributes
end

"""
    Camera3D(scene[; attributes...])

Creates a 3d camera with a lot of controls.

The 3D camera is (or can be) unrestricted in terms of rotations and translations. Both `cam3d!(scene)` and `cam3d_cad!(scene)` create this camera type. Unlike the 2D camera, settings and controls are stored in the `cam.attributes` field rather than in the struct directly, but can still be passed as keyword arguments. The general camera settings include

- `fov = 45f0` sets the "neutral" field of view, i.e. the fov corresponding to no zoom. This is irrelevant if the camera uses an orthographic projection.
- `near = automatic` sets the value of the near clip. By default this will be chosen based on the scenes bounding box. The final value is in `cam.near`.
- `far = automatic` sets the value of the far clip. By default this will be chosen based on the scenes bounding box. The final value is in `cam.far`.
- `rotation_center = :lookat` sets the default center for camera rotations. Currently allows `:lookat` or `:eyeposition`.
- `projectiontype = Perspective` sets the type of the projection. Can be `Orthographic` or `Perspective`.
- `fixed_axis = false`: If true panning uses the (world/plot) z-axis instead of the camera up direction.
- `zoom_shift_lookat = true`: If true attempts to keep data under the cursor in view when zooming.
- `cad = false`: If true rotates the view around `lookat` when zooming off-center.

The camera view follows from the position of the camera `eyeposition`, the point which the camera focuses `lookat` and the up direction of the camera `upvector`. These can be accessed as `cam.eyeposition` etc and adjusted via `update_cam!(scene, cameracontrols(scene), eyeposition, lookat[, upvector = Vec3f0(0, 0, 1)])`. They can also be passed as keyword arguments when the camera is constructed.

The camera can be controlled by keyboard and mouse. The keyboard has the following available attributes

- `up_key   = Keyboard.left_shift` sets the key for translations towards the top of the screen.
- `down_key = Keyboard.left_control` sets the key for translations towards the bottom of the screen.
- `left_key  = Keyboard.a` sets the key for translations towards the left of the screen.
- `right_key = Keyboard.d` sets the key for translations towards the right of the screen.
- `forward_key  = Keyboard.w` sets the key for translations into the screen.
- `backward_key = Keyboard.s` sets the key for translations out of the screen.

- `zoom_in_key   = Keyboard.i` sets the key for zooming into the scene (enlarge, via fov).
- `zoom_out_key  = Keyboard.k` sets the key for zooming out of the scene (shrink, via fov).
- `stretch_view_key  = Keyboard.page_up` sets the key for moving `eyepostion` away from `lookat`.
- `contract_view_key = Keyboard.page_down` sets the key for moving `eyeposition` towards `lookat`.

- `pan_left_key  = Keyboard.j` sets the key for rotations around the screens vertical axis.
- `pan_right_key = Keyboard.l` sets the key for rotations around the screens vertical axis.
- `tilt_up_key   = Keyboard.r` sets the key for rotations around the screens horizontal axis.
- `tilt_down_key = Keyboard.f` sets the key for rotations around the screens horizontal axis.
- `roll_clockwise_key        = Keyboard.e` sets the key for rotations of the screen.
- `roll_counterclockwise_key = Keyboard.q` sets the key for rotations of the screen.

- `keyboard_rotationspeed = 1f0` sets the speed of keyboard based rotations.
- `keyboard_translationspeed = 0.5f0` sets the speed of keyboard based translations.
- `keyboard_zoomspeed = 1f0` sets the speed of keyboard based zooms.
- `update_rate = 1/30` sets the rate at which keyboard based camera updates are evaluated.

and mouse interactions are controlled by

- `translation_button   = Mouse.right` sets the mouse button for drag-translations. (up/down/left/right)
- `translation_modifier = nothing` sets additional keys that need to be held for mouse translations.
- `rotation_button    = Mouse.left` sets the mouse button for drag-rotations. (pan, tilt)
- `rotation_modifier  = nothing` sets additional keys that need to be held for mouse rotations.

- `mouse_rotationspeed = 1f0` sets the speed of mouse rotations.
- `mouse_translationspeed = 0.5f0` sets the speed of mouse translations.
- `mouse_zoomspeed = 1f0` sets the speed of mouse zooming (mousewheel).
- `circular_rotation = (true, true, true)` enables circular rotations for (fixed x, fixed y, fixed z) rotation axis. (This means drawing a circle with your mouse around the center of the scene will result in a continuous rotation.)

There are also a few generally applicable controls:

- `fix_x_key = Keyboard.x` sets the key for fixing translations and rotations to the (world/plot) x-axis.
- `fix_y_key = Keyboard.y` sets the key for fixing translations and rotations to the (world/plot) y-axis.
- `fix_z_key = Keyboard.z` sets the key for fixing translations and rotations to the (world/plot) z-axis.
- `reset = Keyboard.home` sets the key for fully resetting the camera. This equivalent to setting `lookat = Vec3f0(0)`, `upvector = Vec3f0(0, 0, 1)`, `eyeposition = Vec3f0(3)` and then calling `center!(scene)`.

You can also make adjustments to the camera position, rotation and zoom by calling relevant functions:

- `translate_cam!(scene, v)` will translate the camera by the given world/plot space vector `v`.
- `rotate_cam!(scene, angles)` will rotate the camera around its axes with the corresponding angles. The first angle will rotate around the cameras "right" that is the screens horizontal axis, the second around the up vector/vertical axis or `Vec3f0(0, 0, +-1)` if `fixed_axis = true`, and the third will rotate around the view direction i.e. the axis out of the screen. The rotation respects the the current `rotation_center` of the camera.
- `zoom!(scene, zoom_step)` will change the zoom level of the scene without translating or rotating the scene. `zoom_step` applies multiplicatively to `cam.zoom_mult` which is used as a multiplier to the fov (perspective projection) or width and height (orthographic projection).
"""
function Camera3D(scene; kwargs...)
    attr = merged_get!(:cam3d, scene, Attributes(kwargs)) do
        Attributes(
            # Keyboard controls
            # Translations
            up_key        = Keyboard.left_shift,
            down_key      = Keyboard.left_control,
            left_key      = Keyboard.a,
            right_key     = Keyboard.d,
            forward_key   = Keyboard.w,
            backward_key  = Keyboard.s,
            # Zooms
            zoom_in_key   = Keyboard.i,
            zoom_out_key  = Keyboard.k,
            stretch_view_key  = Keyboard.page_up,
            contract_view_key = Keyboard.page_down,
            # Rotations
            pan_left_key  = Keyboard.j,
            pan_right_key = Keyboard.l,
            tilt_up_key   = Keyboard.r,
            tilt_down_key = Keyboard.f,
            roll_clockwise_key        = Keyboard.e,
            roll_counterclockwise_key = Keyboard.q,
            # Mouse controls
            translation_button   = Mouse.right,
            translation_modifier = nothing,
            rotation_button    = Mouse.left,
            rotation_modifier  = nothing,
            # Shared controls
            fix_x_key = Keyboard.x,
            fix_y_key = Keyboard.y,
            fix_z_key = Keyboard.z,
            reset = Keyboard.home,
            # Settings
            keyboard_rotationspeed = 1f0,
            keyboard_translationspeed = 0.5f0,
            keyboard_zoomspeed = 1f0,
            mouse_rotationspeed = 1f0,
            mouse_translationspeed = 0.2f0,
            mouse_zoomspeed = 1f0,
            circular_rotation = (true, true, true),
            fov = 45f0, # base fov
            near = automatic,
            far = automatic,
            rotation_center = :lookat,
            update_rate = 1/30,
            projectiontype = Perspective,
            fixed_axis = true,
            zoom_shift_lookat = false, # doesn't really work with fov
            cad = false
        )
    end

    cam = Camera3D(
        pop!(attr, :eyeposition, Vec3f0(3)),
        pop!(attr, :lookat,      Vec3f0(0)),
        pop!(attr, :upvector,    Vec3f0(0, 0, 1)),

        Node(1f0),
        Node(attr[:fov][]),
        Node(attr[:near][] === automatic ? 0.1f0 : attr[:near][]),
        Node(attr[:far][]  === automatic ? 100f0 : attr[:far][]),
        Node(-1.0),

        attr
    )

    disconnect!(camera(scene))

    # Keyboard controls
    # ticks every so often to get consistent position updates.
    on(cam.pulser) do prev_time
        current_time = time()
        active = on_pulse(scene, cam, Float32(current_time - prev_time))
        @async if active
            sleep(attr.update_rate[])
            cam.pulser[] = current_time
        else
            cam.pulser.val = -1.0
        end
    end

    keynames = (
        :up_key, :down_key, :left_key, :right_key, :forward_key, :backward_key,
        :zoom_in_key, :zoom_out_key, :stretch_view_key, :contract_view_key,
        :pan_left_key, :pan_right_key, :tilt_up_key, :tilt_down_key,
        :roll_clockwise_key, :roll_counterclockwise_key
    )

    # Start ticking if relevant keys are pressed
    on(camera(scene), events(scene).keyboardbutton) do event
        if event.action == Keyboard.press && cam.pulser[] == -1.0 &&
            any(key -> ispressed(scene, attr[key][]), keynames)

            cam.pulser[] = time()
            return Consume(true)
        end
        return Consume(false)
    end

    # Mouse controls
    add_translation!(scene, cam)
    add_rotation!(scene, cam)

    # add camera controls to scene
    cameracontrols!(scene, cam)

    # Trigger updates on scene resize and settings change
    on(camera(scene), scene.px_area, attr[:fov], attr[:projectiontype]) do _, _, _
        update_cam!(scene, cam)
    end
    on(camera(scene), attr[:near], attr[:far]) do near, far
        near === automatic || (cam.near[] = near)
        far  === automatic || (cam.far[] = far)
        update_cam!(scene, cam)
    end

    # reset
    on(camera(scene), events(scene).keyboardbutton) do event
        if event.key == attr[:reset][] && event.action == Keyboard.release
            # center keeps the rotation of the camera so we reset that here
            # might make sense to keep user set lookat, upvector, eyeposition
            # around somewhere for this?
            cam.lookat[] = Vec3f0(0)
            cam.upvector[] = Vec3f0(0,0,1)
            cam.eyeposition[] = Vec3f0(3)
            center!(scene)
            return Consume(true)
        end
        return Consume(false)
    end

    # TODO remove this?
    # center!(scene)

    cam
end

# These imitate the old camera
function cam3d!(scene; zoom_shift_lookat = true, fixed_axis = true, kwargs...)
    Camera3D(scene, zoom_shift_lookat = zoom_shift_lookat, fixed_axis = fixed_axis; kwargs...)
end
function cam3d_cad!(scene; cad = true, zoom_shift_lookat = false, fixed_axis = false, kwargs...)
    Camera3D(scene, cad = cad, zoom_shift_lookat = zoom_shift_lookat, fixed_axis = fixed_axis; kwargs...)
end


function add_translation!(scene, cam::Camera3D)
    translationspeed = cam.attributes[:mouse_translationspeed]
    zoomspeed = cam.attributes[:mouse_zoomspeed]
    shift_lookat = cam.attributes[:zoom_shift_lookat]
    cad = cam.attributes[:cad]
    button = cam.attributes[:translation_button]
    mod = cam.attributes[:translation_modifier]

    last_mousepos = RefValue(Vec2f0(0, 0))
    dragging = RefValue(false)

    # drag start/stop
    on(camera(scene), scene.events.mousebutton) do event
        if event.button == button[]
            if event.action == Mouse.press && is_mouseinside(scene) && ispressed(scene, mod[])
                last_mousepos[] = mouseposition_px(scene)
                dragging[] = true
                return Consume(true)
            elseif event.action == Mouse.release && dragging[]
                mousepos = mouseposition_px(scene)
                dragging[] = false
                diff = (last_mousepos[] - mousepos) * 0.01f0 * translationspeed[]
                last_mousepos[] = mousepos
                viewdir = cam.lookat[] - cam.eyeposition[]
                translate_cam!(scene, cam, cam.zoom_mult[] * norm(viewdir) * Vec3f0(diff[1], diff[2], 0f0))
                update_cam!(scene, cam)
                return Consume(true)
            end
        end
        return Consume(false)
    end

    # in drag
    on(camera(scene), scene.events.mouseposition) do mp
        if dragging[] && ispressed(scene, button[]) && ispressed(scene, mod[])
            mousepos = screen_relative(scene, mp)
            diff = (last_mousepos[] .- mousepos) * 0.01f0 * translationspeed[]
            last_mousepos[] = mousepos
            viewdir = cam.lookat[] - cam.eyeposition[]
            translate_cam!(scene, cam, cam.zoom_mult[] * norm(viewdir) * Vec3f0(diff[1], diff[2], 0f0))
            update_cam!(scene, cam)
            return Consume(true)
        end
        return Consume(false)
    end

    on(camera(scene), scene.events.scroll) do scroll
        if is_mouseinside(scene) && ispressed(scene, mod[])
            cam_res = Vec2f0(widths(scene.px_area[]))
            zoom_step = (1f0 + 0.1f0 * zoomspeed[]) ^ -scroll[2]
            zoom!(scene, cam, zoom_step, shift_lookat[], cad[])
            update_cam!(scene, cam)
            return Consume(true)
        end
        return Consume(false)
    end
end

function add_rotation!(scene, cam::Camera3D)
    rotationspeed = cam.attributes[:mouse_rotationspeed]
    button = cam.attributes[:rotation_button]
    mod = cam.attributes[:rotation_modifier]
    last_mousepos = RefValue(Vec2f0(0, 0))
    dragging = RefValue(false)
    e = events(scene)

    # drag start/stop
    on(camera(scene), e.mousebutton) do event
        if event.button == button[]
            if event.action == Mouse.press && is_mouseinside(scene) && ispressed(scene, mod[])
                last_mousepos[] = mouseposition_px(scene)
                dragging[] = true
                return Consume(true)
            elseif event.action == Mouse.release && dragging[]
                mousepos = mouseposition_px(scene)
                dragging[] = false
                rot_scaling = rotationspeed[] * (e.window_dpi[] * 0.005)
                mp = (last_mousepos[] - mousepos) * 0.01f0 * rot_scaling
                last_mousepos[] = mousepos
                rotate_cam!(scene, cam, Vec3f0(-mp[2], mp[1], 0f0), true)
                update_cam!(scene, cam)
                return Consume(true)
            end
        end
        return Consume(false)
    end

    # in drag
    on(camera(scene), e.mouseposition) do mp
        if dragging[] && ispressed(scene, mod[])
            mousepos = screen_relative(scene, mp)
            rot_scaling = rotationspeed[] * (e.window_dpi[] * 0.005)
            mp = (last_mousepos[] .- mousepos) * 0.01f0 * rot_scaling
            last_mousepos[] = mousepos
            rotate_cam!(scene, cam, Vec3f0(-mp[2], mp[1], 0f0), true)
            update_cam!(scene, cam)
            return Consume(true)
        end
        return Consume(false)
    end
end


function on_pulse(scene, cam, timestep)
    attr = cam.attributes

    # translation
    right = ispressed(scene, attr[:right_key][])
    left = ispressed(scene, attr[:left_key][])
    up = ispressed(scene, attr[:up_key][])
    down = ispressed(scene, attr[:down_key][])
    backward = ispressed(scene, attr[:backward_key][])
    forward = ispressed(scene, attr[:forward_key][])
    translating = right || left || up || down || backward || forward

    if translating
        # translation in camera space x/y/z direction
        translation = attr[:keyboard_translationspeed][] * timestep *
            Vec3f0(right - left, up - down, backward - forward)
        viewdir = cam.lookat[] - cam.eyeposition[]
        translate_cam!(scene, cam, cam.zoom_mult[] * norm(viewdir) * translation)
    end

    # rotation
    up = ispressed(scene, attr[:tilt_up_key][])
    down = ispressed(scene, attr[:tilt_down_key][])
    left = ispressed(scene, attr[:pan_left_key][])
    right = ispressed(scene, attr[:pan_right_key][])
    counterclockwise = ispressed(scene, attr[:roll_counterclockwise_key][])
    clockwise = ispressed(scene, attr[:roll_clockwise_key][])
    rotating = up || down || left || right || counterclockwise || clockwise

    if rotating
        # rotations around camera space x/y/z axes
        angles = attr[:keyboard_rotationspeed][] * timestep *
            Vec3f0(up - down, left - right, counterclockwise - clockwise)

        rotate_cam!(scene, cam, angles)
    end

    # zoom
    zoom_out = ispressed(scene, attr[:zoom_out_key][])
    zoom_in = ispressed(scene, attr[:zoom_in_key][])
    zooming = zoom_out || zoom_in

    if zooming
        zoom_step = (1f0 + attr[:keyboard_zoomspeed][] * timestep) ^ (zoom_out - zoom_in)
        zoom!(scene, cam, zoom_step, false)
    end

    stretch = ispressed(scene, attr[:stretch_view_key][])
    contract = ispressed(scene, attr[:contract_view_key][])
    if stretch || contract
        zoom_step = (1f0 + attr[:keyboard_zoomspeed][] * timestep) ^ (stretch - contract)
        cam.eyeposition[] = cam.lookat[] + zoom_step * (cam.eyeposition[] - cam.lookat[])
    end
    zooming = zooming || stretch || contract

    # if any are active, update matrices, else stop clock
    if translating || rotating || zooming
        update_cam!(scene, cam)
        return true
    else
        return false
    end
end


translate_cam!(scene, t) = translate_cam!(scene, cameracontrols(scene), t)
function translate_cam!(scene, cam, t)
    # This uses a camera based coordinate system where
    # x expands right, y expands up and z expands towards the screen
    lookat = cam.lookat[]
    eyepos = cam.eyeposition[]
    up = cam.upvector[]         # +y
    viewdir = lookat - eyepos   # -z
    right = cross(viewdir, up)  # +x

    trans = normalize(right) * t[1] + normalize(up) * t[2] - normalize(viewdir) * t[3]

    # apply world space restrictions
    fix_x = ispressed(scene, cam.attributes[:fix_x_key][])
    fix_y = ispressed(scene, cam.attributes[:fix_y_key][])
    fix_z = ispressed(scene, cam.attributes[:fix_z_key][])
    if fix_x || fix_y || fix_z
        trans = Vec3f0(fix_x, fix_y, fix_z) .* trans
    end

    cam.eyeposition[] = eyepos + trans
    cam.lookat[] = lookat + trans
    update_cam!(scene, cam)
    return
end

rotate_cam!(scene, angles) = rotate_cam!(scene, cameracontrols(scene), angles, false)
function rotate_cam!(scene, cam::Camera3D, angles::VecTypes, from_mouse=false)
    # This applies rotations around the x/y/z axis of the camera coordinate system
    # x expands right, y expands up and z expands towards the screen
    lookat = cam.lookat[]
    eyepos = cam.eyeposition[]
    up = cam.upvector[]         # +y
    viewdir = lookat - eyepos   # -z
    right = cross(viewdir, up)  # +x

    x_axis = right
    y_axis = cam.attributes[:fixed_axis][] ? Vec3f0(0, 0, sign(up[3])) : up
    z_axis = -viewdir

    fix_x = ispressed(scene, cam.attributes[:fix_x_key][])
    fix_y = ispressed(scene, cam.attributes[:fix_y_key][])
    fix_z = ispressed(scene, cam.attributes[:fix_z_key][])
    cx, cy, cz = cam.attributes[:circular_rotation][]
    rotation = Quaternionf0(0, 0, 0, 1)
    if !xor(fix_x, fix_y, fix_z)
        # if there are more or less than one restriction apply all rotations
        rotation *= qrotation(y_axis, angles[2])
        rotation *= qrotation(x_axis, angles[1])
        rotation *= qrotation(z_axis, angles[3])
    else
        # apply world space restrictions
        if from_mouse && ((fix_x && (fix_x == cx)) || (fix_y && (fix_y == cy)) || (fix_z && (fix_z == cz)))
            # recontextualize the (dy, dx, 0) from mouse rotations so that
            # drawing circles creates continuous rotations around the fixed axis
            mp = mouseposition_px(scene)
            past_half = 0.5f0 .* widths(scene.px_area[]) .> mp
            flip = 2f0 * past_half .- 1f0
            angle = flip[1] * angles[1] + flip[2] * angles[2]
            angles = Vec3f0(-angle, angle, -angle)
            # only one fix is true so this only rotates around one axis
            rotation *= qrotation(
                Vec3f0(fix_x, fix_z, fix_y) .* Vec3f0(sign(right[1]), viewdir[2], sign(up[3])),
                dot(Vec3f0(fix_x, fix_y, fix_z), angles)
            )
        else
            # restrict total quaternion rotation to one axis
            rotation *= qrotation(y_axis, angles[2])
            rotation *= qrotation(x_axis, angles[1])
            rotation *= qrotation(z_axis, angles[3])
            # the first three components are related to rotations around the x/y/z-axis
            rotation = Quaternionf0(rotation.data .* (fix_x, fix_y, fix_z, 1))
        end
    end

    cam.upvector[] = rotation * up
    viewdir = rotation * viewdir

    # TODO maybe generalize this to arbitrary center?
    # calculate positions from rotated vectors
    if cam.attributes[:rotation_center][] == :lookat
        cam.eyeposition[] = lookat - viewdir
    else
        cam.lookat[] = eyepos + viewdir
    end
    update_cam!(scene, cam)
    return
end

zoom!(scene::Scene, zoom_step) = zoom!(scene, cameracontrols(scene), zoom_step, false, false)
function zoom!(scene::Scene, cam::Camera3D, zoom_step, shift_lookat = false, cad = false)
    if cad
        # move eyeposition if mouse is not over the center
        lookat = cam.lookat[]
        eyepos = cam.eyeposition[]
        up = cam.upvector[]         # +y
        viewdir = lookat - eyepos   # -z
        right = cross(viewdir, up)  # +x

        rel_pos = 2f0 * mouseposition_px(scene) ./ widths(scene.px_area[]) .- 1f0
        shift = rel_pos[1] * normalize(right) + rel_pos[2] * normalize(up)
        shifted = eyepos + 0.1f0 * sign(1f0 - zoom_step) * norm(viewdir) * shift
        cam.eyeposition[] = lookat + norm(viewdir) * normalize(shifted - lookat)
    elseif shift_lookat
        # translate both eyeposition and lookat to more or less keep data under
        # the mouse in view
        lookat = cam.lookat[]
        eyepos = cam.eyeposition[]
        up = cam.upvector[]         # +y
        viewdir = lookat - eyepos   # -z
        right = cross(viewdir, up)  # +x

        fov = cam.attributes[:fov][]
        before = tan(clamp(cam.zoom_mult[] * fov, 0.01f0, 175f0) / 360f0 * Float32(pi))
        after  = tan(clamp(cam.zoom_mult[] * zoom_step * fov, 0.01f0, 175f0) / 360f0 * Float32(pi))

        aspect = Float32((/)(widths(scene.px_area[])...))
        rel_pos = 2f0 * mouseposition_px(scene) ./ widths(scene.px_area[]) .- 1f0
        shift = rel_pos[1] * normalize(right) + rel_pos[2] * normalize(up)
        shift = -(after - before) * norm(viewdir) * normalize(aspect .* shift)

        cam.lookat[]      = lookat + shift
        cam.eyeposition[] = eyepos + shift
    end

    # apply zoom
    cam.zoom_mult[] *= zoom_step
    update_cam!(scene, cam)
    return
end


function update_cam!(scene::Scene, cam::Camera3D)
    @extractvalue cam (lookat, eyeposition, upvector, near, far)

    aspect = Float32((/)(widths(scene.px_area[])...))

    if cam.attributes[:projectiontype][] == Perspective
        fov = clamp(cam.zoom_mult[] * cam.attributes[:fov][], 0.01f0, 175f0)
        cam.fov[] = fov
        proj = perspectiveprojection(fov, aspect, near, far)
    else
        distance = norm(lookat - eyeposition)
        w = 0.5f0 * (1f0 + aspect) * cam.zoom_mult[] * distance
        h = 0.5f0 * (1f0 + 1f0 / aspect) * cam.zoom_mult[] * distance
        proj = orthographicprojection(-w, w, -h, h, near, far)
    end

    view = Makie.lookat(eyeposition, lookat, upvector)

    scene.camera.projection[] = proj
    scene.camera.view[] = view
    scene.camera.projectionview[] = proj * view
    scene.camera.eyeposition[] = eyeposition
end

function update_cam!(scene::Scene, camera::Camera3D, area3d::Rect)
    @extractvalue camera (lookat, eyeposition, upvector)
    bb = FRect3D(area3d)
    width = widths(bb)
    half_width = width/2f0
    middle = maximum(bb) - half_width
    old_dir = normalize(eyeposition .- lookat)
    camera.lookat[] = middle
    fact = (camera.attributes[:projectiontype][] == Perspective) ? 1.2 : .5
    neweyepos = middle .+ (fact * norm(width) .* old_dir)
    camera.eyeposition[] = neweyepos
    camera.upvector[] = Vec3f0(0,0,1)
    if camera.attributes[:near][] === automatic
        camera.near[] = 0.1f0 * norm(widths(bb))
    end
    if camera.attributes[:far][] === automatic
        camera.far[]  = 3f0 * norm(widths(bb))
    end
    camera.zoom_mult[] = 1f0
    update_cam!(scene, camera)
    return
end

function update_cam!(scene::Scene, camera::Camera3D, eyeposition, lookat, up = Vec3f0(0, 0, 1))
    camera.lookat[] = Vec3f0(lookat)
    camera.eyeposition[] = Vec3f0(eyeposition)
    camera.upvector[] = Vec3f0(up)
    update_cam!(scene, camera)
    return
end
