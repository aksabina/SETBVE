using StringDistances, Distances
using Printf 

function assign_oan(sut_name::String, run_duration::Integer, emitter::String, sampling_strategy::Union{String, Nothing}, 
    refine_budget::Union{Integer, Nothing}, args)

    if !(sut_name in ["circle", "bmi"])  # OAN behavioural descriptor is only used in SUTs with categorical outputs
        return 
    end

    input_dir = get_directory_path(path_archive, sut_name, run_duration, emitter, sampling_strategy, refine_budget)
    if !isdir(input_dir) || isempty(readdir(input_dir))
        println("\033[33m⚠️  Warning: 'Archive' folder is missing the data for the following: $(sut_name) $(emitter) $(sampling_strategy) $(refine_budget)\033[0m")
        println("\033[33mPlease copy the 'Archive' folder from the SETBVE project into EvaluationSETBVE,\033[0m")
        println("\033[33mor download it from the Zenodo link provided in the README.\033[0m")
        exit()
    end

    for file in Glob.glob("*.csv", input_dir)
        df = CSV.read(file, DataFrame, types=String)

        bd_oan_values = Vector{Integer}(undef, nrow(df))

        output1_col = ("n_output" in names(df)) ? "output" : "output1"
        output2_col = ("n_output" in names(df)) ? "n_output" : "output2"

        for i in 1:nrow(df)
            o1, o2 = df[i, Symbol(output1_col)], df[i, Symbol(output2_col)]
            # extract error type if any 
            o1_error = Base.match(r"^[\w]+Error", o1)  
            o1 = (o1_error !== nothing) ? o1_error.match : o1  
            o2_error = Base.match(r"^[\w]+Error", o2)
            o2 = (o2_error !== nothing) ? o2_error.match : o2
            bd_oan_values[i] = bd_oan_global_dic[sut_name]["$(o1)$(o2)"]
        end

        df.bd_oan = bd_oan_values

        CSV.write(file, df)
    end
    
end


function aggregate_archive(sut_name::String, run_duration::Integer, emitter::String, sampling_strategy::Union{String, Nothing}, refine_budget::Union{Integer, Nothing}, additional_args)

    output_filename = get_filename(path_agg_archive, sut_name, run_duration, emitter, sampling_strategy, refine_budget, "csv", nothing)
    input_dir = get_directory_path(path_archive, sut_name, run_duration, emitter, sampling_strategy, refine_budget) 

    create_dir_if_not_exists(output_filename)
    aggregated_df = DataFrame()
    
    # Use Glob.jl to match all CSV files in the input directory
    for file in Glob.glob("*.csv", input_dir)
        df = CSV.read(file, DataFrame, types=String)

        # Sort BD columns
        bd_columns = filter(col -> startswith(col, "bd_"), names(df))
        sorted_bd_columns = sort(bd_columns)
        new_column_order = vcat(sorted_bd_columns, setdiff(names(df), bd_columns))  # keep bd columns first 
        df = df[:, new_column_order]
        
        append!(aggregated_df, df, promote=true)
    end
    
    CSV.write(output_filename, aggregated_df)
end

function extract_unique_cells_from_agg_archive_per_method(sut_name::String, run_duration::Integer, emitter::String, sampling_strategy::Union{String, Nothing}, 
    refine_budget::Union{Integer, Nothing}, args)
    input_filename = get_filename(path_agg_archive, sut_name, run_duration, emitter, sampling_strategy, refine_budget, "csv", nothing)
    df = CSV.read(input_filename, DataFrame, types=String)
    df.fitness = parse.(Float64, df.fitness)

    # Get output filename
    last_slash_index = findlast('/', input_filename)
    dirpath = input_filename[1:last_slash_index]
    filename = input_filename[last_slash_index+1:end]
    output_filename = "$(dirpath)$(args[1])$(filename)"

    # Define the columns to group by and the fitness column
    cell_column_names = filter(name -> startswith(name, "bd_"), names(df))
    fitness_column = :fitness 

    # Group by specified columns and filter for the max fitness row in each group
    filtered_df = combine(groupby(df, cell_column_names)) do group
        group[findmax(group[!, fitness_column])[2], :]  # save max fitness per bd combination and drop everything else 
    end

    CSV.write(output_filename, filtered_df)
