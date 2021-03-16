
using Test, ParameterizedNotebooks

nb = ParameterizedNotebook("../examples/example.ipynb")
@test nb.parameters == [:seed]
@test_throws Exception nb()
@test [nb(;seed=seed) for seed in 1:4] == [1,4,9,16]
