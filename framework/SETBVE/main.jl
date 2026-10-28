using Pkg
Pkg.activate(@__DIR__)      # activates the folder where the file lives
Pkg.instantiate()  

include("SETBVE.jl")
using .SETBVE
using Random, CSV, DataFrames, Base.Threads

sut_name = ARGS[1] # bmi, circle, date, bytecount, two_circles, bytecount, power_by_squaring, tailjoin, max, cld, fldmod1, fld
total_duration = parse(Int, ARGS[2])  # 30, 600 in seconds
emitter_type = ARGS[3]  # Mutation, Bituniform, Random
bias_column = ARGS[4]  # Fitness, Uniform, Curiosity, NoSelection (Random, Bituniform)
local_search_budget_ratio = parse(Float64, ARGS[5])  # 0, 0.1, 0.5
seed = length(ARGS) >= 6 ? parse(Int, ARGS[6]) : nothing  # optional: run k is seeded with seed + k - 1

# Prepare a container for results
results_global_search = Vector{Tuple{Int, DataFrame}}()
results_local_search = Vector{Tuple{Int, DataFrame}}()

for run_num in 1:number_of_runs
    printstyled("$(total_duration)-$(run_num)-$(sut_name): $(emitter_type)-$(local_search_budget_ratio), $(bias_column)\n", color=:blue)
    run_seed = (seed === nothing) ? nothing : seed + run_num - 1
    result = run_search(sut_name, total_duration; emitter=emitter_type, selection=bias_column,
                        tracer_budget=local_search_budget_ratio, seed=run_seed, run_num=run_num)
    push!(results_global_search, (run_num, result.archive))
    if result.with_tracer !== nothing
        push!(results_local_search, (run_num, result.with_tracer))
    end
end

# Plot results outside the @threads loop (unless SETBVE was loaded without Plots)
plot_suts = SETBVE.WITH_PLOTS ? ["bmi", "circle", "two_circles"] : String[]
println("Plotting results outside threads: without Tracer")
for (run_num, df) in results_global_search
    if sut_name in plot_suts
        printstyled("$(total_duration)-$(run_num)-$(sut_name): $(emitter_type), $(bias_column)\n", color=:orange)
        plot_zoomed_scatter(df, sut_name, emitter_type, bias_column, total_duration, false, "", run_num, local_search_budget_ratio)
    end
end

if local_search_budget_ratio != 0
    println("Plotting results outside threads: with Tracer")
    for (run_num, df_all) in results_local_search
        if sut_name in plot_suts
            printstyled("$(total_duration)-$(run_num)-$(sut_name): $(emitter_type), $(bias_column)\n", color=:orange)
            plot_zoomed_scatter(df_all, sut_name, emitter_type, bias_column, total_duration, false, "Tracer", run_num, local_search_budget_ratio)
        end
    end
end