end

function extract_unique_cells_from_agg_archive_per_sut(sut_name::String)
    dfs = iterate_function(load_dataframe, sut_name; args=["AggregatedArchive" ,"UniqueCells"])

    # Identify common columns
    common_columns = intersect(names(dfs[begin]), names(dfs[end]))  # AutoBVA contains columns that other emitters do not have

    # Combine dataframes into one
    aligned_dfs = [df[:, common_columns] for df in dfs]
    combined_df = vcat(aligned_dfs...)
    combined_df.fitness = parse.(Float64, combined_df.fitness)
    
    sorted_column_names = sort(names(combined_df))
    combined_df = combined_df[:, sorted_column_names]
    cell_column_names = filter(name -> startswith(name, "bd_"), names(combined_df))
    combined_df[!, :found_by_count] .= 0

    filtered_df = combine(groupby(combined_df, cell_column_names)) do group
        max_fitness_row = group[findmax(group[!, :fitness])[2], :]
    
        # Add the new column 'found_by_count' which counts the number of rows in the group
        max_fitness_row.found_by_count = nrow(group)
        
        return max_fitness_row
    end

    sort!(filtered_df, :fitness, rev=true)
    output_filename = "AggregatedArchive/AllMethods/$(sut_name)UniqueCells.csv"
    create_dir_if_not_exists(output_filename)
    CSV.write(output_filename, filtered_df)
end

function add_max_fitness_column(sut_name::String, run_duration::Integer, emitter::String, sampling_strategy::Union{String, Nothing}, 
    refine_budget::Union{Integer, Nothing}, args)

    all_filename = "AggregatedArchive/AllMethods/$(sut_name)UniqueCells.csv"
    df_all = CSV.read(all_filename, DataFrame, types=String)
    df_all.fitness = parse.(Float64, df_all.fitness)
    
    sorted_column_names = sort(names(df_all))
    df_all = df_all[:, sorted_column_names]
    cell_columns = filter(name -> startswith(name, "bd_"), names(df_all))

    df_all_dict = Dict(row[cell_columns] => row[:fitness] for row in eachrow(df_all))
    input_dir = get_directory_path(path_archive, sut_name, run_duration, emitter, sampling_strategy, refine_budget)

    for file in Glob.glob("*.csv", input_dir)
        df = CSV.read(file, DataFrame, types=String)
        df.fitness = parse.(Float64, df.fitness)
        sorted_column_names = sort(names(df))
        df = df[:, sorted_column_names]
        
        df.:fitness_max = [get(df_all_dict, row[cell_columns], missing) for row in eachrow(df)]  # assign max fitness found in the combined dataframe
        fitness_ratio_max_values = Vector{Float64}(undef, nrow(df))

        for i in 1:nrow(df)
            if ismissing(df[i, :fitness_max])
                fitness_ratio_max_values[i] = missing
            else
                if df[i, :fitness_max] == 0 && df[i, :fitness] == 0
                    fitness_ratio_max_values[i] = 1 # if the max possible fitness is 0, it means we achieved max possible, so we assign the ratio to 1
                else
                    fitness_ratio_max_values[i] = df[i, :fitness] / df[i, :fitness_max]
                end
            end
        end

        df.fitness_ratio_max = fitness_ratio_max_values
        
        # Count rows with missing fitness_max and missing fitness_ratio_max
        missing_fitness_max_count = count(ismissing, df.:fitness_max)
        missing_fitness_ratio_count = count(ismissing, df.:fitness_ratio_max)
        if missing_fitness_max_count>0 || missing_fitness_ratio_count>0
            println("File: $(input_filename) -> Missing fitness_max: $(missing_fitness_max_count); Missing fitness_ratio_max: $(missing_fitness_ratio_count)")
        end

        # Drop the max_fitness column which is not related to this calculation to avoid confusion
        if "max_fitness" in names(df)
            select!(df, Not(:max_fitness))
        end

        CSV.write(file, df)
    end

