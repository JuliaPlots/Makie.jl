@plottype mutable struct Lines{N} <: AbstractPlot{Any}
    position::AbstractVector{Point{N,Float32}}
    color::ColorType = :black
    linewidth::TorVector{Float32} = 1.0
    linestyle::Union{Nothing, Vector{Float32}} = nothing

    cycle::Vector{Symbol} = [:color]
    anti_aliasing::AntiAliasing = NOAA
    inspectable::Bool = true
    visible::Bool = true
end

function lines(args...; attributes...)
    plot(Lines, args...; attributes...)
end

function lines!(args...; attributes...)
    plot!(Lines, args...; attributes...)
end

export lines, lines!, Lines

@plottype mutable struct LineSegments{N} <: AbstractPlot{Any}
    position::AbstractVector{Point{N,Float32}}
    color::ColorType = :black
    linewidth::TorVector{Float32} = 1.0
    linestyle::Union{Nothing, Vector{Float32}} = nothing

    cycle::Vector{Symbol} = [:color]
    anti_aliasing::AntiAliasing = NOAA
    inspectable::Bool = true
    visible::Bool = true
end

function linesegments(args...; attributes...)
    plot(LineSegments, args...; attributes...)
end

function linesegments!(args...; attributes...)
    plot!(LineSegments, args...; attributes...)
end

export linesegments, linesegments!, LineSegments
