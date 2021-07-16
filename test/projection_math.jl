
@testset "Projection math" begin
    @test eltype(Makie.rotationmatrix_x(1)) == Float64
    @test eltype(Makie.rotationmatrix_x(1f0)) == Float32
end
