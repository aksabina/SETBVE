using Pkg
Pkg.activate(joinpath(@__DIR__, "env"))  # main.jl's environment
Pkg.develop(path=@__DIR__)                # SETBVE itself, from this folder (also for Julia before 1.11)
Pkg.instantiate()                         # Plots, PyCall and the other packages main.jl uses
