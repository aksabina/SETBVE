# Running SETBVE from Julia code: registering SUTs and behavioural descriptors, and one search on a SUT, as one run
# of main.jl does

"""
    register_descriptor!(name, f)

Add a behavioural descriptor called `name`. `f(i1, i2, output1, output2)` gets a pair's inputs (two vectors) and its
outputs, and returns an integer bin; the archive keeps the best pair for each combination of bins. It is used both
when solutions are evaluated and when the Tracer's solutions are added to the archive.
"""
function register_descriptor!(name::AbstractString, f)
    behav_desc_functions_dic[String(name)] = f
    return String(name)
end

"""
    register_sut!(name, f, n_inputs; descriptors=["validity_group", "oan", "in_length_var", "in_length_total"],
                  bounds=nothing, numeric_outputs=false, output_distance=nothing, input_distance=nothing)

Add a SUT called `name`. `f(inputs)` gets a vector of `n_inputs` integers and returns the output; an error it throws
counts as an invalid output. `descriptors` names the behavioural descriptors that spread the archive: built-in ones
or ones added with `register_descriptor!`.

`bounds = (lower, upper)`, two vectors of `n_inputs` integers, limits input k to `lower[k]:upper[k]`: the Sampler,
the Explorer's mutations and the Tracer then stay within them, instead of searching the whole integer range.

A pair's score, its program derivative, is how far apart its outputs are divided by how far apart its inputs are. By
default these are SETBVE's: a string distance between the outputs, and the Euclidean distance between the inputs.
- `numeric_outputs=true`: `f` returns numbers (or their text), and the outputs' distance is their absolute difference.
- `output_distance(o1, o2)`: your own distance between two outputs (numbers if `numeric_outputs`, else as `f` returns
  them).
- `input_distance(i1, i2)`: your own distance between the pair's two input vectors.
A pair with an error output is always scored by SETBVE's own program derivative.
"""
function register_sut!(name::AbstractString, f, n_inputs::Integer;
                       descriptors=["validity_group", "oan", "in_length_var", "in_length_total"], bounds=nothing,
                       numeric_outputs::Bool=false, output_distance=nothing, input_distance=nothing)
    unknown = filter(d -> !haskey(behav_desc_functions_dic, d), descriptors)
    isempty(unknown) || error("Unknown behavioural descriptors: $(join(unknown, ", ")) (see register_descriptor!)")
    if bounds !== nothing
        lower, upper = BigInt.(bounds[1]), BigInt.(bounds[2])
        length(lower) == length(upper) == n_inputs || error("bounds need $n_inputs lower and $n_inputs upper values")
        all(lower .<= upper) || error("each lower bound must be at most its upper bound")
    end
    name = String(name)
    sut_functions_dic[name] = f
    total_args_num[name] = 2 * n_inputs
    behavioural_descriptors[name] = collect(String, descriptors)
    if bounds === nothing
        delete!(input_bounds, name)
    else
        input_bounds[name] = InputBounds(lower, upper)
    end
    if numeric_outputs || output_distance !== nothing || input_distance !== nothing
        sut_distances[name] = (numeric_outputs=numeric_outputs, output_distance=output_distance,
                               input_distance=input_distance)
    else
        delete!(sut_distances, name)
    end
    return name
end

