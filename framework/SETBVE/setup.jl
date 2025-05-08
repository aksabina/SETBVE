using Pkg
Pkg.activate(@__DIR__)      # activates the folder where the file lives
Pkg.instantiate()           # downloads the exact versions in Manifest.toml
Pkg.add("StatsBase")
Pkg.add("Random")
Pkg.add("Statistics")   
Pkg.add("StringDistances")  
Pkg.add("Printf")   
Pkg.add("Plots")
Pkg.add("Distances")
Pkg.add("Dates")
Pkg.add("CSV")
Pkg.add("DataFrames")
Pkg.add("ProgressMeter")
