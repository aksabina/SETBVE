
function calculate_archive_coverage(sut_name::String, run_duration::Integer, emitter::String, sampling_strategy::Union{String, Nothing}, 
    refine_budget::Union{Integer, Nothing}, args)
    prefix = args[1]

    rac_stats_per_run = DataFrame()
    run_duration_list = []
    emitter_list = []
    sampling_strategy_list = []
    refine_budget_list = []
    run_number_list = []
    rac_list = []

    if prefix == "UniqueCells" || prefix == "TopRanked"
        all_filename = "AggregatedArchive/AllMethods/$(sut_name)$(prefix).csv" 
        df_all = CSV.read(all_filename, DataFrame, types=String)
    elseif prefix == "NoPD0"
        all_filename = "AggregatedArchive/AllMethods/$(sut_name)UniqueCells.csv" 
        df_all = CSV.read(all_filename, DataFrame, types=String)
        df_all = filter(row -> row[:boundary_rank] != "2", df_all)  # exclude rows with fitness=0
    end
    sorted_column_names = sort(names(df_all))
    df_all = df_all[:, sorted_column_names] # sort column names to make sure that the order of bd columns is correct 

    cell_columns = filter(name -> startswith(name, "bd_"), names(df_all))

    result_df = DataFrame()

    input_directory = get_directory_path(path_archive, sut_name, run_duration, emitter, sampling_strategy, refine_budget)
    list_coverage_percentage = []
    
    pattern = r"_(\d+)\.csv$"
    for file in Glob.glob("*.csv", input_directory)
        m = match(pattern, basename(file))
        if m !== nothing && parse(Int, m.captures[1]) in 1:NUMBER_OF_RUNS

            df = CSV.read(file, DataFrame, types=String)
            sorted_column_names = sort(names(df))
            df = df[:, sorted_column_names] # sort column names to make sure that the order of bd columns is correct 

            if prefix == "NoPD0"
                df = filter(row -> row[:boundary_rank] != "2", df)  # exclude rows with fitness=0
            end

            intersect_count = nrow(DataFrame(intersect(collect(eachrow(df_all[:, cell_columns])), collect(eachrow(df[:, cell_columns])))))
            coverage_percentage = 100 * intersect_count / nrow(df_all)

            push!(list_coverage_percentage, coverage_percentage)
            push!(run_duration_list, run_duration)
            push!(emitter_list, emitter)
            push!(sampling_strategy_list, sampling_strategy)
            push!(refine_budget_list, refine_budget)
            push!(run_number_list, parse(Int, split(split(file, "_")[end], ".")[1]))
            push!(rac_list, coverage_percentage)
        else
            continue
        end
    end

    avg_cov = round(mean(list_coverage_percentage), digits=2)
    std_cov = round(std(list_coverage_percentage), digits=2)

    method = (emitter == "Mutation") ? sampling_strategy : emitter
    trace_budget = (refine_budget == nothing) ? missing : refine_budget

    append!(result_df, DataFrame(Method=method, 
                                TraceBudget=trace_budget,
                                Duration=run_duration,
                                RACmean=avg_cov,
                                RACstd=std_cov))

    rac_stats_per_run.run_duration = run_duration_list
    rac_stats_per_run.emitter = emitter_list
    rac_stats_per_run.parent_selection = sampling_strategy_list
    rac_stats_per_run.tracer_budget = refine_budget_list
    rac_stats_per_run.run_number = run_number_list
    rac_stats_per_run.rac = rac_list

    return [result_df, rac_stats_per_run]

end 


function save_archive_coverage(sut_name::String; top_ranked_only=false, all_groups=true)


    if top_ranked_only
        additional_arg = "TopRanked"
    else
        if all_groups
            additional_arg = "UniqueCells"
        else
            additional_arg = "NoPD0"
        end 

    end

    coverage_results = iterate_function(calculate_archive_coverage, sut_name; args = [additional_arg])
    total_archive_coverage_list, per_run_archive_coverage_list =  map(x -> x[1], coverage_results), map(x -> x[2], coverage_results)
    
    total_archive_coverage_df = vcat(total_archive_coverage_list...)
    sort!(total_archive_coverage_df, [:Duration, :Method, :TraceBudget])
    output_filename = "$(path_stats)/$(sut_name)/$(sut_name)ArchiveCoverage$(additional_arg).csv"
    create_dir_if_not_exists(output_filename)

    CSV.write(output_filename, total_archive_coverage_df)

    if additional_arg == "TopRanked"
        per_run_archive_coverage_df = vcat(per_run_archive_coverage_list...)
        sort!(per_run_archive_coverage_df, [:run_duration, :emitter, :parent_selection, :tracer_budget, :run_number])
        output_filename = "$(path_stats)/$(sut_name)/$(sut_name)ArchiveCoveragePerRun$(additional_arg).csv"
        CSV.write(output_filename, per_run_archive_coverage_df)
    end
    
end

