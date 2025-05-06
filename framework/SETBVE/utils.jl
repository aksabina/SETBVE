using StatsBase, Random, Base.Threads

# calculate the maximum number of bits of a datatype 
maxbits(::Type{T}) where {T<:Unsigned} = sizeof(T) * 8  
maxbits(::Type{T}) where {T<:Signed} = sizeof(T) * 8 - 1

# right bitshift for a randomly sampled Integer of a subtype t
bitlogsample(t::Type{<:Integer}) = (rand(t)) >> rand(0:maxbits(t))
bitlogsample(::Type{Bool}) = (Int(rand(Bool)))

# returns sorted combined strings  (e.g., NormalOverweight)
lexorderjoin(a, b, sep="") = join(sort([string(a), string(b)]), sep)  
# returns a string without digits 
stripnumber(s) = replace(string(s), r"\d+" => "")  

function to_signed_unsigned_Int(x)
    if x < 0 || x < typemax(Int128)
        round(Int128, x)
    else
        round(UInt128, x)
    end
end

# replaces en error message by the error type
function replace_errors!(df::DataFrame, column::Symbol, pattern::Regex, replacement::String)
    for i in 1:nrow(df)
        if occursin(pattern, df[i, column])
            df[i, column] = replacement
        end
    end
end

function parse_int_with_bool(value)
    if value == "false" || value == "FALSE" || value == "False"
        return Int8(0)
    elseif value == "true" || value == "TRUE" || value == "True"
        return Int8(1)
    else
        return to_signed_unsigned_Int(value)
    end
end

function sample(archive::AbstractArchive, numsolutions::Int, bias_column::String)

    if bias_column == "Fitness"
        bias_scores = [abs(archive.cells[archive.grid[cellid]][2].fitness[1]) for cellid in keys(archive.grid)] 
    elseif bias_column == "Curiosity"
        bias_scores = [archive.cells[archive.grid[cellid]][1]["curiosity"] for cellid in keys(archive.grid)]
    else # uniform
        bias_scores = []
    end

    # Check if there are non-zero scores and that they are not all the same
    if isempty(bias_scores) || all(x -> x == bias_scores[1], bias_scores)
        # If all scores are zero or the list is empty, use uniform sampling
        cellid_bd_list = StatsBase.sample(cellids(archive), numsolutions)  # cellid is the behav descriptor (coordinates)
    else
        min_score = minimum(bias_scores)
        max_score = maximum(bias_scores)
        normalized_scores = (bias_scores .- min_score) ./ (max_score - min_score)

        # Perform weighted sampling based on the normalized curiosity scores
        cellid_bd_list = StatsBase.sample(cellids(archive), Weights(normalized_scores), numsolutions)  # replace=false ensures no duplicated sampling 
    end

    idx_list = [get(archive.grid, cellid_bd, nothing) for cellid_bd in cellid_bd_list]
    return idx_list
end


function random_point_between(i1::Vector{<:Any}, i2::Vector{<:Any}; min_percent=0.25, max_percent=0.75)::Vector{<:Any}
    # Random percentage between min_percent and max_percent
    rand_percent = min_percent + rand() * (max_percent - min_percent)

    # Calculate the vector from i1 to i2 and scale it
    scaled_vector = [rand_percent * (i2[j] - i1[j]) for j in 1:length(i1)]

    # Calculate the new point by adding scaled_vector to i1
    i_between = [(to_signed_unsigned_Int(i1[j]) + to_signed_unsigned_Int(scaled_vector[j])) for j in 1:length(i1)] 
    return i_between
end

function generate_random_neighbours(solution_list)
    neighbors = deepcopy(solution_list)
    for _ in 1:local_search_neighbors_num
        neighbor = shrink_move_mutation(deepcopy(rand(neighbors)))
        push!(neighbors, neighbor) 
    end

    return unique(neighbors)  # list of solutions e.g, [[1,2,3,4], [5,6,7,8], ..., [333,453,242,2]]
