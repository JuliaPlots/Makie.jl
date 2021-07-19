#=
Buffers are just normal plots, with the benefit of being setup correctly to
efficiently append + push new values to them
=#

function LinesegmentBuffer(
        scene::SceneLike, ::Type{Point{N}} = Point{2};
        color = RGBAf[], linewidth = Float32[], raw = true,
        kw_args...
    ) where N
    linesegments!(
        scene, Point{N, Float32}[]; color = color,
        linewidth = linewidth, raw = raw, kw_args...
    )
end

function append!(lsb::LineSegments, positions::Vector{Point{N, Float32}}; color = :black, linewidth = 1.0) where N
    thickv = same_length_array(positions, linewidth, key"linewidth"())
    colorv = same_length_array(positions, color, key"color"())
    append!(lsb[1][], positions)
    append!(lsb[:color][], colorv)
    append!(lsb[:linewidth][], thickv)
    return
end

function push!(tb::LineSegments, positions::Point{N, Float32}; kw_args...) where N
    append!(tb, [positions]; kw_args...)
end

function start!(lsb::LineSegments)
    resize!(lsb[1][], 0)
    resize!(lsb[:color][], 0)
    resize!(lsb[:linewidth][], 0)
    return
end

function finish!(lsb::LineSegments)
    # update the signal!
    lsb[1][] = lsb[1][]
    lsb[:color][] = lsb[:color][]
    lsb[:linewidth][] = lsb[:linewidth][]
    return
end

function TextBuffer(
        scene::SceneLike, ::Type{Point{N}} = Point{2};
        rotation = [Quaternionf(0,0,0,1)],
        color = RGBAf[RGBAf(0,0,0,0)],
        textsize = Float32[0],
        font = [defaultfont()],
        align = [Vec2f(0)],
        raw = true,
        kw_args...
    ) where N
    annotations!(
        scene, String[" "], [Point{N, Float32}(0)];
        rotation = rotation,
        color = color,
        textsize = textsize,
        font = font,
        align = align,
        raw = raw,
        kw_args...
    )
end

function start!(tb::Annotations)
    for key in (1, :color, :rotation, :textsize, :font, :align)
        empty!(tb[key][])
    end
    return
end

function finish!(tb::Annotations)
    # update the signal!
    # now update all callbacks
    # TODO this is a bit shaky, buuuuhut, in theory the whole lift(color, ...)
    # in basic_recipes annotations should depend on all signals here, so updating one should be enough
    if length(tb[1][]) != length(tb.textsize[])
        error("Inconsistent buffer state for $(tb[1][])")
    end
    notify(tb[1])
    return
end


function push!(tb::Annotations, text::String, position::VecTypes{N}; kw_args...) where N
    append!(tb, [(String(text), Point{N, Float32}(position))]; kw_args...)
end

function append!(tb::Annotations, text::Vector{String}, positions::Vector{Point{N, Float32}}; kw_args...) where N
    text_positions = convert_argument(Annotations, text, positions)[1]
    append!(tb, text_positions; kw_args...)
    return
end

function append!(tb::Annotations, text_positions::Vector{Tuple{String, Point{N, Float32}}}; kw_args...) where N
    append!(tb[1][], text_positions)
    kw = Dict(kw_args)
    for key in (:color, :rotation, :textsize, :font, :align)
        val = get(kw, key) do
            isempty(tb[key][]) && error("please provide default for $key")
            return last(tb[key][])
        end
        val_vec = same_length_array(text_positions, val, Key{key}())
        append!(tb[key][], val_vec)
    end
    return
end
