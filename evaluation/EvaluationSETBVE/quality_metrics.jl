
function save_top_ranked_cells_per_sut(sut_name::String; quantile_thresh=top_rank_quantile)
    input_filename = "$(path_agg_archive)/AllMethods/$(sut_name)UniqueCells.csv"  # to calculate the threshold we need all methods combined including autobva
    df = CSV.read(input_filename, DataFrame, types=String)

    # Calculate the threshold for top ranked solutions 
    df_thresh = filter(row -> row[:boundary_rank] == "1", df)  # rank 1 has fitness 0<fitness<1
    df_thresh.fitness = parse.(Float64, df_thresh.fitness)
    fitness_quantile = quantile(df_thresh[!, :fitness], quantile_thresh)

    df.fitness = parse.(Float64, df.fitness)
    df = filter(row -> row[:fitness] >= fitness_quantile, df)

    output_filename = "$(path_agg_archive)/AllMethods/$(sut_name)TopRanked.csv"
    CSV.write(output_filename, df)
end



function save_top_ranked_cells_per_method(sut_name::String, run_duration::Integer, emitter::String, sampling_strategy::Union{String, Nothing}, 
    refine_budget::Union{Integer, Nothing}, args)

    input_filename = "$(path_agg_archive)/AllMethods/$(sut_name)$(args[1]).csv"  # we need to include autobva boundaries here because these are all found top solutions by all methods
    df_main = CSV.read(input_filename, DataFrame, types=String)
    cell_columns = filter(name -> startswith(name, "bd_"), names(df_main))
    top_rows = Set(eachrow(select(df_main, cell_columns)))  # top rows overall 
    
    df = load_dataframe(sut_name, run_duration, emitter, sampling_strategy, refine_budget, [path_agg_archive, "UniqueCells"])
    filtered_df = filter(row -> (row[cell_columns] in top_rows), df)

    output_filename = get_filename(path_agg_archive, sut_name, run_duration, emitter, sampling_strategy, refine_budget, "csv", args[1])
    create_dir_if_not_exists(output_filename)
    CSV.write(output_filename, filtered_df)
end


function calculate_pd_metrics(sut_name::String, run_duration::Integer, emitter::String, sampling_strategy::Union{String, Nothing}, 
    refine_budget::Union{Integer, Nothing}, args)
    prefix = args[1]

    cnpd_stats_per_run = DataFrame()
    run_duration_list = []
    emitter_list = []
    sampling_strategy_list = []
    refine_budget_list = []
    run_number_list = []
    cnpd_list = []

    result_df = DataFrame()
    input_directory = get_directory_path(path_archive, sut_name, run_duration, emitter, sampling_strategy, refine_budget)
    
    list_mean_pd_ratio_per_run = []

    # calculate fitness threshold for the top ranked solutions 
    if prefix == "TopRanked"
        input_filename = "$(path_agg_archive)/AllMethods/$(sut_name)UniqueCells.csv"
        df_all = CSV.read(input_filename, DataFrame, types=String)
        df_all = filter(row -> row[:boundary_rank] == "1", df_all)  # rank 1 does not include fitness = 0 and fitness = 1
        df_all.fitness = parse.(Float64, df_all.fitness)
        fitness_quantile = quantile(df_all[!, :fitness], top_rank_quantile)
    end


    for file in Glob.glob("*.csv", input_directory)

        df = CSV.read(file, DataFrame, types=String)

        if prefix == "NoPD0"
            df = filter(row -> row[:boundary_rank] != "2", df)
        elseif prefix == "TopRanked"
            df.fitness = parse.(Float64, df.fitness)
            df = filter(row -> row[:fitness] >= fitness_quantile, df)
        end 

        df.fitness_ratio_max = parse.(Float64, df.fitness_ratio_max)

        # after phase2 there are multiple solutions per one archive cell, so we take the best one to assess the quality 
        cell_column_names = filter(name -> startswith(name, "bd_"), names(df)) 

        if nrow(df) > 0 
            # Group by specified columns and filter for the max fitness row in each group
            df_filtered = combine(groupby(df, cell_column_names)) do group
                group[findmax(group[!, :fitness])[2], :]  # save max fitness per bd combination and drop everything else 
            end
        mean_pd = mean(df_filtered.:fitness_ratio_max) 

        else
            mean_pd = 0
        end

        push!(list_mean_pd_ratio_per_run, mean_pd)
        push!(run_duration_list, run_duration)
        push!(emitter_list, emitter)
        push!(sampling_strategy_list, sampling_strategy)
        push!(refine_budget_list, refine_budget)
        push!(run_number_list, parse(Int, split(split(file, "_")[end], ".")[1]))
        push!(cnpd_list, mean_pd)
        

    end

    avg_cnpd = round(mean(list_mean_pd_ratio_per_run), digits=2)
    std_cnpd = round(std(list_mean_pd_ratio_per_run), digits=2)


    method = (emitter == "Mutation") ? sampling_strategy : emitter
    trace_budget = (refine_budget == nothing) ? missing : refine_budget

    append!(result_df, DataFrame(Method=method, 
                                TraceBudget=trace_budget,
                                Duration=run_duration,
                                RPDMean=avg_cnpd,
                                RPDStd=std_cnpd))


    cnpd_stats_per_run.run_duration = run_duration_list
    cnpd_stats_per_run.emitter = emitter_list
    cnpd_stats_per_run.parent_selection = sampling_strategy_list
    cnpd_stats_per_run.tracer_budget = refine_budget_list
    cnpd_stats_per_run.run_number = run_number_list
    cnpd_stats_per_run.cnpd = cnpd_list

    return [result_df, cnpd_stats_per_run]
end


function save_pd_metrics(sut_name::String; top_ranked_only=false, all_groups=false)
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

    quality_results = iterate_function(calculate_pd_metrics, sut_name; args = [additional_arg])
    total_cnpd_list, per_run_cnpd_list =  map(x -> x[1], quality_results), map(x -> x[2], quality_results)

    total_cnpd_df = vcat(total_cnpd_list...)
    sort!(total_cnpd_df, [:Duration, :Method, :TraceBudget])
    output_filename = "$(path_stats)/$(sut_name)/$(sut_name)Quality$(additional_arg).csv"
    create_dir_if_not_exists(output_filename)

    CSV.write(output_filename, total_cnpd_df)

    if additional_arg == "TopRanked"
        per_run_quality_df = vcat(per_run_cnpd_list...)
        sort!(per_run_quality_df, [:run_duration, :emitter, :parent_selection, :tracer_budget, :run_number])
        output_filename = "$(path_stats)/$(sut_name)/$(sut_name)QualityPerRun$(additional_arg).csv"
        CSV.write(output_filename, per_run_quality_df)
    end
end