end


function extract_i1_i2(solution::Vector{<:Any})
    args_num = round(Int, (length(solution) / 2))
    i1 = solution[1:args_num]  # calculate args number per input to make it flexible for 2 and 3 input args
    i2 = solution[args_num+1:end] 
    return i1, i2
end


# function calculate_pd(i1::Vector{<:Any}, i2::Vector{<:Any}, output1, output2)
#     #input_distance = euclidean(map(to_signed_unsigned_Int, i1), map(to_signed_unsigned_Int, i2))
#     differences = [(UInt128(abs(to_signed_unsigned_Int(i1[i]) - to_signed_unsigned_Int(i2[i]))))^2 for i in 1:length(i1)]  
#     input_distance = sqrt(sum(differences))
#     output_distance = distance_jaccard(string(output1), string(output2))
#     fitness = input_distance != 0 ? output_distance / input_distance : 0
#     return fitness
# end

function calculate_pd(i1::Vector{<:Any}, i2::Vector{<:Any}, output1, output2)
    i1, i2 = map(BigInt, i1), map(BigInt, i2)  # convert to BigInt before squaring in euclidean

    input_distance = euclidean(i1, i2)
    output_distance = distance_jaccard(output1, output2)
    fitness = input_distance != 0 ? output_distance / input_distance : 0
    #i1, i2 = map(to_signed_unsigned_Int, i1), map(to_signed_unsigned_Int, i2)
    return fitness
end

function get_sut_output(i::Vector{<:Any}, sut_name::String)
    sut_function = sut_functions_dic[sut_name]
    
    output = try
        sut_function(i)
    catch err
        string(err)
    end
    return output 
end


function max_distance_inside_search_area(ranges::Vector{Any})
    max_point = ([maximum(rng) for rng in ranges])  # Get the maximum value from each range
    min_point = ([minimum(rng) for rng in ranges])  # Get the minimum value from each range

    max_point = map(BigInt, max_point)
    min_point = map(BigInt, min_point)

    # Compute the Euclidean distance between max_point and min_point

    distance = sqrt(sum((max_point[i] - min_point[i])^2 for i in 1:length(ranges)))

    return round(distance, digits = 4) 
end


function generate_solutions_within_ranges(ranges)
    solutions = Vector{Vector{Number}}()

    for _ in 1:local_search_neighbors_num
        # Generate one solution vector by randomly selecting a value within each range
        solution = [rand(rng) for rng in ranges]
        push!(solutions, solution)
    end

    return solutions
end

function calculate_objective(generated_solution, sampled_solution, max_distance, sut_name)
    # the objective is a weighted sum of fitness and distance between solution and random solution 

    i1_gen, i2_gen = extract_i1_i2(map(to_signed_unsigned_Int, generated_solution))
    output1_gen = get_sut_output(i1_gen, sut_name)
    output2_gen = get_sut_output(i2_gen, sut_name)
    fitness_gen = calculate_pd(i1_gen, i2_gen, output1_gen, output2_gen)

    i1_sam, i2_sam = extract_i1_i2(map(to_signed_unsigned_Int, sampled_solution))
    output1_sam = get_sut_output(map(to_signed_unsigned_Int, i1_sam), sut_name)
    output2_sam = get_sut_output(map(to_signed_unsigned_Int, i2_sam), sut_name)
    fitness_sam = calculate_pd(map(to_signed_unsigned_Int, i1_sam), map(to_signed_unsigned_Int, i2_sam), output1_sam, output2_sam)

    generated_solution = map(BigInt, generated_solution)
    sampled_solution = map(BigInt, sampled_solution)

    distance = euclidean(generated_solution, sampled_solution)

    return (max_distance*(fitness_gen+fitness_sam)) + distance
end


