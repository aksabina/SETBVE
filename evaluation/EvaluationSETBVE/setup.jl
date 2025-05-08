using Pkg     
Pkg.activate(@__DIR__)      # activates the folder where the file lives
Pkg.instantiate()           # downloads the exact versions in Manifest.toml
Pkg.add("Glob")
Pkg.add("Statistics")    
Pkg.add("Plots")
Pkg.add("CSV")
Pkg.add("DataFrames")
Pkg.add("StatsBase")
Pkg.add("ProgressMeter")
Pkg.add("DataStructures")
Pkg.add("StringDistances")
Pkg.add("Distances")
Pkg.add("Printf")

