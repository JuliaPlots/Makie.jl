function theme_black()
    Theme(
        backgroundcolor = :black,
        textcolor = :white,
        linecolor = :white,
        Axis = (
            backgroundcolor = :transparent,
            bottomspinecolor = :white,
            topspinecolor = :white,
            leftspinecolor = :white,
            rightspinecolor = :white,
            xgridcolor = RGBAf0(1, 1, 1, 0.16),
            ygridcolor = RGBAf0(1, 1, 1, 0.16),
            xtickcolor = :white,
            ytickcolor = :white,
        ),
        Legend = (
            framecolor = :white,
            bgcolor = :black,
        ),
        Axis3 = (
            xgridcolor = RGBAf0(1, 1, 1, 0.16),
            ygridcolor = RGBAf0(1, 1, 1, 0.16),
            zgridcolor = RGBAf0(1, 1, 1, 0.16),
            xspinecolor = :white,
            yspinecolor = :white,
            zspinecolor = :white,
            xticklabelpad = 3,
            yticklabelpad = 3,
            zticklabelpad = 6,
            xtickcolor = :white,
            ytickcolor = :white,
            ztickcolor = :white,
        ),
        Colorbar = (
            tickcolor = :white,
            spinecolor = :white,
            topspinecolor = :white,
            bottomspinecolor = :white,
            leftspinecolor = :white,
            rightspinecolor = :white,
        )
    )
end