function local_search(duration_in_millis::Integer, sut_name::String, search_area_dims, max_distance)

    #init random solutions within the search area 
    best_solutions_list = generate_solutions_within_ranges(search_area_dims)
    
    # Hill Climber on total fitness and total distance between points 
    start_time = time() * 1_000_000  # milliseconds
    while(time() * 1_000_000 - start_time) <= duration_in_millis  # run for n milliseconds
        old_solution = rand(best_solutions_list)
        new_solution = shrink_move_mutation(old_solution)
        sampled_solution = rand(best_solutions_list)  # random one to calculate the distance with 
        if sampled_solution == old_solution
            sampled_solution = rand(best_solutions_list)  # sample again because we need a different one 
        end
        
        # Evaluate new solution
        old_objective = calculate_objective(old_solution, sampled_solution, max_distance, sut_name)
        new_objective = calculate_objective(new_solution, sampled_solution, max_distance, sut_name)

        # Check if the new solution is better (based on both objectives)
        if new_objective > old_objective
            #printstyled("$(old_objective) => $(new_objective)\n"; color=:green)
            # Replace the old solution in the list with the new solution
            for i in 1:length(best_solutions_list)
                if best_solutions_list[i] == old_solution
                    best_solutions_list[i] = new_solution
                    break  # Exit loop after replacing the old solution
                end
            end
            
        end
    end
    #println("Best solutions: ", best_solutions_list)
    return best_solutions_list 
end  


function calculate_localsearch_dims(df::DataFrame, start_row::Int, column_names::Vector{String}, current_solution)
    # Initialize a dictionary to store the deltas for each column
    deltas = Dict{String,Vector{Any}}()

    # Create an empty vector for each column's deltas
    for col in column_names
        deltas[col] = []
    end
    
    df_length = nrow(df)
    # Loop through the rows to calculate deltas
    for i in start_row:min(df_length - 1, (start_row + local_search_delta_calc_rows - 2))
        for col in column_names
            # Calculate the absolute deltas for each column between consecutive rows
            a = parse_int_with_bool(df[i+1, col])
            b = parse_int_with_bool(df[i, col])
            diff = signed_delta(a, b)
            push!(deltas[col], diff)
            #push!(deltas[col], abs(parse_int_with_bool(df[i+1, col]) - parse_int_with_bool(df[i, col])))  
        end
    end

    # Calculate the median of the deltas for each column
    medians = Dict{String,Any}()
    for col in column_names
        medians[col] = median(deltas[col])
    end

    # Calculate the ranges using the medians and current_solution
    ranges = []
    for i in 1:length(current_solution)
        col = column_names[i]
        median_val = medians[col]
        margin = max(UInt128(1), UInt128(round(0.1 * median_val)))  #margin is at least 1
        val = to_signed_unsigned_Int(current_solution[i])  # convert one of the arguments of the complete solution

        raw_lower = val - BigInt(median_val) - margin 
        raw_upper = val + BigInt(median_val) + margin
       
        if raw_lower <= UInt128(typemax(Int128))
            lower_bound = max(typemin(Int128) + 1, Int128(raw_lower))
        else
            lower_bound = typemax(Int128) - 1  # in case the value is too big
        end

        if raw_upper <= UInt128(typemax(Int128))
            upper_bound = min(typemax(Int128) - 1, Int128(raw_upper))
        else
            upper_bound = typemax(Int128) - 1 # in case the value is too big
        end

        if upper_bound <= lower_bound  # can happen due to UInt128 conversion or overflow
            upper_bound = lower_bound + margin
        end

        push!(ranges, lower_bound:upper_bound)
    end
    
    return ranges
end


function get_relative_random_step(i1::Vector{<:Any}, i2::Vector{<:Any})
    i1 = map(BigInt, i1)
    i2 = map(BigInt, i2)
    distance = euclidean(i1, i2)
    offset = min(typemax(Int128), max(1, round(BigInt, distance * rand())))
    step = (rand(range(-offset, offset)))
    return Int128(step) 