end

function rename_autobva_files(sut_name::String)
    
    for run_duration in list_run_duration
        
        old_pattern = "$(path_autobva)/$(sut_name)/$(run_duration)/*.csv"
        old_files = glob(old_pattern)

        for old_name in old_files
            # Extract the components from the old filename
            path_components = splitpath(old_name)

            # # Example: ["Archive", "AutoBVA", "circle", "30", "circle solid_ProgramDerivative_bcs_BituniformSampling_cts_30_1.csv"]
            sut_name = path_components[end-2]  # Extract "circle"
            duration = path_components[end-1]  # Extract "30"
            old_file = path_components[end]    # Extract "circle solid_ProgramDerivative_bcs_BituniformSampling_cts_30_1.csv"

            # Extract the index (e.g., the last number before ".csv")
            matches = match(r".*_(\d+)\.csv", old_file)
            index = matches.captures[1]  # Capture the index (e.g., "1")

            # Create the new file name
            new_file = @sprintf("Archive%sAutoBVA%s_%s.csv", sut_name, duration, index)

            # Construct the new full path for the renamed file
            new_name = joinpath(path_archive, "AutoBVA", sut_name, string(run_duration) ,new_file)

            # Rename the file
            if occursin("-", old_name)
                new_name = replace(old_name, "-" => "_")   
            end

            # Create destination directory if it doesn't exist
            isdir(dirname(new_name)) || mkpath(dirname(new_name))

            # copy+replace files in the destination 
            cp(old_name, new_name; force=true)
        end
    end
end

