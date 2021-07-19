using Serialization
using FreeTypeAbstraction: iter_or_array

mutable struct TextureAtlas
    rectangle_packer::RectanglePacker
    mapping::Dict{Tuple{Char, String}, Int} # styled glyph to index in sprite_attributes
    index::Int
    data::Matrix{Float16}
    # rectangles we rendered our glyphs into in normalized uv coordinates
    uv_rectangles::Vector{Vec4f}
end

Base.size(atlas::TextureAtlas) = size(atlas.data)

@enum GlyphResolution High Low

const TEXTURE_RESOLUTION = Ref((2048, 2048))
const CACHE_RESOLUTION_PREFIX = Ref("high")

const HIGH_PIXELSIZE = 64
const LOW_PIXELSIZE = 32

const PIXELSIZE_IN_ATLAS = Ref(HIGH_PIXELSIZE)

function set_glyph_resolution!(res::GlyphResolution)
    if res == High
        TEXTURE_RESOLUTION[] = (2048, 2048)
        CACHE_RESOLUTION_PREFIX[] = "high"
        PIXELSIZE_IN_ATLAS[] = HIGH_PIXELSIZE
    else
        TEXTURE_RESOLUTION[] = (1024, 1024)
        CACHE_RESOLUTION_PREFIX[] = "low"
        PIXELSIZE_IN_ATLAS[] = LOW_PIXELSIZE
    end
end

function TextureAtlas(initial_size = TEXTURE_RESOLUTION[])
    return TextureAtlas(
        RectanglePacker(Rect2(0, 0, initial_size...)),
        Dict{Tuple{Char, String}, Int}(),
        1,
        zeros(Float16, initial_size...),
        Vec4f[],
    )
end

begin
    # basically a singleton for the textureatlas

    function get_cache_path()
        return abspath(
            first(Base.DEPOT_PATH), "makiegallery", ".cache",
            "texture_atlas_$(CACHE_RESOLUTION_PREFIX[])_$(VERSION).jls"
        )
    end

    const _default_font = NativeFont[]
    const _alternative_fonts = NativeFont[]

    function defaultfont()
        if isempty(_default_font)
            push!(_default_font, to_font("Dejavu Sans"))
        end
        _default_font[]
    end

    function alternativefonts()
        if isempty(_alternative_fonts)
            alternatives = [
                "DejaVuSans.ttf",
                "NotoSansCJKkr-Regular.otf",
                "NotoSansCuneiform-Regular.ttf",
                "NotoSansSymbols-Regular.ttf",
                "FiraMono-Medium.ttf"
            ]
            for font in alternatives
                push!(_alternative_fonts, NativeFont(assetpath("fonts", font)))
            end
        end
        return _alternative_fonts
    end

    function load_ascii_chars!(atlas)
        # for c in '\u0000':'\u00ff' #make sure all ascii is mapped linearly
        #     insert_glyph!(atlas, c, defaultfont())
        # end
        for c in '0':'9' #make sure all ascii is mapped linearly
            insert_glyph!(atlas, c, defaultfont())
        end
        for c in 'A':'Z' #make sure all ascii is mapped linearly
            insert_glyph!(atlas, c, defaultfont())
        end
    end

    function cached_load()
        if isfile(get_cache_path())
            try
                return open(get_cache_path()) do io
                    dict = Serialization.deserialize(io)
                    fields = map(fieldnames(TextureAtlas)) do n
                        v = dict[n]
                        isa(v, Vector) ? copy(v) : v # otherwise there seems to be a problem with resizing
                    end
                    TextureAtlas(fields...)
                end
            catch e
                @info("You can likely ignore the following warning, if you just switched Julia versions for Makie")
                @warn(e)
                rm(get_cache_path())
            end
        end
        atlas = TextureAtlas()
        @info("Makie/Makie is caching fonts, this may take a while. Needed only on first run!")
        load_ascii_chars!(atlas)
        to_cache(atlas) # cache it
        return atlas
    end

    function to_cache(atlas)
        if !ispath(dirname(get_cache_path()))
            mkpath(dirname(get_cache_path()))
        end
        open(get_cache_path(), "w") do io
            dict = Dict(map(fieldnames(typeof(atlas))) do name
                name => getfield(atlas, name)
            end)
            Serialization.serialize(io, dict)
        end
    end

    const global_texture_atlas = Dict{Int, TextureAtlas}()

    function get_texture_atlas()
        return get!(global_texture_atlas, PIXELSIZE_IN_ATLAS[]) do
            return cached_load() # initialize only on demand
        end
    end
end


"""
    find_font_for_char(c::Char, font::NativeFont)
Finds the best font for a character from a list of fallback fonts, that get chosen
if `font` can't represent char `c`
"""
function find_font_for_char(c::Char, font::NativeFont)
    FT_Get_Char_Index(font, c) != 0 && return font
    # it seems that linebreaks are not found which messes up font metrics
    # if another font is selected just for those chars
    c in ('\n', '\r', '\t') && return font
    for afont in alternativefonts()
        if FT_Get_Char_Index(afont, c) != 0
            return afont
        end
    end
    error("Can't represent character $(c) with any fallback font nor $(font.family_name)!")
