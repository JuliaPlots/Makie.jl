
"""
VolumeSlices

    volumeslices(x, y, z, v)

Draws heatmap slices of the volume v

## Attributes
$(ATTRIBUTES)
"""
@recipe(VolumeSlices, x, y, z, volume) do scene
    Attributes(
        colorrange = automatic,
        heatmap = Attributes(),
    )
end

function plot!(plot::VolumeSlices)
    @extract plot (x, y, z, volume)
    replace_automatic!(plot, :colorrange) do
        map(extrema, volume)
    end
    hattributes = plot[:heatmap]
    hattributes[:colorrange] = plot[:colorrange][]
    mx, Mx = extrema(x[])
    my, My = extrema(y[])
    mz, Mz = extrema(z[])
    v = (  # vertices
        (mx, my, mz), (Mx, my, mz), (mx, My, mz), (mx, my, Mz),
        (Mx, My, mz), (Mx, my, Mz), (mx, My, Mz), (Mx, My, Mz)
    )
    s = [  # segments
        v[1], v[2], v[1], v[3], v[1], v[4], v[2], v[5],
        v[2], v[6], v[3], v[5], v[3], v[7], v[5], v[8],
        v[4], v[6], v[4], v[7], v[6], v[8], v[7], v[8],
    ]
    # bounding box
    col = RGBAf(.5, .5, .5, .5)
    linesegments!(plot, getindex.(s, 1), getindex.(s, 2), getindex.(s, 3), color=col)

    axes = :x, :y, :z
    for (ax, p, r, (X, Y)) ∈ zip(axes, (:yz, :xz, :xy), (x, y, z), ((y, z), (x, z), (x, y)))
        hmap = heatmap!(plot, hattributes, X, Y, zeros(length(X[]), length(Y[])))
        plot[Symbol(:update_, p)] = i -> begin
            transform!(hmap, (p, r[][i]))
            indices = ntuple(Val(3)) do j
                axes[j] == ax ? i : (:)
            end
            hmap[3][] = view(volume[], indices...)
        end
    end
    plot
end