function preprocess_autobva_df(sut_name::String)

    new_column_names = Dict(
        "date" => Dict(
            :year => :i1_3,
            :month => :i1_2,
            :day => :i1_1, 
            :output => :output1, 
            :outputtype => :output_type, 
            :datatype => :datatype, 
            :metric => :fitness_strlength, 
            :n_year => :i2_3, 
            :n_month => :i2_2,
            :n_day => :i2_1, 
            :n_output => :output2, 
            :n_outputtype => :n_outputtype, 
            :n_datatype => :n_datatype, 
            :count => :count, 
        ),

        "circle" => Dict(
            :x => :i1_1,
            :y => :i1_2,
            :output => :output1, 
            :outputtype => :output_type, 
            :datatype => :datatype, 
            :metric => :fitness_strlength, 
            :n_x => :i2_1, 
            :n_y => :i2_2,
            :n_output => :output2, 
            :n_outputtype => :n_outputtype, 
            :n_datatype => :n_datatype, 
            :count => :count, 
        ),

        "bmi" => Dict(
            :h => :i1_1,
            :w => :i1_2,
            :output => :output1, 
            :outputtype => :output_type, 
            :datatype => :datatype, 
            :metric => :fitness_strlength, 
            :n_h => :i2_1, 
            :n_w => :i2_2,
            :n_output => :output2, 
            :n_outputtype => :n_outputtype, 
            :n_datatype => :n_datatype, 
            :count => :count, 
        ),

        "bytecount" => Dict(
            :bytes => :i1_1,
            :output => :output1, 
            :outputtype => :output_type, 
            :datatype => :datatype, 
            :metric => :fitness_strlength, 
            :n_bytes => :i2_1, 
            :n_output => :output2, 
            :n_outputtype => :n_outputtype, 
            :n_datatype => :n_datatype, 
            :count => :count, 
        ),
        "cld" => Dict(
            :a => :i1_1,
            :b => :i1_2,
            :output => :output1, 
            :outputtype => :output_type, 
            :datatype => :datatype, 
            :metric => :fitness_strlength, 
            :n_a => :i2_1, 
            :n_b => :i2_2, 
            :n_output => :output2, 
            :n_outputtype => :n_outputtype, 
            :n_datatype => :n_datatype, 
            :count => :count, 
        ),
        "fld" => Dict(
            :a => :i1_1,
            :b => :i1_2,
            :output => :output1, 
            :outputtype => :output_type, 
            :datatype => :datatype, 
            :metric => :fitness_strlength, 
            :n_a => :i2_1, 
            :n_b => :i2_2, 
            :n_output => :output2, 
            :n_outputtype => :n_outputtype, 
            :n_datatype => :n_datatype, 
            :count => :count, 
        ),
        "fldmod1" => Dict(
            :x => :i1_1,
            :y => :i1_2,
            :output => :output1, 
            :outputtype => :output_type, 
            :datatype => :datatype, 
            :metric => :fitness_strlength, 
            :n_x => :i2_1, 
            :n_y => :i2_2, 
            :n_output => :output2, 
            :n_outputtype => :n_outputtype, 
            :n_datatype => :n_datatype, 
            :count => :count, 
        ),
        "max" => Dict(
            :x => :i1_1,
            :y => :i1_2,
            :output => :output1, 
            :outputtype => :output_type, 
            :datatype => :datatype, 
            :metric => :fitness_strlength, 
            :n_x => :i2_1, 
            :n_y => :i2_2, 
            :n_output => :output2, 
            :n_outputtype => :n_outputtype, 
            :n_datatype => :n_datatype, 
            :count => :count, 
        ),
        "tailjoin" => Dict(
            :A => :i1_1,
            :i => :i1_2,
            :output => :output1, 
            :outputtype => :output_type, 
            :datatype => :datatype, 
            :metric => :fitness_strlength, 
            :n_A => :i2_1, 
            :n_i => :i2_2, 
            :n_output => :output2, 
            :n_outputtype => :n_outputtype, 
            :n_datatype => :n_datatype, 
            :count => :count, 
        ),
        "power_by_squaring" => Dict(
            :x_ => :i1_1,
            :p => :i1_2,
            :output => :output1, 
            :outputtype => :output_type, 
            :datatype => :datatype, 
            :metric => :fitness_strlength, 
            :n_x_ => :i2_1, 
            :n_p => :i2_2, 
            :n_output => :output2, 
            :n_outputtype => :n_outputtype, 
            :n_datatype => :n_datatype, 
            :count => :count, 
        ),
    )

    col_dtypes = Dict(
        "date" => Dict(
            :year => String,
            :month => String,
            :day => String, 
            :output => String, 
            :outputtype => String, 
            :datatype => String, 
            :metric => Float64, 
            :n_year => String, 
            :n_month => String,
            :n_day => String, 
            :n_output => String, 
            :n_outputtype => String, 
            :n_datatype => String, 
            :count => Int64, 
        ),

        "circle" => Dict(
            :x => String,
            :y => String,
            :output => String, 
            :outputtype => String,  
            :datatype => String, 
            :metric => Float64,
            :n_x => String, 
            :n_y => String,
            :n_output => String, 
            :n_outputtype => String,  
            :n_datatype => String,  
            :count => Int64 
        ),

        "bmi" => Dict(
            :h => String,
            :w => String,
            :output => String, 
            :outputtype => String, 
            :datatype => String, 
            :metric => Float64, 
            :n_h => String,
            :n_w => String,
            :n_output => String, 
            :n_outputtype => String, 
            :n_datatype => String, 
            :count => Int64, 
        ),

        "bytecount" => Dict(
            :bytes => String,
            :output => String, 
            :outputtype => String,  
            :datatype => String,  
            :metric => Float64, 
            :n_bytes => String, 
            :n_output => String,  
            :n_outputtype => String,  
            :n_datatype => String,  
            :count => Int64 
        ),
        "cld" => Dict(
            :a => String,
            :b => String,
            :output => String, 
            :outputtype => String, 
            :datatype => String, 
            :metric => Float64, 
            :n_a => String, 
            :n_b => String, 
            :n_output => String, 
            :n_outputtype => String, 
            :n_datatype => String, 
            :count => Int64, 
        ),
        "fld" => Dict(
            :a => String,
            :b => String,
            :output => String, 
            :outputtype => String, 
            :datatype => String, 
            :metric => Float64, 
            :n_a => String, 
            :n_b => String, 
            :n_output => String, 
            :n_outputtype => String, 
            :n_datatype => String, 
            :count => Int64, 
        ),
        "fldmod1" => Dict(
            :x => String,
            :y => String,
            :output => String, 
            :outputtype => String, 
            :datatype => String, 
            :metric => Float64, 
            :n_x => String, 
            :n_y => String, 
            :n_output => String, 
            :n_outputtype => String, 
            :n_datatype => String, 
            :count => Int64, 
        ),
        "max" => Dict(
            :x => String,
            :y => String,
            :output => String, 
            :outputtype => String, 
            :datatype => String, 
            :metric => Float64, 
            :n_x => String, 
            :n_y => String, 
            :n_output => String, 
            :n_outputtype => String, 
            :n_datatype => String, 
            :count => Int64, 
        ),
        "tailjoin" => Dict(
            :A => String,
            :i => String,
            :output => String, 
            :outputtype => String, 
            :datatype => String, 
            :metric => Float64, 
            :n_A => String, 
            :n_i => String, 
            :n_output => String, 
            :n_outputtype => String, 
            :n_datatype => String, 
            :count => Int64, 
        ),
        "power_by_squaring" => Dict(
            :x_ => String,
            :p => String,
            :output => String, 
            :outputtype => String, 
            :datatype => String, 
            :metric => Float64, 
            :n_x_ => String, 
            :n_p => String, 
            :n_output => String, 
            :n_outputtype => String, 
            :n_datatype => String, 
            :count => Int64, 
        ),
    )

    for total_duration in list_run_duration
        for i in 1:20
            input_filename = "$(path_archive)/AutoBVA/$(sut_name)/$(total_duration)/Archive$(sut_name)AutoBVA$(total_duration)_$i.csv"
            if sut_name == "circle"
                df = CSV.read(input_filename, DataFrame, types=col_dtypes[sut_name])
            else 
                df = CSV.read(input_filename, DataFrame)
            end

            # Rename columns
            rename!(df, new_column_names[sut_name]) 

            # Calculate BDs
            df.bd_validity_group = [num_exceptions(row) for row in eachrow(df)]
            df.bd_in_length_total = [total_input_length(row) for row in eachrow(df)]
            df.bd_in_length_var = [var_input_length(row) for row in eachrow(df)]

            if sut_name in ["date", "bytecount", "cld", "fld", "fldmod1", "max", "tailjoin", "power_by_squaring"]
                df.bd_out_length_diff = [output_length_diff(row) for row in eachrow(df)]
            end

            df.fitness = [calculate_fitness(row) for row in eachrow(df)]

            cell_column_names = filter(name -> startswith(name, "bd_"), names(df))

            filtered_df = combine(groupby(df, cell_column_names)) do group  # save one solution with a max PD per archive cell
                group[findmax(group[!, :fitness])[2], :]
            end
            CSV.write(input_filename, filtered_df)
        end
    end
