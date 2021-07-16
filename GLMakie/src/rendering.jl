# TODO process!(scene, RenderTickEvent())
function vsynced_renderloop(screen)
    while isopen(screen) && !WINDOW_CONFIG.exit_renderloop[]
        pollevents(screen) # GLFW poll
        screen.render_tick[] = nothing
        if WINDOW_CONFIG.pause_rendering[]
            sleep(0.1)
        else
            make_context_current(screen)
            render_frame(screen)
            GLFW.SwapBuffers(to_native(screen))
            yield()
        end
    end
end

function fps_renderloop(screen::Screen, framerate=WINDOW_CONFIG.framerate[])
    time_per_frame = 1.0 / framerate
    while isopen(screen) && !WINDOW_CONFIG.exit_renderloop[]
        t = time_ns()
        pollevents(screen) # GLFW poll
        screen.render_tick[] = nothing
        if WINDOW_CONFIG.pause_rendering[]
            sleep(0.1)
        else
            make_context_current(screen)
            render_frame(screen)
            GLFW.SwapBuffers(to_native(screen))
            t_elapsed = (time_ns() - t) / 1e9
            diff = time_per_frame - t_elapsed
            if diff > 0.001 # can't sleep less than 0.001
                sleep(diff)
            else # if we don't sleep, we still need to yield explicitely to other tasks
                yield()
            end
        end
    end
end

function renderloop(screen; framerate=WINDOW_CONFIG.framerate[])
    isopen(screen) || error("Screen most be open to run renderloop!")
    try
        if WINDOW_CONFIG.vsync[]
            GLFW.SwapInterval(1)
            vsynced_renderloop(screen)
        else
            GLFW.SwapInterval(0)
            fps_renderloop(screen, framerate)
        end
    catch e
        showerror(stderr, e, catch_backtrace())
        println(stderr)
        rethrow(e)
    finally
        destroy!(screen)
    end
end

const WINDOW_CONFIG = (
    renderloop = Ref{Function}(renderloop),
    vsync = Ref(false),
    framerate = Ref(30.0),
    float = Ref(false),
    pause_rendering = Ref(false),
    focus_on_show = Ref(false),
    decorated = Ref(true),
    title = Ref("Makie"),
    exit_renderloop = Ref(false),
    osx_retina_scaling = Ref(false)
)

"""
    set_window_config!(;
        renderloop = renderloop,
        vsync = false,
        framerate = 30.0,
        float = false,
        pause_rendering = false,
        focus_on_show = false,
        decorated = true,
        title = "Makie",
        # Disables OSX doubling the amount of pixels on high dpi screens
        # and preserves the mapping 1 makie px -> 1 screen px
        osx_retina_scaling = false
    )
Updates the screen configuration, will only go into effect after closing the current
window and opening a new one!
"""
function set_window_config!(; kw...)
    for (key, value) in kw
        if hasproperty(WINDOW_CONFIG, key)
            getfield(WINDOW_CONFIG, key)[] = value
        else
            error("$key is not a valid window config. Call ?set_window_config!, to see applicable options")
        end
    end
end

function setup!(screen)
    glEnable(GL_SCISSOR_TEST)
    if isopen(screen)
        glScissor(0, 0, widths(screen)...)
        glClearColor(1, 1, 1, 1)
        glClear(GL_COLOR_BUFFER_BIT)
        for (id, scene) in screen.screens
            if scene.visible[]
                a = pixelarea(scene)[]
                rt = (minimum(a)..., widths(a)...)
                glViewport(rt...)
                bits = GL_STENCIL_BUFFER_BIT
                glClearStencil(id)
                if scene.clear
                    c = to_color(scene.backgroundcolor[])
                    glScissor(rt...)
                    glClearColor(red(c), green(c), blue(c), alpha(c))
                    bits |= GL_COLOR_BUFFER_BIT
                    glClear(bits)
                end
            end
        end
    end
    glDisable(GL_SCISSOR_TEST)
    return
end

const selection_queries = Function[]

"""
Renders a single frame of a `window`
"""
function render_frame(screen::Screen; resize_buffers=true)
    nw = to_native(screen)
    ShaderAbstractions.is_context_active(nw) || return
    fb = screen.framebuffer
    if resize_buffers
        wh = Int.(framebuffer_size(nw))
        resize!(fb, wh)
    end
    w, h = size(fb)

    # prepare stencil (for sub-scenes)
    glEnable(GL_STENCIL_TEST)
    glBindFramebuffer(GL_FRAMEBUFFER, fb.id[1]) # color framebuffer
    glDrawBuffers(length(fb.render_buffer_ids), fb.render_buffer_ids)
    glEnable(GL_STENCIL_TEST)
    glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE)
    glStencilMask(0xff)
    glClearStencil(0)
    glClearColor(0, 0, 0, 0)
    glClear(GL_DEPTH_BUFFER_BIT | GL_STENCIL_BUFFER_BIT | GL_COLOR_BUFFER_BIT)
    glDrawBuffer(fb.render_buffer_ids[1])
    setup!(screen)
    glDrawBuffers(length(fb.render_buffer_ids), fb.render_buffer_ids)

    # render with FXAA & SSAO
    glColorMask(GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE)
    glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE)
    glStencilMask(0x00)
    GLAbstraction.render(screen, true, true)


    # SSAO
    screen.postprocessors[1].render(screen)

    # render with FXAA but no SSAO
    glDrawBuffers(2, [GL_COLOR_ATTACHMENT0, GL_COLOR_ATTACHMENT1])
    glEnable(GL_STENCIL_TEST)
    glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE)
    glStencilMask(0x00)
    GLAbstraction.render(screen, true, false)
    glDisable(GL_STENCIL_TEST)

    # FXAA
    screen.postprocessors[2].render(screen)


    # no FXAA primary render
    glDrawBuffers(2, [GL_COLOR_ATTACHMENT0, GL_COLOR_ATTACHMENT1])
    glEnable(GL_STENCIL_TEST)
    glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE)
    glStencilMask(0x00)
    GLAbstraction.render(screen, false)
    glDisable(GL_STENCIL_TEST)

    # transfer everything to the screen
    screen.postprocessors[3].render(screen)


    return
end

function id2scene(screen, id1)
    # TODO maybe we should use a different data structure
    for (id2, scene) in screen.screens
        id1 == id2 && return true, scene
    end
    return false, nothing
end

function GLAbstraction.render(screen::GLScreen, fxaa::Bool, ssao::Bool=false)
    # Somehow errors in here get ignored silently!?
    try
        # sort by overdraw, so that overdrawing objects get drawn last!
        # sort!(screen.renderlist, by = ((zi, id, robj),)-> robj.prerenderfunction.overdraw[])
        for (zindex, screenid, elem) in screen.renderlist
            found, scene = id2scene(screen, screenid)
            found || continue
            a = pixelarea(scene)[]
            glViewport(minimum(a)..., widths(a)...)
            if scene.clear
                glStencilFunc(GL_EQUAL, screenid, 0xff)
            else
                # if we don't clear, that means we have a screen that is overlaid
                # on top of another, which means it doesn't have a stencil value
                # so we can't do the stencil test
                glStencilFunc(GL_ALWAYS, screenid, 0xff)
            end
            if (fxaa && elem[:fxaa][]) && ssao && elem[:ssao][]
                render(elem)
            end
            if (fxaa && elem[:fxaa][]) && !ssao && !elem[:ssao][]
                render(elem)
            end
            if !fxaa && !elem[:fxaa][]
                render(elem)
            end
        end
    catch e
        @error "Error while rendering!" exception = e
        rethrow(e)
    end
    return
end
