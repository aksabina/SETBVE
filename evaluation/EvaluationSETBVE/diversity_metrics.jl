
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
    
    for file in Glob.glob("*.csv", input_directory)

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