end


function shrink_move_mutation(solution::Vector{<:Any})::Vector{<:Any}
    i1, i2 = extract_i1_i2(solution)

    # shrink
    i_between = random_point_between(i1, i2)
    random_pair = (rand() < 0.5) ? i1 : i2

    # move
    rand_step = get_relative_random_step(i_between, random_pair)
    full_solution = Integer[i_between...; random_pair...]  
    rand_arg = rand(1:length(full_solution))

    if full_solution[rand_arg] > typemax(Int128) - abs(rand_step)
        full_solution[rand_arg] = UInt128(full_solution[rand_arg])
    end

    full_solution[rand_arg] += rand_step
    return full_solution
end

function create_dir_if_not_exists(filepath::String)
    last_slash_index = findlast('/', filepath)
    dirpath = filepath[1:last_slash_index]
    
    if !isdir(dirpath)
        mkpath(dirpath)
    end
end

function save_large_df_in_chunks(df::DataFrame, file_path::String, chunk_size::Int)
    create_dir_if_not_exists(file_path)
    df_length = nrow(df)
    open(file_path, "w") do io
        for i in 1:chunk_size:df_length
            chunk = df[i:min(i + chunk_size - 1, df_length), :]
            CSV.write(io, chunk; append=(i > 1))
        end
    end
end

function save_archive_to_csv(Archive::AbstractArchive, behavioural_descriptors::Vector{String}, sut_name::String, emitter_type::String, bias_column::String, duration::Integer, run_num::Integer, local_search_budget_ratio)::DataFrame

    output_filename = "$(dir_archive)$(round(Int,local_search_budget_ratio*100))%Tracer/$(bias_column)/$(sut_name)/$(emitter_type)/$(duration)/Archive$(sut_name)$(emitter_type)$(bias_column)$(duration)_$(run_num).csv"

    sut_function = sut_functions_dic[sut_name]

    df = DataFrame()
    archive_cells = cells(Archive)
    solutions = [cell[2][1]["solution"] for cell in archive_cells]
    curiosity_scores = [cell[2][1]["curiosity"] for cell in archive_cells]
    bd_values = [cell[1] for cell in archive_cells]
    fitness_values = [(cell[2][2]).fitness for cell in archive_cells]

    for (i, bd) in enumerate(behavioural_descriptors)
        df[!, Symbol("bd_$bd")] = [t[i] for t in bd_values]
    end

    for i in 1:(total_args_num[sut_name]÷2)
        df[!, Symbol("i1_$i")] = [t[i] for t in solutions]
    end

    for i in 1:(total_args_num[sut_name]÷2)
        df[!, Symbol("i2_$i")] = [t[i+total_args_num[sut_name]÷2] for t in solutions]
    end

    if sut_function !== nothing
        # Dynamically collect column names for i1
        i1_columns = filter(col -> startswith(string(col), "i1_"), names(df))

        #Apply transform for i1 (with unknown number of arguments)
        transform!(df, i1_columns => ByRow((args...) -> try
            string(sut_function(map(to_signed_unsigned_Int,collect(args))))
        catch e
            string(e)
        end) => :output1)


        # Dynamically collect column names for i1_2
        i2_columns = filter(col -> startswith(string(col), "i2_"), names(df))

        #Apply transform for i1_2 (with unknown number of arguments)
        transform!(df, i2_columns => ByRow((args...) -> try
            string(sut_function(map(to_signed_unsigned_Int, collect(args))))
        catch e
            string(e)
        end) => :output2)

    else
        error("Unknown sut_name: $sut_name")
    end

    df[!, :fitness] = [abs(t[1]) for t in fitness_values]  # later can be expanded to more than one fitness calculation
    df[!, :curiosity] = [t for t in curiosity_scores]
    df = DataFrames.sort(df, :fitness, rev=true)

    #save_large_df_in_chunks(df, output_filename, 10000)
    create_dir_if_not_exists(output_filename)
    CSV.write(output_filename, df) 

    return df

