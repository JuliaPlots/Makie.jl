using Makie: PointTrans, xyz_boundingbox, apply_transform

@testset "Basic transforms" begin
    function fpoint2(x::Point2)
        return Point2f(x[1] + 10, x[2] - 77)
    end

    function fpoint3(x::Point3)
        return Point3f(x[1] + 10, x[2] - 77, x[3] /  4)
    end
    trans2 = PointTrans{2}(fpoint2)
    trans3 = PointTrans{3}(fpoint3)
    points2 = [Point2f(0, 0), Point2f(0, 1)]
    bb = xyz_boundingbox(trans2, points2)
    @test bb == Rect(Vec3f(10, -77, 0), Vec3f(0, 1, 0))
    bb = xyz_boundingbox(trans3, points2)
    @test bb == Rect(Vec3f(10, -77, 0), Vec3f(0, 1, 0))

    points3 = [Point3f(0, 0, 4), Point3f(0, 1, -8)]
    bb = xyz_boundingbox(trans2, points3)
    @test bb == Rect(Vec3f(10, -77, -8), Vec3f(0, 1, 12))
    bb = xyz_boundingbox(trans3, points3)
    @test bb == Rect(Vec3f(10, -77, -2.0), Vec3f(0, 1, 3.0))

    @test apply_transform(trans2, points2) == fpoint2.(points2)
    @test apply_transform(trans3, points3) == fpoint3.(points3)

    @test_throws ErrorException PointTrans{2}(x::Int -> x)
    @test_throws ErrorException PointTrans{3}(x::Int -> x)
end


@testset "Tuple and identity transforms" begin
    t1 = sqrt
    t2 = (sqrt, log)
    t3 = (sqrt, log, log10)

    p2 = Point(2.0, 5.0)
    p3 = Point(2.0, 5.0, 4.0)

    @test apply_transform(identity, p2) == p2
    @test apply_transform(identity, p3) == p3

    @test apply_transform(t1, p2) == Point(sqrt(2.0), sqrt(5.0))
    @test apply_transform(t1, p3) == Point(sqrt(2.0), sqrt(5.0), sqrt(4.0))

    @test apply_transform(t2, p2) == Point2f(sqrt(2.0), log(5.0))
    @test apply_transform(t2, p3) == Point3f(sqrt(2.0), log(5.0), 4.0)

    @test apply_transform(t3, p3) == Point3f(sqrt(2.0), log(5.0), log10(4.0))

    i2 = (identity, identity)
    i3 = (identity, identity, identity)
    @test apply_transform(i2, p2) == p2
    @test apply_transform(i3, p3) == p3

    # test that identity gives back exact same arrays without copying
    p2s = Point2f[(1, 2), (3, 4)]
    @test apply_transform(identity, p2s) === p2s
    @test apply_transform(i2, p2s) === p2s
    @test apply_transform(i3, p2s) === p2s

    p3s = Point3f[(1, 2, 3), (3, 4, 5)]
    @test apply_transform(identity, p3s) === p3s
    @test apply_transform(i2, p3s) === p3s
    @test apply_transform(i3, p3s) === p3s

    @test apply_transform(identity, 1) == 1
    @test apply_transform(i2, 1) == 1
    @test apply_transform(i3, 1) == 1

    @test apply_transform(identity, 1..2) == 1..2
    @test apply_transform(i2, 1..2) == 1..2
    @test apply_transform(i3, 1..2) == 1..2

    pa = Point2f(1, 2)
    pb = Point2f(3, 4)
    r2 = Rect2f(pa, pb .- pa)
    @test apply_transform(t1, r2) == Rect2f(apply_transform(t1, pa), apply_transform(t1, pb) .- apply_transform(t1, pa) )
end
