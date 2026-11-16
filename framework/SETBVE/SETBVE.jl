# SETBVE is a Julia package (Project.toml, src/). This file is for code that includes SETBVE's source instead of
# loading the package (`include("SETBVE.jl"); using .SETBVE`), as earlier versions did: it defines the same module from
# src/. Plotting and the Python SUT are package extensions, so they need SETBVE loaded as a package (`using SETBVE`).
include(joinpath(@__DIR__, "src", "SETBVE.jl"))
