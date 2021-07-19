@testset "Quaternions" begin

    qx = qrotation(Vec(1, 0, 0), pi / 4)
    @test qx * qx ≈ qrotation(SVector(1.0, 0.0, 0.0), pi / 2)
    @test Base.power_by_squaring(qx, 2) ≈ qrotation(SVector(1.0, 0.0, 0.0), pi / 2)
    theta = pi / 8
    qx = qrotation(SVector(1.0, 0.0, 0.0), theta)
    c = cos(theta); s = sin(theta)
    Rx = [1 0 0; 0 c -s; 0 s c]

    @test Mat3f(qx) ≈ Rx
    theta = pi / 6
    qy = qrotation(SVector(0.0, 1.0, 0.0), theta)
    c = cos(theta); s = sin(theta)
    Ry = [c 0 s; 0 1 0; -s 0 c]
    @test Mat3f(qy) ≈ Ry
    theta = 4pi / 3
    qz = qrotation(SVector(0.0, 0.0, 1.0), theta)
    c = cos(theta); s = sin(theta)
    Rz = [c -s 0; s c 0; 0 0 1]
    @test Mat3f(qz) ≈ Rz

    @test Mat3f(qx * qy * qz) ≈ Rx * Ry * Rz
    @test Mat3f(qy * qx * qz) ≈ Ry * Rx * Rz
    @test Mat3f(qz * qx * qy) ≈ Rz * Rx * Ry

    a, b = qrotation(SVector(0.0, 0.0, 1.0), deg2rad(0)), qrotation(SVector(0.0, 0.0, 1.0), deg2rad(180))
    # @test slerp(a, b, 0.0) ≈ a
    # @test slerp(a, b, 1.0) ≈ b
    # @test slerp(a, b, 0.5) ≈ qrotation([0, 0, 1], deg2rad(90))
    #
    # @test angle(qrotation(SVector(1.0, 0.0, 0.0), 0)) ≈ 0
    # @test angle(qrotation([0, 1, 0], pi / 4)) ≈ pi / 4
    # @test angle(qrotation([0, 0, 1], pi / 2)) ≈ pi / 2
    #
    # let # test numerical stability of angle
    #     ax = RNG.randn(3)
    #     for θ in [1e-9, π - 1e-9]
    #         q = qrotation(ax, θ)
    #         @test angle(q) ≈ θ
    #     end
    # end
end