end

function calculate_fitness(row)

    output_distance = StringDistances.Jaccard(2)(row.output1, row.output2)
    if (:i1_3) in propertynames(row)
        input_distance = euclidean((parse_bigint_with_bool(row.i1_1), parse_bigint_with_bool(row.i1_2), parse_bigint_with_bool(row.i1_3)), (parse_bigint_with_bool(row.i2_1), parse_bigint_with_bool(row.i2_2), parse_bigint_with_bool(row.i2_3)))
    elseif (:i1_2) in propertynames(row)
        input_distance = euclidean((parse_bigint_with_bool(row.i1_1), parse_bigint_with_bool(row.i1_2)), (parse_bigint_with_bool(row.i2_1), parse_bigint_with_bool(row.i2_2)))
    else
        input_distance = abs(parse_bigint_with_bool(row.i1_1) - parse_bigint_with_bool(row.i2_1))
    end 
    return input_distance == 0 ? 0 : output_distance / input_distance
end

function num_exceptions(row)
    count_contains_error = sum(map(o -> occursin(r"(?i)error", o), [row.output1, row.output2]))
    return count_contains_error
end

function output_length_diff(row)
    o1, o2 = string(row.output1), string(row.output2)
    return abs(length(o1) - length(o2))
end

function total_input_length(row)
    # convert to BigInt to avoid scientific notation with e; 
    # skip converting true or false to BigInt
    if :i1_3 in propertynames(row)
        i1_1 = (lowercase(string(row.i1_1)) == "false" || lowercase(string(row.i1_1)) == "true") ? string(row.i1_1) : string(parse_bigint_with_bool(row.i1_1))
        i1_2 = (lowercase(string(row.i1_2)) == "false" || lowercase(string(row.i1_2)) == "true") ? string(row.i1_2) : string(parse_bigint_with_bool(row.i1_2))
        i1_3 = (lowercase(string(row.i1_3)) == "false" || lowercase(string(row.i1_3)) == "true") ? string(row.i1_3) : string(parse_bigint_with_bool(row.i1_3))
        i2_1 = (lowercase(string(row.i2_1)) == "false" || lowercase(string(row.i2_1)) == "true") ? string(row.i2_1) : string(parse_bigint_with_bool(row.i2_1))
        i2_2 = (lowercase(string(row.i2_2)) == "false" || lowercase(string(row.i2_2)) == "true") ? string(row.i2_2) : string(parse_bigint_with_bool(row.i2_2))
        i2_3 = (lowercase(string(row.i2_3)) == "false" || lowercase(string(row.i2_3)) == "true") ? string(row.i2_3) : string(parse_bigint_with_bool(row.i2_3))
        return length(i1_1) + length(i1_2) + length(i1_3) + length(i2_1) + length(i2_2) + length(i2_3)
    elseif :i1_2 in propertynames(row)
        i1_1 = (lowercase(string(row.i1_1)) == "false" || lowercase(string(row.i1_1)) == "true") ? string(row.i1_1) : string(parse_bigint_with_bool(row.i1_1))
        i1_2 = (lowercase(string(row.i1_2)) == "false" || lowercase(string(row.i1_2)) == "true") ? string(row.i1_2) : string(parse_bigint_with_bool(row.i1_2))
        i2_1 = (lowercase(string(row.i2_1)) == "false" || lowercase(string(row.i2_1)) == "true") ? string(row.i2_1) : string(parse_bigint_with_bool(row.i2_1))
        i2_2 = (lowercase(string(row.i2_2)) == "false" || lowercase(string(row.i2_2)) == "true") ? string(row.i2_2) : string(parse_bigint_with_bool(row.i2_2))
        return length(i1_1) + length(i1_2) + length(i2_1) + length(i2_2)
    else
        i1_1 = (lowercase(string(row.i1_1)) == "false" || lowercase(string(row.i1_1)) == "true") ? string(row.i1_1) : string(parse_bigint_with_bool(row.i1_1))
        i2_1 = (lowercase(string(row.i2_1)) == "false" || lowercase(string(row.i2_1)) == "true") ? string(row.i2_1) : string(parse_bigint_with_bool(row.i2_1))
        return length(i1_1) + length(i2_1)
    end
