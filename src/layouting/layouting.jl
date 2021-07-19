using FreeTypeAbstraction: hadvance, leftinkbound, inkwidth, get_extent, ascender, descender

one_attribute_per_char(attribute, string) = (attribute for char in string)

function one_attribute_per_char(font::NativeFont, string)
    return (find_font_for_char(char, font) for char in string)
end

function attribute_per_char(string, attribute)
    n_words = 0
    if attribute isa AbstractVector
        if length(attribute) == length(string)
            return attribute
        else
            n_words = length(split(string, r"\s+"))
            if length(attribute) == n_words
                i = 1
                return map(collect(string)) do char
                    f = attribute[i]
                    char == "\n" && (i += 1)
                    return f
                end
            end
        end
    else
        return one_attribute_per_char(attribute, string)
    end
    error("A vector of attributes with $(length(attribute)) elements was given but this fits neither the length of '$string' ($(length(string))) nor the number of words ($(n_words))")
end



"""
    layout_text(
        string::AbstractString, textsize::Union{AbstractVector, Number},
        font, align, rotation, model, justification, lineheight
    )

Compute a GlyphCollection for a `string` given textsize, font, align, rotation, model, justification, and lineheight.
"""
function layout_text(
        string::AbstractString, textsize::Union{AbstractVector, Number},
        font, align, rotation, model, justification, lineheight, color, strokecolor, strokewidth
    )

    ft_font = to_font(font)
    rscale = to_textsize(textsize)
    rot = to_rotation(rotation)

    # atlas = get_texture_atlas()
    # mpos = model * Vec4f(to_ndim(Vec3f, startpos, 0f0)..., 1f0)
    # pos = to_ndim(Point3f, mpos, 0)

    fontperchar = attribute_per_char(string, ft_font)
    textsizeperchar = attribute_per_char(string, rscale)

    glyphcollection = glyph_collection(string, fontperchar, textsizeperchar, align[1],
        align[2], lineheight, justification, rot, color, strokecolor, strokewidth)

    return glyphcollection
end