end

function glyph_index!(atlas::TextureAtlas, c::Char, font::NativeFont)
    if FT_Get_Char_Index(font, c) == 0
        for afont in alternativefonts()
            if FT_Get_Char_Index(afont, c) != 0
                font = afont
            end
        end
    end
    return insert_glyph!(atlas, c, font)
end


function glyph_uv_width!(atlas::TextureAtlas, c::Char, font::NativeFont)
    return atlas.uv_rectangles[glyph_index!(atlas, c, font)]
end

function glyph_uv_width!(c::Char)
    return glyph_uv_width!(get_texture_atlas(), c, defaultfont())
end

function glyph_boundingbox(c::Char, font::NativeFont, pixelsize)
    if FT_Get_Char_Index(font, c) == 0
        for afont in alternativefonts()
            if FT_Get_Char_Index(afont, c) != 0
                font = afont
                break
            end
        end
    end
    bb, ext = FreeTypeAbstraction.metrics_bb(c, font, pixelsize)
    return bb
end

function insert_glyph!(atlas::TextureAtlas, glyph::Char, font::NativeFont)
    return get!(atlas.mapping, (glyph, FreeTypeAbstraction.fontname(font))) do
        downsample = 5 # render font 5x larger, and then downsample back to desired pixelsize
        pad = 8 # padd rendered font by 6 pixel in each direction
        uv_pixel = render(atlas, glyph, font, downsample, pad)
        tex_size = Vec2f(size(atlas.data) .- 1) # starts at 1

        idx_left_bottom = minimum(uv_pixel)# 0 based!!!
        idx_right_top = maximum(uv_pixel)

        # include padding
        left_bottom_pad = idx_left_bottom .+ pad .- 1
        # -1 for indexing offset
        right_top_pad = idx_right_top .- pad

        # transform to normalized texture coordinates
        uv_left_bottom_pad = (left_bottom_pad) ./ tex_size
        uv_right_top_pad =  (right_top_pad) ./ tex_size

        uv_offset_rect = Vec4f(uv_left_bottom_pad..., uv_right_top_pad...)
        i = atlas.index
        push!(atlas.uv_rectangles, uv_offset_rect)
        atlas.index = i + 1
        return i
    end
end

"""
    sdistancefield(img, downsample, pad)
Calculates a distance fields, that is downsampled `downsample` time,
with a padding applied of `pad`.
The padding is in units after downscaling!
"""
function sdistancefield(img, downsample, pad)
    # we pad before downsampling, so we need to have `downsample` as much padding
    pad = downsample * pad
    # padd the image
    padded_size = size(img) .+ 2pad

    # for the downsampling, we need to make sure that
    # we can divide the image size by `downsample` without reminder
    dividable_size = ceil.(Int, padded_size ./ downsample) .* downsample

    in_or_out = fill(false, dividable_size)
    # the size we fill the image up to
    wend, hend = size(img) .+ pad
    in_or_out[pad+1:wend, pad+1:hend] .= img .> (0.5 * 255)

    yres, xres = dividable_size .÷ downsample
    # divide by downsample to normalize distances!
    return Float16.(sdf(in_or_out, xres, yres) ./ downsample)
end

const font_render_callbacks = Dict{Int, Vector{Function}}()

function font_render_callback!(f)
    funcs = get!(font_render_callbacks, PIXELSIZE_IN_ATLAS[], Function[])
    push!(funcs, f)
end

function remove_font_render_callback!(f)
    for (s, callbacks) in font_render_callbacks
        filter!(f2-> f2 != f, callbacks)
    end
end

function render(atlas::TextureAtlas, glyph::Char, font, downsample=5, pad=6)
    #select_font_face(cc, font)
    if glyph == '\n' # don't render  newline
        glyph = ' '
    end
    # the target pixel size of our distance field
    pixelsize = PIXELSIZE_IN_ATLAS[]
    # we render the font `downsample` sizes times bigger
    # Make sure the font doesn't have a mutated font matrix from e.g. Cairo
    FreeTypeAbstraction.FreeType.FT_Set_Transform(font, C_NULL, C_NULL)
    bitmap, extent = renderface(font, glyph, pixelsize * downsample)
    # Our downsampeld & padded distancefield
    sd = sdistancefield(bitmap, downsample, pad)
    rect = Rect2(0, 0, size(sd)...)
    uv = push!(atlas.rectangle_packer, rect) # find out where to place the rectangle
    uv == nothing && error("texture atlas is too small. Resizing not implemented yet. Please file an issue at Makie if you encounter this") #TODO resize surface
    # write distancefield into texture
    atlas.data[uv.area] = sd
    for f in get(font_render_callbacks, pixelsize, ())
        # update everyone who uses the atlas image directly (e.g. in GLMakie)
        f(sd, uv.area)
    end
    # return the area we rendered into!
    return uv.area
end
