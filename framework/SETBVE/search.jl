# Running SETBVE from Julia code: one search on a SUT, as one run of main.jl does

"""
    run_search(sut_name, duration; emitter="Mutation", selection="Curiosity", tracer_budget=0.0,
               seed=nothing, run_num=1) -> (archive=DataFrame, with_tracer=DataFrame or nothing)

Run one SETBVE search on the SUT `sut_name` for `duration` seconds:

- the Sampler fills the archive with random solutions for a share `bituniform_init_budget_ratio` of the time
  (skipped for the Bituniform and Random emitters);
- the Explorer generates new solutions with `emitter` ("Mutation", "Bituniform" or "Random"); for "Mutation",
  `selection` ("Uniform", "Fitness" or "Curiosity") chooses the parents, otherwise it is "NoSelection";
- the Tracer, given a share `tracer_budget` of the time (0 disables it), searches locally around the best
  boundary candidates.

`seed`, if given, seeds Julia's random number generator first. `run_num` only numbers the output files.

The archive is written as CSV under the output directory (see `set_output_dir!`), as main.jl writes it, and returned
as DataFrames: `archive` holds the Sampler's and Explorer's solutions, `with_tracer` adds the Tracer's (`nothing` when
`tracer_budget` is 0).
"""
function run_search(sut_name::String, duration::Integer; emitter::String="Mutation", selection::String="Curiosity",
                    tracer_budget::Real=0.0, seed::Union{Nothing,Integer}=nothing, run_num::Integer=1)
    haskey(sut_functions_dic, sut_name) || error("Unknown SUT $sut_name: register it first (see register_sut!)")
    if seed !== nothing
        Random.seed!(seed)
    end
    emitter_type, bias_column, local_search_budget_ratio = emitter, selection, tracer_budget
    descriptors = behavioural_descriptors[sut_name]
    args_num = total_args_num[sut_name]

    init_duration = (emitter_type != "Bituniform" && emitter_type != "Random") ? bituniform_init_budget_ratio * duration : 0
    local_search_duration = local_search_budget_ratio * duration

    archive = IntGridArchive{S,Evaluation}(Int8(1))
    evaluator = Evaluator()
    if emitter_type == "Mutation"
        if occursin("normalize", sut_name)
            # use the vector-specific emitter
            explorer = MutateVectorEmitter(archive, bias_column, default_parent_id, default_parent_id)
        else
            explorer = MutateEmitter(archive, bias_column, default_parent_id, default_parent_id)
        end
    elseif emitter_type == "Bituniform"
        explorer = BitUniformRandomEmitter(args_num, default_parent_id, default_parent_id)
    elseif emitter_type == "Random"
        explorer = RandomEmitter(args_num, default_parent_id, default_parent_id)
    else
        error("Unknown emitter $emitter_type: use Mutation, Bituniform or Random")
    end
    optimizer = DefaultOptimizer(batch_size, archive, explorer, evaluator)

    if sut_name == "element_at_position" || occursin("normalize", sut_name)
        sampler = BitUniformVectorRandomEmitter(args_num, default_parent_id, default_parent_id)
    else
        sampler = BitUniformRandomEmitter(args_num, default_parent_id, default_parent_id)
    end
    optimiser_init = DefaultOptimizer(batch_size, archive, sampler, evaluator)

    # Sampler: init archive with random solutions for the specified time (skipped for Bituniform and Random emitters)
    start_time = time() * 1_000_000  # microseconds
    while (time() * 1_000_000 - start_time) < init_duration * 1_000_000
        emit_solutions(optimiser_init, sut_name, descriptors)
    end

    # Explorer
    emit_solutions_dur = (duration - init_duration - local_search_duration) * 1_000_000
    start_time = time() * 1_000_000
    while (time() * 1_000_000 - start_time) < emit_solutions_dur
        emit_solutions(optimizer, sut_name, descriptors)
    end

    df = save_archive_to_csv(archive, descriptors, sut_name, emitter_type, bias_column, duration, run_num, local_search_budget_ratio)
    if local_search_budget_ratio == 0
        return (archive=df, with_tracer=nothing)
    end

    # Tracer: local search around the best boundary candidates of each validity group
    i_columns = filter(c -> startswith(String(c), "i"), names(df))  # get names of input columns
    local_search_dataframe = DataFrame([Symbol(col) => [] for col in i_columns])  # create an empty dataframe

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
    rows_num = Dict(zip(("VV", "VE", "EE"), get_local_search_rows_num_per_validity_group(sorted_df)))

    if sum(values(rows_num)) > 0  # an archive can be too small for any local search
        duration_ms_per_row = round(Int, (local_search_duration * 1_000_000) / sum(values(rows_num)))
        start_time = time() * 1_000_000
        while (time() * 1_000_000 - start_time) < local_search_duration * 1_000_000
            for group in ("VV", "VE", "EE")
                _, local_search_dataframe = local_search_iteration(group, first_rows[group], rows_num[group], sorted_df, i_columns, duration_ms_per_row, sut_name, local_search_dataframe)
                if group != "EE" && (time() * 1_000_000 - start_time) > local_search_duration * 1_000_000
                    break
                end
            end
            (time() * 1_000_000 - start_time) > local_search_duration * 1_000_000 && break
        end
    end

    local_search_dataframe = unique(local_search_dataframe, i_columns)  # drop duplicates
    df_all = append_archive_with_local_search_sols(df, local_search_dataframe, sut_name, emitter_type, bias_column, duration, run_num, local_search_budget_ratio)
    return (archive=df, with_tracer=df_all)
end