"""
    glyph_collection(str::AbstractString, font_per_char, fontscale_px, halign, valign, lineheight_factor, justification, rotation, color)

Calculate the positions for each glyph in a string given a certain font, font size, alignment, etc.
This layout in text coordinates, relative to the anchor point [0,0] can then be translated and
rotated to wherever it is needed in the plot.
"""
function glyph_collection(str::AbstractString, font_per_char, fontscale_px, halign, valign,
        lineheight_factor, justification, rotation, color, strokecolor, strokewidth)

    isempty(str) && return GlyphCollection(
        [], [], Point3f[],FreeTypeAbstraction.FontExtent{Float32}[],
        Vec2f[], Float32[], RGBAf[], RGBAf[], Float32[])

    # collect information about every character in the string
    charinfos = broadcast([c for c in str], font_per_char, fontscale_px) do char, font, scale
        # TODO: scale as SVector not Number
        unscaled_extent = get_extent(font, char)
        lineheight = Float32(font.height / font.units_per_EM * lineheight_factor * scale)
        unscaled_hi_bb = height_insensitive_boundingbox(unscaled_extent, font)
        hi_bb = Rect2f(
            Makie.origin(unscaled_hi_bb) * scale,
            widths(unscaled_hi_bb) * scale)
        (char = char, font = font, scale = scale, hadvance = hadvance(unscaled_extent) * scale,
            hi_bb = hi_bb, lineheight = lineheight, extent = unscaled_extent)
    end

    # split the character info vector into lines after every \n
    lineinfos = let
        last_line_start = 1
        lineinfos = typeof(view(charinfos, last_line_start:last_line_start))[]
        for (i, ci) in enumerate(charinfos)
            if ci.char == '\n' || i == length(charinfos)
                push!(lineinfos, view(charinfos, last_line_start:i))
                last_line_start = i+1
            end
        end
        lineinfos
    end

    # calculate the x positions of each character in each line
    xs = map(lineinfos) do line
        cumsum([
            isempty(line) ? 0.0 : -(line[1].hi_bb.origin[1]);
            [l.hadvance for l in line[1:end-1]]
        ])
    end

    # calculate linewidths as the last origin plus inkwidth for each line
    linewidths = map(lineinfos, xs) do line, xx
        nchars = length(line)
        # if the last and not the only character is \n, take the previous one
        # to compute the width
        i = (nchars > 1 && line[end].char == '\n') ? nchars - 1 : nchars
        xx[i] + widths(line[i].hi_bb)[1]
    end

    # the maximum width is needed for justification
    maxwidth = maximum(linewidths)

    # how much each line differs from the maximum width for justification correction
    width_differences = maxwidth .- linewidths

    # shift all x values by the justification amount needed for each line
    # if justification is automatic it depends on alignment
    float_justification = if justification === automatic
        if halign == :left || halign == 0
            0.0f0
        elseif halign == :right || halign == 1
            1.0f0
        elseif halign == :center || halign == 0.5
            0.5f0
        else
            0.5f0
        end
    elseif justification == :left
        0.0f0
    elseif justification == :right
        1.0f0
    elseif justification == :center
        0.5f0
    else
        Float32(justification)
    end

    xs_justified = map(xs, width_differences) do xsgroup, wd
        xsgroup .+ wd * float_justification
    end

    # each character carries a "lineheight" metric given its font and scale and a lineheight scaling factor
    # make each line's height the maximum of these values in the line
    lineheights = map(lineinfos) do line
        maximum(l -> l.lineheight, line)
    end

    # compute y values by adding up lineheights in negative y direction
    ys = cumsum([0.0; -lineheights[2:end]])

    # compute x values after left/center/right alignment
    halign = if halign isa Number
        Float32(halign)
    elseif halign == :left
        0.0f0
    elseif halign == :center
        0.5f0
    elseif halign == :right
        1.0f0
    else
        error("Invalid halign $halign. Valid values are <:Number, :left, :center and :right.")
    end
    xs_aligned = [xsgroup .- halign * maxwidth for xsgroup in xs_justified]

    # for y alignment, we need the largest ascender of the first line
    # and the largest descender of the last line
    first_line_ascender = maximum(lineinfos[1]) do l
        ascender(l.font) * l.scale
    end

    last_line_descender = minimum(lineinfos[end]) do l
        descender(l.font) * l.scale
    end

    # compute the height of all lines together
    overall_height = first_line_ascender - ys[end] - last_line_descender

    # compute y values after top/center/bottom/baseline alignment
    ys_aligned = if valign == :baseline
        ys .- first_line_ascender .+ overall_height .+ last_line_descender
    else
        va = if valign isa Number
            Float32(valign)
        elseif valign == :top
            1f0
        elseif valign == :bottom
            0f0
        elseif valign == :center
            0.5f0
        else
            error("Invalid valign $valign. Valid values are <:Number, :bottom, :baseline, :top, and :center.")
        end

        ys .- first_line_ascender .+ (1 - va) .* overall_height
    end

    # compute the origins for each character by rotating each character around the common origin
    # which is the alignment anchor and now [0, 0]
    # use 3D coordinates already because later they will be required in that format anyway
    charorigins = [Ref(rotation) .* Point3f.(xsgroup, y, 0) for (xsgroup, y) in zip(xs_aligned, ys_aligned)]

    # return a GlyphCollection, which contains each character's origin, height-insensitive
    # boundingbox and horizontal advance value
    # these values should be enough to draw characters correctly,
    # compute boundingboxes without relayouting and maybe implement
    # interactive features that need to know where characters begin and end
    return GlyphCollection(
        [x.char for x in charinfos],
        [x.font for x in charinfos],
        reduce(vcat, charorigins),
        [x.extent for x in charinfos],
        [Vec2f(x.scale) for x in charinfos],
        [rotation for x in charinfos],
        [color for x in charinfos],
        [strokecolor for x in charinfos],
        [strokewidth for x in charinfos],
    )
end


function preprojected_glyph_arrays(
        position::VecTypes, glyphcollection::Makie.GlyphCollection,
        space::Symbol, projview, resolution, offset::VecTypes, transfunc
    )
    offset = to_ndim(Point3f, offset, 0)
    pos3f0 = to_ndim(Point3f, position, 0)

    if space == :data
        positions = apply_transform(transfunc, Point3f[pos3f0 + offset + o for o in glyphcollection.origins])
    elseif space == :screen
        projected = Makie.project(projview, resolution, apply_transform(transfunc, pos3f0))
        positions = Point3f[to_ndim(Point3f, projected, 0) + offset + o for o in glyphcollection.origins]
    else
        error("Unknown space $space, only :data or :screen allowed")
    end
    text_quads(positions, glyphcollection.glyphs, glyphcollection.fonts, glyphcollection.scales)