end


function var_input_length(row)
    # convert to BigInt to avoid scientific notation with e 
    if :i1_3 in propertynames(row)
        i1_1 = (lowercase(string(row.i1_1)) == "false" || lowercase(string(row.i1_1)) == "true") ? string(row.i1_1) : string(parse_bigint_with_bool(row.i1_1))
        i1_2 = (lowercase(string(row.i1_2)) == "false" || lowercase(string(row.i1_2)) == "true") ? string(row.i1_2) : string(parse_bigint_with_bool(row.i1_2))
        i1_3 = (lowercase(string(row.i1_3)) == "false" || lowercase(string(row.i1_3)) == "true") ? string(row.i1_3) : string(parse_bigint_with_bool(row.i1_3))
        i2_1 = (lowercase(string(row.i2_1)) == "false" || lowercase(string(row.i2_1)) == "true") ? string(row.i2_1) : string(parse_bigint_with_bool(row.i2_1))
        i2_2 = (lowercase(string(row.i2_2)) == "false" || lowercase(string(row.i2_2)) == "true") ? string(row.i2_2) : string(parse_bigint_with_bool(row.i2_2))
        i2_3 = (lowercase(string(row.i2_3)) == "false" || lowercase(string(row.i2_3)) == "true") ? string(row.i2_3) : string(parse_bigint_with_bool(row.i2_3))
        lengths = [length(i1_1), length(i1_2), length(i1_3), length(i2_1), length(i2_2), length(i2_3)]
        return Int(floor(Statistics.var(lengths)))
    elseif :i1_2 in propertynames(row)
        i1_1 = (lowercase(string(row.i1_1)) == "false" || lowercase(string(row.i1_1)) == "true") ? string(row.i1_1) : string(parse_bigint_with_bool(row.i1_1))
        i1_2 = (lowercase(string(row.i1_2)) == "false" || lowercase(string(row.i1_2)) == "true") ? string(row.i1_2) : string(parse_bigint_with_bool(row.i1_2))
        i2_1 = (lowercase(string(row.i2_1)) == "false" || lowercase(string(row.i2_1)) == "true") ? string(row.i2_1) : string(parse_bigint_with_bool(row.i2_1))
        i2_2 = (lowercase(string(row.i2_2)) == "false" || lowercase(string(row.i2_2)) == "true") ? string(row.i2_2) : string(parse_bigint_with_bool(row.i2_2))
        lengths = [length(i1_1), length(i1_2), length(i2_1), length(i2_2)]
        return Int(floor(Statistics.var(lengths)))
    else
        i1_1 = (lowercase(string(row.i1_1)) == "false" || lowercase(string(row.i1_1)) == "true") ? string(row.i1_1) : string(parse_bigint_with_bool(row.i1_1))
        i2_1 = (lowercase(string(row.i2_1)) == "false" || lowercase(string(row.i2_1)) == "true") ? string(row.i2_1) : string(parse_bigint_with_bool(row.i2_1))
        lengths = [length(i1_1), length(i2_1)]
        return Int(floor(Statistics.var(lengths)))
    end
end

function assign_boundary_candidate_rank(sut_name::String, run_duration::Integer, emitter::String, sampling_strategy::Union{String, Nothing}, 
    refine_budget::Union{Integer, Nothing}, args)

    input_dir = get_directory_path(path_archive, sut_name, run_duration, emitter, sampling_strategy, refine_budget) 
    # Use Glob.jl to match all CSV files in the input directory
    for file in Glob.glob("*.csv", input_dir)
        df = CSV.read(file, DataFrame, types=String)

        df.fitness = parse.(Float64, df.fitness)
        df.boundary_rank = map(f -> f == 1 ? 0 : f == 0 ? 2 : 1, df.fitness)
        CSV.write(file, df)
    end


end