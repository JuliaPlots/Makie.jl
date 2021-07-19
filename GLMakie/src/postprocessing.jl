# Utilities:
function draw_fullscreen(vao_id)
    glBindVertexArray(vao_id)
    glDrawArrays(GL_TRIANGLES, 0, 3)
    glBindVertexArray(0)
    return
end

struct PostprocessPrerender end

function (sp::PostprocessPrerender)()
    glDepthMask(GL_TRUE)
    glDisable(GL_DEPTH_TEST)
    glDisable(GL_BLEND)
    glDisable(GL_CULL_FACE)
    return
end

const PostProcessROBJ = RenderObject{PostprocessPrerender}

rcpframe(x) = 1f0 ./ Vec2f(x[1], x[2])

struct PostProcessor{F}
    robjs::Vector{PostProcessROBJ}
    render::F
end

function empty_postprocessor(args...; kwargs...)
    PostProcessor(PostProcessROBJ[], screen -> nothing)
end



function ssao_postprocessor(framebuffer)
    # Add missing buffers
    if !haskey(framebuffer.buffers, :position)
        glBindFramebuffer(GL_FRAMEBUFFER, framebuffer.id[1])
        position_buffer = Texture(
            Vec4f, size(framebuffer), minfilter = :nearest, x_repeat = :clamp_to_edge
        )
        attach_framebuffer(position_buffer, GL_COLOR_ATTACHMENT2)
        push!(framebuffer.buffers, :position => position_buffer)
    end
    if !haskey(framebuffer.buffers, :normal)
        glBindFramebuffer(GL_FRAMEBUFFER, framebuffer.id[1])
        normal_occlusion_buffer = Texture(
            Vec4f, size(framebuffer), minfilter = :nearest, x_repeat = :clamp_to_edge
        )
        attach_framebuffer(normal_occlusion_buffer, GL_COLOR_ATTACHMENT3)
        push!(framebuffer.buffers, :normal_occlusion => normal_occlusion_buffer)
    end

    # Add buffers written in primary render (before postprocessing)
    if !(GL_COLOR_ATTACHMENT2 in framebuffer.render_buffer_ids)
        push!(framebuffer.render_buffer_ids, GL_COLOR_ATTACHMENT2)
    end
    if !(GL_COLOR_ATTACHMENT3 in framebuffer.render_buffer_ids)
        push!(framebuffer.render_buffer_ids, GL_COLOR_ATTACHMENT3)
    end

    # SSAO setup
    N_samples = 64
    lerp_min = 0.1f0
    lerp_max = 1.0f0
    kernel = map(1:N_samples) do i
        n = normalize([2.0rand() .- 1.0, 2.0rand() .- 1.0, rand()])
        scale = lerp_min + (lerp_max - lerp_min) * (i / N_samples)^2
        v = Vec3f(scale * rand() * n)
    end



    # compute occlusion
    shader1 = LazyShader(
        loadshader("postprocessing/fullscreen.vert"),
        loadshader("postprocessing/SSAO.frag"),
        view = Dict(
            "N_samples" => "$N_samples"
        )
    )
    data1 = Dict{Symbol, Any}(
        :position_buffer => framebuffer.buffers[:position],
        :normal_occlusion_buffer => framebuffer.buffers[:normal_occlusion],
        :kernel => kernel,
        :noise => Texture(
            [normalize(Vec2f(2.0rand(2) .- 1.0)) for _ in 1:4, __ in 1:4],
            minfilter = :nearest, x_repeat = :repeat
        ),
        :noise_scale => map(s -> Vec2f(s ./ 4.0), framebuffer.resolution),
        :projection => Node(Mat4f(I)),
        :bias => Node(0.025f0),
        :radius => Node(0.5f0)
    )
    pass1 = RenderObject(data1, shader1, PostprocessPrerender(), nothing)
    pass1.postrenderfunction = () -> draw_fullscreen(pass1.vertexarray.id)


    # blur occlusion and combine with color
    shader2 = LazyShader(
        loadshader("postprocessing/fullscreen.vert"),
        loadshader("postprocessing/SSAO_blur.frag")
    )
    data2 = Dict{Symbol, Any}(
        :normal_occlusion => framebuffer.buffers[:normal_occlusion],
        :color_texture => framebuffer.buffers[:color],
        :ids => framebuffer.buffers[:objectid],
        :inv_texel_size => lift(rcpframe, framebuffer.resolution),
        :blur_range => Node(Int32(2))
    )
    pass2 = RenderObject(data2, shader2, PostprocessPrerender(), nothing)
    pass2.postrenderfunction = () -> draw_fullscreen(pass2.vertexarray.id)



    full_render = screen -> begin
        fb = screen.framebuffer
        w, h = size(fb)

        # Setup rendering
        # SSAO - calculate occlusion
        glDrawBuffer(GL_COLOR_ATTACHMENT3)  # occlusion buffer
        glViewport(0, 0, w, h)
        # glClearColor(1, 1, 1, 1)            # 1 means no darkening
        # glClear(GL_COLOR_BUFFER_BIT)
        glDisable(GL_STENCIL_TEST)
        glEnable(GL_SCISSOR_TEST)

        for (screenid, scene) in screen.screens
            # Select the area of one leaf scene
            # This should be per scene because projection may vary between 
            # scenes. It should be a leaf scene to avoid repeatedly shading
            # the same region (though this is not guaranteed...)
            isempty(scene.children) || continue
            a = pixelarea(scene)[]
            glScissor(minimum(a)..., widths(a)...)
            # update uniforms
            SSAO = scene.SSAO
            data1[:projection][] = scene.camera.projection[]
            data1[:bias][] = Float32(to_value(get(SSAO, :bias, 0.025)))
            data1[:radius][] = Float32(to_value(get(SSAO, :radius, 0.5)))
            GLAbstraction.render(pass1)
        end


        # SSAO - blur occlusion and apply to color
        glDrawBuffer(GL_COLOR_ATTACHMENT0)  # color buffer
        for (screenid, scene) in screen.screens
            # Select the area of one leaf scene
            isempty(scene.children) || continue
            a = pixelarea(scene)[]
            glScissor(minimum(a)..., widths(a)...)
            # update uniforms
            SSAO = scene.attributes.SSAO
            data2[:blur_range][] = Int32(to_value(get(SSAO, :blur, 2)))
            GLAbstraction.render(pass2)
        end
        glDisable(GL_SCISSOR_TEST)
    end

    PostProcessor([pass1, pass2], full_render)
