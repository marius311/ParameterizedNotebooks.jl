
using Test, ParameterizedNotebooks
using ParameterizedNotebooks: section_matches

@testset "ParameterizedNotebooks" begin

    @testset "Example notebook" begin

        nb = ParameterizedNotebook("../examples/example.ipynb")
        @test nb.parameters == [:seed]
        @test_throws Exception nb()
        @test [nb(;seed=seed) for seed in 1:4] == [1,4,9,16]

    end

    @testset "Section matching" begin

        # not matching
        @test !section_matches(("~","A","B"), "C", recursive=false)
        @test !section_matches(("~","A","B"), "C", recursive=false)
        # recursive vs. non-recursive
        @test  section_matches(("~","A","B"), "B", recursive=true)
        @test  section_matches(("~","A","B"), "A", recursive=true)
        @test  section_matches(("~","A","B"), "B", recursive=false)
        @test !section_matches(("~","A","B"), "A", recursive=false)
        # string matches entire section only    
        @test !section_matches(("~","AA","BB"), "B", recursive=true)
        @test !section_matches(("~","AA","BB"), "A", recursive=true)
        # regex
        @test  section_matches(("~","AA","BB"), r"B", recursive=true)
        @test  section_matches(("~","AA","BB"), r"A", recursive=true)
        @test  section_matches(("~","AA","BB"), r"B", recursive=false)
        @test !section_matches(("~","AA","BB"), r"A", recursive=false)
        @test !section_matches(("~","AA","BB"), r"C", recursive=false)
        @test !section_matches(("~","AA","BB"), r"C", recursive=false)
        
    end

end