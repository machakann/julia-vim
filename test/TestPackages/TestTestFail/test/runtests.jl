using Test

@testset "TestTestFail" begin
    @test 0 == -1
    @test 0 ==  0
    @test 0 ==  1
end