end



"""
    fxaa_postprocessor(framebuffer)

Returns a PostProcessor that handles fxaa.
"""
function fxaa_postprocessor(framebuffer)
    # Add missing buffers
    if !haskey(framebuffer.buffers, :color_luma)
        glBindFramebuffer(GL_FRAMEBUFFER, framebuffer.id[2])
        color_luma_buffer = Texture(
            RGBA{N0f8}, size(framebuffer), minfilter=:linear, x_repeat=:clamp_to_edge
        )
        attach_framebuffer(color_luma_buffer, GL_COLOR_ATTACHMENT0)
        push!(framebuffer.buffers, :color_luma => color_luma_buffer)
    end



    # calculate luma for FXAA
    shader1 = LazyShader(
        loadshader("postprocessing/fullscreen.vert"),
        loadshader("postprocessing/postprocess.frag")
    )
    data1 = Dict{Symbol, Any}(
        :color_texture => framebuffer.buffers[:color]
    )
    pass1 = RenderObject(data1, shader1, PostprocessPrerender(), nothing)
    pass1.postrenderfunction = () -> draw_fullscreen(pass1.vertexarray.id)

    # perform FXAA
    shader2 = LazyShader(
        loadshader("postprocessing/fullscreen.vert"),
        loadshader("postprocessing/fxaa.frag")
    )
    data2 = Dict{Symbol, Any}(
        :color_texture => framebuffer.buffers[:color_luma],
        :RCPFrame => lift(rcpframe, framebuffer.resolution),
    )
    pass2 = RenderObject(data2, shader2, PostprocessPrerender(), nothing)
    pass2.postrenderfunction = () -> draw_fullscreen(pass2.vertexarray.id)



    full_render = screen -> begin
        fb = screen.framebuffer
        w, h = size(fb)

        # FXAA - calculate LUMA
        glBindFramebuffer(GL_FRAMEBUFFER, framebuffer.id[2])
        glDrawBuffer(GL_COLOR_ATTACHMENT0)  # color_luma buffer
        glViewport(0, 0, w, h)
        # necessary with negative SSAO bias...
        glClearColor(1, 1, 1, 1)
        glClear(GL_COLOR_BUFFER_BIT)
        GLAbstraction.render(pass1)

        # FXAA - perform anti-aliasing
        glBindFramebuffer(GL_FRAMEBUFFER, framebuffer.id[1])
        glDrawBuffer(GL_COLOR_ATTACHMENT0)  # color buffer
        # glViewport(0, 0, w, h) # not necessary
        GLAbstraction.render(pass2)
    end

    PostProcessor([pass1, pass2], full_render)
end


"""
    to_screen_postprocessor(framebuffer)

Sets up a Postprocessor which copies the color buffer to the screen. Used as a
final step for displaying the screen.
"""
function to_screen_postprocessor(framebuffer)
    # draw color buffer
    shader = LazyShader(
        loadshader("postprocessing/fullscreen.vert"),
        loadshader("postprocessing/copy.frag")
    )
    data = Dict{Symbol, Any}(
        :color_texture => framebuffer.buffers[:color]
    )
    pass = RenderObject(data, shader, PostprocessPrerender(), nothing)
    pass.postrenderfunction = () -> draw_fullscreen(pass.vertexarray.id)

    full_render = screen -> begin
        fb = screen.framebuffer
        w, h = size(fb)

        # transfer everything to the screen
        glBindFramebuffer(GL_FRAMEBUFFER, 0)
        glViewport(0, 0, w, h)
        glClear(GL_COLOR_BUFFER_BIT)
        GLAbstraction.render(pass) # copy postprocess
    end

    PostProcessor([pass], full_render)
end