end

function preprojected_glyph_arrays(
        position::VecTypes, glyphcollection::Makie.GlyphCollection,
        space::Symbol, projview, resolution, offsets::Vector, transfunc
    )

    offsets = to_ndim.(Point3f, offsets, 0)
    pos3f0 = to_ndim(Point3f, position, 0)

    if space == :data
        positions = apply_transform(transfunc, [pos3f0 + offset + o for (o, offset) in zip(glyphcollection.origins, offsets)])
    elseif space == :screen
        projected = Makie.project(projview, resolution, apply_transform(transfunc, pos3f0))
        positions = Point3f[to_ndim(Point3f, projected, 0) + offset + o for (o, offset) in zip(glyphcollection.origins, offsets)]
    else
        error("Unknown space $space, only :data or :screen allowed")
    end

    text_quads(positions, string, font, textsize)
end

function preprojected_glyph_arrays(
        positions::AbstractVector, glyphcollections::AbstractVector{<:GlyphCollection}, space::Symbol, projview, resolution, offset, transfunc
    )

    if offset isa VecTypes
        offset = [to_ndim(Point3f, offset, 0)]
    end

    if space == :data
        allpos = broadcast(positions, glyphcollections, offset) do pos, glyphcollection, offs
            p = to_ndim(Point3f, pos, 0)
            apply_transform(
                transfunc,
                Point3f[p .+ to_ndim(Point3f, offs, 0) .+ o for o in glyphcollection.origins]
            )
        end
    elseif space == :screen
        allpos = broadcast(positions, glyphcollections, offset) do pos, glyphcollection, offs
            projected = to_ndim(
                Point3f,
                Makie.project(
                    projview,
                    resolution,
                    apply_transform(transfunc, to_ndim(Point3f, pos, 0))
                ),
                0)

            return Point3f[projected .+ to_ndim(Point3f, offs, 0) + o
                        for o in glyphcollection.origins]
        end
    else
        error("Unknown space $space, only :data or :screen allowed")
    end

    text_quads(
        allpos,
        [x.glyphs for x in glyphcollections],
        [x.fonts for x in glyphcollections],
        [x.scales for x in glyphcollections])
end


function text_quads(positions, glyphs::AbstractVector, fonts::AbstractVector, textsizes::ScalarOrVector{<:Vec2})

    atlas = get_texture_atlas()
    offsets = Vec2f[]
    uv = Vec4f[]
    scales = Vec2f[]
    broadcast_foreach(positions, glyphs, fonts, textsizes) do offs, c, font, pixelsize
    # for (c, font, pixelsize) in zipx(glyphs, fonts, textsizes)
        push!(uv, glyph_uv_width!(atlas, c, font))
        glyph_bb, extent = FreeTypeAbstraction.metrics_bb(c, font, pixelsize)
        push!(scales, widths(glyph_bb))
        push!(offsets, minimum(glyph_bb))
    end
    return positions, offsets, uv, scales
end

function text_quads(positions, glyphs, fonts, textsizes::Vector{<:ScalarOrVector})

    atlas = get_texture_atlas()
    offsets = Vec2f[]
    uv = Vec4f[]
    scales = Vec2f[]

    broadcast_foreach(positions, glyphs, fonts, textsizes) do positions, glyphs, fonts, textsizes
        broadcast_foreach(positions, glyphs, fonts, textsizes) do offs, c, font, pixelsize
            push!(uv, glyph_uv_width!(atlas, c, font))
            glyph_bb, extent = FreeTypeAbstraction.metrics_bb(c, font, pixelsize)
            push!(scales, widths(glyph_bb))
            push!(offsets, minimum(glyph_bb))
        end
    end

    return reduce(vcat, positions, init = Point3f[]), offsets, uv, scales
end


# function to concatenate vectors with a value between every pair
function padded_vcat(arrs::AbstractVector{T}, fillvalue) where T <: AbstractVector{S} where S
    n = sum(length.(arrs))
    arr = fill(convert(S, fillvalue), n + length(arrs) - 1)

    counter = 1
    @inbounds for a in arrs
        for v in a
            arr[counter] = v
            counter += 1
        end
        counter += 1
    end
    arr
end

function alignment2num(x::Symbol)
    (x == :center) && return 0.5f0
    (x in (:left, :bottom)) && return 0.0f0
    (x in (:right, :top)) && return 1.0f0
    return 0.0f0 # 0 default, or better to error?
end
