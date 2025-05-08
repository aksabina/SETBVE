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

init_duration = (emitter_type!="Bituniform" && emitter_type!="Random") ? Integer(bituniform_init_budget_ratio * total_duration) : 0  
local_search_duration = Integer(local_search_budget_ratio * total_duration) # n% of the total time

# Prepare a container for results
results_global_search = Vector{Tuple{Int, DataFrame}}()
results_global_search_lock = ReentrantLock()
results_local_search = Vector{Tuple{Int, DataFrame}}()
results_local_search_lock = ReentrantLock()

#@threads for run_num in 1:number_of_runs
for run_num in 1:number_of_runs

    printstyled("$(total_duration)-$(run_num)-$(sut_name): $(emitter_type)-$(local_search_budget_ratio), $(bias_column)\n", color=:blue)
    archive, evaluator, emitter, optimizer, optimiserInit, emitterInit, df = nothing, nothing, nothing, nothing, nothing, nothing, nothing  # re-init to ensure everything is empty 

    # Re-Initializing variables 
    archive = (archive === nothing) ? IntGridArchive{S,Evaluation}(Int8(1)) : error("Archive must be empty at the beginning of a loop")
    evaluator = (evaluator === nothing) ? Evaluator() : error("Evaluator must be empty at the beginning of a loop")

    if emitter_type == "Mutation"
        emitter = (emitter === nothing) ? MutateEmitter(archive, bias_column, default_parent_id, default_parent_id) : error("Emitter must be empty at the beginning of a loop")
    elseif emitter_type == "Bituniform"
        emitter = (emitter === nothing) ? BitUniformRandomEmitter(total_args_num[sut_name], default_parent_id, default_parent_id) : error("Emitter must be empty at the beginning of a loop")
    elseif emitter_type == "Random"
        emitter = (emitter === nothing) ? RandomEmitter(total_args_num[sut_name], default_parent_id, default_parent_id) : error("Emitter must be empty at the beginning of a loop")
    end

    optimizer = (optimizer === nothing) ? DefaultOptimizer(batch_size, archive, emitter, evaluator) : error("Optimiser must be empty at the beginning of a loop")
    
    emitterInit = (emitterInit === nothing) ? BitUniformRandomEmitter(total_args_num[sut_name], default_parent_id, default_parent_id) : error("EmitterInit must be empty at the beginning of a loop")
    optimiserInit = (optimiserInit === nothing) ? DefaultOptimizer(batch_size, archive, emitterInit, evaluator) : error("OptimiserInit must be empty at the beginning of a loop")

    start_time = time() * 1_000_000  # microseconds
    # init archive with random solutions for specified time
    # initialization is skipped for Bituniform and Random emitters
    global elapsed_ts_init = 0
    while (time() * 1_000_000 - start_time) < init_duration * 1_000_000
        elapsed_ts_init = time() * 1_000_000 - start_time
        emit_solutions(optimiserInit, sut_name, behavioural_descriptors[sut_name])
    end
 
    emit_solutions_dur = (total_duration - init_duration - local_search_duration) * 1_000_000 
    start_time = time() * 1_000_000  # milliseconds
    while (time() * 1_000_000 - start_time) < emit_solutions_dur
        global elapsed_ts_emit = elapsed_ts_init + time() * 1_000_000 - start_time
        emit_solutions(optimizer, sut_name, behavioural_descriptors[sut_name])
    end

    # save and plot the results without local search
    df = save_archive_to_csv(archive, behavioural_descriptors[sut_name], sut_name, emitter_type, bias_column, total_duration, run_num, local_search_budget_ratio)
    push!(results_global_search, (run_num, df))
    # Lock and push the run number and DataFrame into the shared vector
    # lock(results_global_search_lock) do
    #     push!(results_global_search, (run_num, df))
    # end

    # local search: Phase 2
    if local_search_budget_ratio != 0
        i_columns = filter(c -> startswith(String(c), "i"), names(df))  # get names of input columns

        local_search_dataframe = DataFrame([Symbol(col) => [] for col in i_columns])  # create an empty dataframe
        elapsed_ts_total = elapsed_ts_init + elapsed_ts_emit

        df[!, :bd_validity_group] .= Int64.(df[!, :bd_validity_group]) 
        df[!, :fitness] .= Float64.(df[!, :fitness]) 

        # Sort dataframe by bd_validity_group and fitness in descending order
        # validity group is in the descending order because otherwise there will be no solutions to compute the delta from 
        sorted_df = sort(df, [:bd_validity_group, :fitness], rev=[true, true]) 

        # Precompute the first row numbers for each validity group
        first_rows = Dict(
            "VV" => findfirst(row -> row[:bd_validity_group] == 0, eachrow(sorted_df)),
            "VE" => findfirst(row -> row[:bd_validity_group] == 1, eachrow(sorted_df)),
            "EE" => findfirst(row -> row[:bd_validity_group] == 2, eachrow(sorted_df))
        )

        # Precompute rows per group
        vv_rows_df = filter(row -> row[:bd_validity_group] == 0, sorted_df)
        ve_rows_df = filter(row -> row[:bd_validity_group] == 1, sorted_df)
        ee_rows_df = filter(row -> row[:bd_validity_group] == 2, sorted_df)

        vv_rows_num, ve_rows_num, ee_rows_num = get_local_search_rows_num_per_validity_group(sorted_df)

        duration_ms_per_row = round(Int, (local_search_duration * 1_000_000) / (vv_rows_num+ve_rows_num+ee_rows_num))

        # Start the local search process
        total_rows = 0
        start_time = time() * 1_000_000  # milliseconds

        while (time() * 1_000_000 - start_time) < local_search_duration * 1_000_000
            elapsed_ts_total += time() * 1_000_000 - start_time

            add_rows, local_search_dataframe = local_search_iteration("VV", first_rows["VV"], vv_rows_num, sorted_df, i_columns, duration_ms_per_row, sut_name, local_search_dataframe)
            total_rows += add_rows
            elapsed_ts_total += time() * 1_000_000 - start_time

            if (time() * 1_000_000 - start_time) > local_search_duration * 1_000_000
                break
            end

            add_rows, local_search_dataframe = local_search_iteration("VE", first_rows["VE"], ve_rows_num, sorted_df, i_columns, duration_ms_per_row, sut_name, local_search_dataframe)
            total_rows += add_rows
            elapsed_ts_total += time() * 1_000_000 - start_time

            if (time() * 1_000_000 - start_time) > local_search_duration * 1_000_000
                break
            end

            add_rows, local_search_dataframe = local_search_iteration("EE", first_rows["EE"], ee_rows_num, sorted_df, i_columns, duration_ms_per_row, sut_name, local_search_dataframe)
            total_rows += add_rows
            elapsed_ts_total += time() * 1_000_000 - start_time
            
        end

        local_search_dataframe = unique(local_search_dataframe, i_columns)  #drop duplicates
        df_all = append_archive_with_local_search_sols(df, local_search_dataframe, sut_name, emitter_type, bias_column, total_duration, run_num, local_search_budget_ratio)
        push!(results_local_search, (run_num, df_all))
        # Lock and push the run number and DataFrame into the shared vector
        # lock(results_local_search_lock) do
        #     push!(results_local_search, (run_num, df_all))
        # end
        
    end
end 

# Plot results outside the @threads loop 
println("Plotting results outside threads: without Tracer")
for (run_num, df) in results_global_search
    if sut_name == "bmi" || sut_name == "circle" || sut_name == "two_circles"
        printstyled("$(total_duration)-$(run_num)-$(sut_name): $(emitter_type), $(bias_column)\n", color=:orange)
        plot_zoomed_scatter(df, sut_name, emitter_type, bias_column, total_duration, false, "", run_num, local_search_budget_ratio)
    end
end

if local_search_budget_ratio != 0
    println("Plotting results outside threads: with Tracer")
    for (run_num, df_all) in results_local_search
        if sut_name == "bmi" || sut_name == "circle" || sut_name == "two_circles"
            printstyled("$(total_duration)-$(run_num)-$(sut_name): $(emitter_type), $(bias_column)\n", color=:orange)
            plot_zoomed_scatter(df_all, sut_name, emitter_type, bias_column, total_duration, false, "Tracer", run_num, local_search_budget_ratio)
        end
    end
end