function calculate_input_coverage_metrics(sut_name::String, run_duration::Integer, emitter::String, sampling_strategy::Union{String,Nothing},
    refine_budget::Union{Integer,Nothing}, args)
    prefix = args[1]

    coverage_stats_per_run = DataFrame()
    run_duration_list = []
    emitter_list = []
    sampling_strategy_list = []
    refine_budget_list = []
    run_number_list = []

    result_df = DataFrame()
    input_directory = get_directory_path(path_archive, sut_name, run_duration, emitter, sampling_strategy, refine_budget)

    list_avg_coverage_per_run = []
    list_sign_coverage_per_run = []
    list_parity_coverage_per_run = []
    list_bitlen_coverage_per_run = []

    input_filename = "$(path_agg_archive)/AllMethods/$(sut_name)UniqueCells.csv"
    df_all = CSV.read(input_filename, DataFrame, types=String)
    # calculate fitness threshold for the top ranked solutions 
    if prefix == "TopRanked"
        
        df_all = filter(row -> row[:boundary_rank] == "1", df_all)  # rank 1 does not include fitness = 0 and fitness = 1
        df_all.fitness = parse.(Float64, df_all.fitness)
        fitness_quantile = quantile(df_all[!, :fitness], top_rank_quantile)
        df_all = filter(row -> row[:fitness] >= fitness_quantile, df_all)
    end
    
    global_bl = collect_global_bitlens(df_all)
    global_rm = collect_global_range_mag_bins_per_row(df_all)

    pattern = r"_(\d+)\.csv$"
    for file in Glob.glob("*.csv", input_directory)
        m = match(pattern, basename(file))
        if m !== nothing && parse(Int, m.captures[1]) in 1:NUMBER_OF_RUNS
            df = CSV.read(file, DataFrame, types=String)

            if prefix == "NoPD0"
                df = filter(row -> row[:boundary_rank] != "2", df)
            elseif prefix == "TopRanked"
                df.fitness = parse.(Float64, df.fitness)
                df = filter(row -> row[:fitness] >= fitness_quantile, df)
            end


            ok, avg_cov, sc, pc, blc = coverage_for_run(df, global_bl, global_rm)

            if ok
                push!(run_duration_list, run_duration)
                push!(emitter_list, emitter)
                push!(sampling_strategy_list, sampling_strategy)
                push!(refine_budget_list, refine_budget)
                push!(list_avg_coverage_per_run, round(avg_cov, digits=4))
                push!(list_sign_coverage_per_run, round(sc, digits=4))
                push!(list_parity_coverage_per_run, round(pc, digits=4))
                push!(list_bitlen_coverage_per_run, round(blc, digits=4))
                push!(run_number_list, parse(Int, split(split(file, "_")[end], ".")[1]))
            else
                println("No input columns found in file: ", file)
            end

        else
            continue
        end
    end

    avg_coverage = round(mean(list_avg_coverage_per_run), digits=2)
    std_coverage = round(std(list_avg_coverage_per_run), digits=2)
    avg_sign_coverage = round(mean(list_sign_coverage_per_run), digits=2)
    std_sign_coverage = round(std(list_sign_coverage_per_run), digits=2)
    avg_parity_coverage = round(mean(list_parity_coverage_per_run), digits=2)
    std_parity_coverage = round(std(list_parity_coverage_per_run), digits=2)
    avg_bitlen_coverage = round(mean(list_bitlen_coverage_per_run), digits=2)
    std_bitlen_coverage = round(std(list_bitlen_coverage_per_run), digits=2)


    method = (emitter == "Mutation") ? sampling_strategy : emitter
    trace_budget = (refine_budget == nothing) ? missing : refine_budget

    append!(result_df, DataFrame(Method=method,
        TraceBudget=trace_budget,
        Duration=run_duration,
        AvgInputCoverageMean=avg_coverage,
        StdAvgInputCoverage=std_coverage,
        SignCoverageMean=avg_sign_coverage,
        StdSignCoverage=std_sign_coverage,
        ParityCoverageMean=avg_parity_coverage,
        StdParityCoverage=std_parity_coverage,
        BitlenCoverageMean=avg_bitlen_coverage,
        StdBitlenCoverage=std_bitlen_coverage))


    coverage_stats_per_run.run_duration = run_duration_list
    coverage_stats_per_run.emitter = emitter_list
    coverage_stats_per_run.parent_selection = sampling_strategy_list
    coverage_stats_per_run.tracer_budget = refine_budget_list
    coverage_stats_per_run.run_number = run_number_list
    coverage_stats_per_run.avg_input_coverage = list_avg_coverage_per_run
    coverage_stats_per_run.sign_coverage = list_sign_coverage_per_run
    coverage_stats_per_run.parity_coverage = list_parity_coverage_per_run
    coverage_stats_per_run.bitlen_coverage = list_bitlen_coverage_per_run


    return [result_df, coverage_stats_per_run]
end


function save_input_feature_metrics(sut_name::String; top_ranked_only=false, all_groups=false)
    include_autobva = true  # we need to include autobva to calculate the relative PD

    if top_ranked_only
        additional_arg = "TopRanked"
    else
        if all_groups
            additional_arg = "UniqueCells"
        else
            additional_arg = "NoPD0"
        end

    end

    input_coverage_results = iterate_function(calculate_input_coverage_metrics, sut_name; args=[additional_arg])
    total_coverage_list, per_run_coverage_list = map(x -> x[1], input_coverage_results), map(x -> x[2], input_coverage_results)

    total_coverage_df = vcat(total_coverage_list...)
    sort!(total_coverage_df, [:Duration, :Method, :TraceBudget])
    output_filename = "$(path_stats)/$(sut_name)/$(sut_name)InputFeatureCoverage$(additional_arg).csv"
    create_dir_if_not_exists(output_filename)

    CSV.write(output_filename, total_coverage_df)

    if additional_arg == "TopRanked"
        per_run_input_feature_df = vcat(per_run_coverage_list...)
        sort!(per_run_input_feature_df, [:run_duration, :emitter, :parent_selection, :tracer_budget, :run_number])
        output_filename = "$(path_stats)/$(sut_name)/$(sut_name)InputFeatureCoveragePerRun$(additional_arg).csv"
        CSV.write(output_filename, per_run_input_feature_df)
    end
end