end


function ensure_column_exists!(df::DataFrame, col_name::Symbol, default_value=nothing)
    if !haskey(df, col_name)
        df[!, col_name] = fill(default_value, nrow(df))  # Add the column with the default value
    end
end


function append_archive_with_local_search_sols(df::DataFrame, local_search_df::DataFrame, sut_name::String, emitter_type::String, bias_column::String, duration::Integer, run_num::Integer, local_search_budget_ratio)
    sut_function = sut_functions_dic[sut_name]
    
    output_filename = "$(dir_archive)$(round(Int,local_search_budget_ratio*100))%Tracer/$(bias_column)/$(sut_name)/$(emitter_type)/$(duration)/Archive$(sut_name)$(emitter_type)$(bias_column)$(duration)withTracer_$(run_num).csv"
    #println("Appending local search df")
    
    n_rows = nrow(local_search_df)

    # Preallocate columns (this minimizes DataFrame modifications during the loop)
    local_search_df[!, :fitness] = fill(0.0, n_rows)
    local_search_df[!, :bd_validity_group] = fill(0, n_rows)
    if "bd_out_length_diff" in names(df)
        local_search_df[!, :bd_out_length_diff] = fill(0, n_rows)
    elseif "bd_oan" in names(df)
        local_search_df[!, :bd_oan] = fill(0, n_rows)
    end
    local_search_df[!, :bd_in_length_total] = fill(0, n_rows)
    local_search_df[!, :bd_in_length_var] = fill(0, n_rows)
    local_search_df[!, :output1] = fill("default_value", n_rows)
    local_search_df[!, :output2] = fill("default_value", n_rows)
    local_search_df[!, :curiosity] = fill(0.0, n_rows)

    function safe_sut_function(i)
        try
            return sut_function(i)
        catch err
            string(err) 
        end
    end

    p = Progress(n_rows)

    #@threads for row_idx in 1:n_rows
    for row_idx in 1:n_rows
        row = local_search_df[row_idx, :]

        if "i1_3" in names(df) 
            i1 = Any[to_signed_unsigned_Int(row.i1_1), to_signed_unsigned_Int(row.i1_2), to_signed_unsigned_Int(row.i1_3)]
            i2 = Any[to_signed_unsigned_Int(row.i2_1), to_signed_unsigned_Int(row.i2_2), to_signed_unsigned_Int(row.i2_3)]  
        elseif "i1_2" in names(df) 
            i1 = Any[to_signed_unsigned_Int(row.i1_1), to_signed_unsigned_Int(row.i1_2)]
            i2 = Any[to_signed_unsigned_Int(row.i2_1), to_signed_unsigned_Int(row.i2_2)]
        else
            i1 = Any[to_signed_unsigned_Int(row.i1_1)]
            i2 = Any[to_signed_unsigned_Int(row.i2_1)]
        end

        output1 = safe_sut_function(i1)
        output2 = safe_sut_function(i2)

        # Compute distances and fitness
        i1 = map(BigInt, i1)
        i2 = map(BigInt, i2)
        input_distance = euclidean(i1, i2)
        output_distance = distance_jaccard(output1, output2)
        fitness = input_distance != 0 ? output_distance / input_distance : 0


        # Assign values to the preallocated columns
        local_search_df.fitness[row_idx] = abs(fitness)
        local_search_df.bd_validity_group[row_idx] = num_exceptions([string(output1), string(output2)])
        
        if "bd_oan" in names(local_search_df)
            local_search_df.bd_oan[row_idx] = output_abstraction_number([string(output1), string(output2)])
        elseif "bd_out_length_diff" in names(local_search_df)
            local_search_df.bd_out_length_diff[row_idx] = output_length_diff([string(output1), string(output2)])
        end
    
        local_search_df.bd_in_length_total[row_idx] = total_input_length([i1, i2])
        local_search_df.bd_in_length_var[row_idx] = var_input_length([i1, i2])
        local_search_df.output1[row_idx] = string(output1)
        local_search_df.output2[row_idx] = string(output2)
        next!(p)
    end

    i_columns = filter(col -> startswith(string(col), "i"), names(local_search_df))

    df = vcat(df, local_search_df)
    
    for col in i_columns
        df[!, col] .= BigInt.(df[!, col])  # Broadcasting with BigInt constructor
    end


    df = unique(df, i_columns)
    df = DataFrames.sort(df, :fitness, rev=true)


    #println("Saving local search df")
    #save_large_df_in_chunks(df, output_filename, 10000)
    create_dir_if_not_exists(output_filename)
    CSV.write(output_filename, df) 
    return df