"""
    run_search(sut_name, duration=0; max_evaluations=0, emitter="Mutation", selection="Curiosity",
               tracer_budget=0.0, vary=nothing, categorical=Int[], log_evaluations=false, seed=nothing, run_num=1)
        -> (archive=DataFrame, with_tracer=DataFrame or nothing, evaluations=DataFrame or nothing)

Run one SETBVE search on the SUT `sut_name`, for `duration` seconds or for `max_evaluations` evaluations:

- the Sampler fills the archive with random solutions for a share `bituniform_init_budget_ratio` of the budget
  (skipped for the Bituniform and Random emitters);
- the Explorer generates new solutions with `emitter` ("Mutation", "Bituniform" or "Random"); for "Mutation",
  `selection` ("Uniform", "Fitness" or "Curiosity") chooses the parents, otherwise it is "NoSelection";
- the Tracer, given a share `tracer_budget` of the time (0 disables it), searches locally around the best
  boundary candidates.

Give either a `duration` or `max_evaluations`. One evaluation is one pair of inputs, so it runs the SUT twice. With
`max_evaluations`, the search stops after exactly that many evaluations, whatever the machine's speed, and with a
`seed` it is repeatable; the Tracer's budget is in seconds, so it must then be off.

`vary`, a list of input indices (1-based), makes every pair vary only those inputs: the pair's two inputs are equal in
all the others, in the Sampler's, the Explorer's and the Tracer's pairs alike. A pair then shows what changing those
inputs alone does, and its program derivative is their local effect. It needs the SUT's input bounds. With `vary`,
the "Mutation" emitter moves a pair either along an input it holds equal or along a varied input, and the
"Bituniform" and "Random" emitters draw such pairs uniformly. `categorical` lists inputs whose values have no order
(codes for categories): the mutation moves them to any value rather than nearby.

`seed`, if given, seeds Julia's random number generator first. `run_num` only numbers the output files.

The archive is written as CSV under the output directory (see `set_output_dir!`), as main.jl writes it, and returned
as DataFrames: `archive` holds the Sampler's and Explorer's solutions, `with_tracer` adds the Tracer's (`nothing` when
`tracer_budget` is 0).

With `log_evaluations=true`, `evaluations` is every pair the Sampler and the Explorer evaluated, in order: its number,
the phase ("sampler" or "explorer"), its inputs (`i1_k`, `i2_k`), outputs, fitness, and what it did to the archive
("new cell", "better" or "no update"). Unlike the archive, it keeps the pairs that the archive later replaced or never
took. The Tracer's own trials aren't logged.
"""
function run_search(sut_name::String, duration::Integer=0; max_evaluations::Integer=0, emitter::String="Mutation",
                    selection::String="Curiosity", tracer_budget::Real=0.0, vary=nothing,
                    categorical::AbstractVector{<:Integer}=Int[], log_evaluations::Bool=false,
                    seed::Union{Nothing,Integer}=nothing, run_num::Integer=1)
    haskey(sut_functions_dic, sut_name) || error("Unknown SUT $sut_name: register it first (see register_sut!)")
    (duration > 0) != (max_evaluations > 0) || error("give either a duration in seconds or max_evaluations")
    max_evaluations > 0 && tracer_budget > 0 &&
        error("with max_evaluations, the Tracer (whose budget is in seconds) must be off: set tracer_budget=0")
    if seed !== nothing
        Random.seed!(seed)
    end
    emitter_type, bias_column, local_search_budget_ratio = emitter, selection, tracer_budget
    descriptors = behavioural_descriptors[sut_name]
    args_num = total_args_num[sut_name]

    sampler_phase = emitter_type != "Bituniform" && emitter_type != "Random"  # those emitters already sample at random
    init_duration = sampler_phase ? bituniform_init_budget_ratio * duration : 0
    local_search_duration = local_search_budget_ratio * duration

    bounds = get(input_bounds, sut_name, nothing)
    vector_input = sut_name == "element_at_position" || occursin("normalize", sut_name)
    if vector_input && bounds !== nothing
        error("Input bounds are only supported for SUTs with integer inputs")
    end
    n_inputs = args_num ÷ 2
    if vary !== nothing
        vary = collect(Int, vary)
        bounds === nothing && error("`vary` needs the SUT's input bounds (see register_sut!)")
        !isempty(vary) && all(k -> 1 <= k <= n_inputs, vary) || error("`vary` needs input indices from 1 to $n_inputs")
    end
    categorical = collect(Int, categorical)
    isempty(categorical) || vary !== nothing || error("`categorical` only applies with `vary`")

    archive = IntGridArchive{S,Evaluation}(Int8(1))
    evaluator = Evaluator()
    if vary !== nothing && emitter_type == "Mutation"
        explorer = VaryMutateEmitter(archive, bias_column, bounds, vary, categorical, default_parent_id, default_parent_id)
    elseif vary !== nothing && emitter_type in ("Bituniform", "Random")
        explorer = VaryUniformEmitter(bounds, vary, default_parent_id, default_parent_id)
    elseif emitter_type == "Mutation"
        if occursin("normalize", sut_name)
            # use the vector-specific emitter
            explorer = MutateVectorEmitter(archive, bias_column, default_parent_id, default_parent_id)
        else
            explorer = MutateEmitter(archive, bias_column, default_parent_id, default_parent_id, bounds)
        end
    elseif emitter_type == "Bituniform"
        explorer = BitUniformRandomEmitter(args_num, default_parent_id, default_parent_id, bounds)
    elseif emitter_type == "Random"
        explorer = RandomEmitter(args_num, default_parent_id, default_parent_id, bounds)
    else
        error("Unknown emitter $emitter_type: use Mutation, Bituniform or Random")
    end
    optimizer = DefaultOptimizer(batch_size, archive, explorer, evaluator)

    if vary !== nothing
        sampler = VaryUniformEmitter(bounds, vary, default_parent_id, default_parent_id)
    elseif vector_input
        sampler = BitUniformVectorRandomEmitter(args_num, default_parent_id, default_parent_id)
    else
        sampler = BitUniformRandomEmitter(args_num, default_parent_id, default_parent_id, bounds)
    end
    optimiser_init = DefaultOptimizer(batch_size, archive, sampler, evaluator)

    evaluation_log[] = log_evaluations ? Dict{String,Any}[] : nothing
    evaluations = nothing
    try
        if max_evaluations > 0
            # The same phases, budgeted in evaluations (SETBVE's batch size is 1): the Sampler gets its usual share
            n_init = sampler_phase ? round(Int, bituniform_init_budget_ratio * max_evaluations) : 0
            for _ in 1:n_init
                evaluation_phase[] = "sampler"
                emit_solutions(optimiser_init, sut_name, descriptors)
            end
            for _ in 1:(max_evaluations - n_init)
                evaluation_phase[] = "explorer"
                emit_solutions(optimizer, sut_name, descriptors)
            end
        else
            # Sampler: init archive with random solutions for the specified time (skipped for Bituniform and Random emitters)
            start_time = time() * 1_000_000  # microseconds
            while (time() * 1_000_000 - start_time) < init_duration * 1_000_000
                evaluation_phase[] = "sampler"
                emit_solutions(optimiser_init, sut_name, descriptors)
            end

            # Explorer
            emit_solutions_dur = (duration - init_duration - local_search_duration) * 1_000_000
            start_time = time() * 1_000_000
            while (time() * 1_000_000 - start_time) < emit_solutions_dur
                evaluation_phase[] = "explorer"
                emit_solutions(optimizer, sut_name, descriptors)
            end
        end

        evaluations = log_evaluations ? evaluation_table(evaluation_log[]) : nothing
    finally
        evaluation_log[] = nothing
    end

    # output files are named by the budget: the duration, or the evaluations (e.g. "1000evals")
    budget = max_evaluations > 0 ? "$(max_evaluations)evals" : duration
    df = save_archive_to_csv(archive, descriptors, sut_name, emitter_type, bias_column, budget, run_num, local_search_budget_ratio)
    if local_search_budget_ratio == 0
        return (archive=df, with_tracer=nothing, evaluations=evaluations)
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
                _, local_search_dataframe = local_search_iteration(group, first_rows[group], rows_num[group], sorted_df, i_columns, duration_ms_per_row, sut_name, local_search_dataframe; vary=vary)
                if group != "EE" && (time() * 1_000_000 - start_time) > local_search_duration * 1_000_000
                    break
                end
            end
            (time() * 1_000_000 - start_time) > local_search_duration * 1_000_000 && break
        end
    end

    local_search_dataframe = unique(local_search_dataframe, i_columns)  # drop duplicates
    df_all = append_archive_with_local_search_sols(df, local_search_dataframe, sut_name, emitter_type, bias_column, duration, run_num, local_search_budget_ratio)
    return (archive=df, with_tracer=df_all, evaluations=evaluations)
end