end

function local_search_iteration(group_name, first_row, rows_num_local_search, sorted_df, i_columns, duration_ms_per_row, sut_name, local_search_dataframe)
    total_rows = 0

    if first_row === nothing
        return total_rows, local_search_dataframe
    end

    for row_num in first_row:(min(rows_num_local_search+first_row-1, nrow(sorted_df)-1))  # iterate for rows_num_local_search or until the end of the dataframe
        current_solution = collect(sorted_df[row_num, i_columns])  # convert to a vector [i1_1, i1_2, i2_1, i2_2]

        search_area_dims = calculate_localsearch_dims(sorted_df, row_num, i_columns, current_solution)
        max_distance = max_distance_inside_search_area(search_area_dims)

        emitter = LocalSearchEmitter(i_columns, round(Int, duration_ms_per_row), sut_name, search_area_dims, max_distance)
        append!(local_search_dataframe, ask(emitter))

        total_rows += 1
    end

    return total_rows, local_search_dataframe
end

function get_local_search_rows_num_per_validity_group(df::DataFrame)
    # Step 1: Determine total rows to search
    total_rows_search = 100

    # Step 2: Calculate initial row counts based on percentages
    vv_rows_search = round(Int, local_search_vv_ratio * total_rows_search)
    ve_rows_search = round(Int, local_search_ve_ratio * total_rows_search)
    ee_rows_search = round(Int, local_search_ee_ratio * total_rows_search)

    # Step 3: Count actual rows available in each group in the DataFrame
    vv_available = sum(df.bd_validity_group .== 0)
    ve_available = sum(df.bd_validity_group .== 1)
    ee_available = sum(df.bd_validity_group .== 2)

    # Step 4: Determine if each group has enough rows, and calculate deficits if not
    vv_deficit = max(0, vv_rows_search - vv_available)
    ve_deficit = max(0, ve_rows_search - ve_available)
    ee_deficit = max(0, ee_rows_search - ee_available)

    # Step 5: Adjust rows to account for deficits and redistribute according to priority
    vv_rows_search = min(vv_rows_search, vv_available)
    ve_rows_search = min(ve_rows_search, ve_available)
    ee_rows_search = min(ee_rows_search, ee_available)

    # Total deficit across all groups
    total_deficit = vv_deficit + ve_deficit + ee_deficit

    # Allocate deficits with priority: VV -> VE -> EE
    vv_rows_search += min(total_deficit, vv_available - vv_rows_search)
    total_deficit -= min(total_deficit, vv_available - vv_rows_search)

    ve_rows_search += min(total_deficit, ve_available - ve_rows_search)
    total_deficit -= min(total_deficit, ve_available - ve_rows_search)

    ee_rows_search += min(total_deficit, ee_available - ee_rows_search)

    return vv_rows_search, ve_rows_search, ee_rows_search
end


function signed_delta(a, b)
    if sign(a) == sign(b)
        return a>=b ? (a - b) : (b - a)  # we check explicitly to avoid UInt128 overflow
    else
        return abs(a) + abs(b)
    end
end