using Statistics 
const OutputAbstractions = Dict{Any,Int}() # Ensure unique number per abstraction

function num_exceptions(args)
    # Check if each input contains the word "error" (case insensitive)
    count_contains_error = sum(map(o -> occursin(r"(?i)error", o), [string(args[1]), string(args[2])]))
    return count_contains_error
end

function output_abstraction_number(args)
    
    o1, o2 = string(args[1]), string(args[2])

    # extract error type if any 
    o1_error = Base.match(r"^[\w]+Error", o1)  
    o1 = (o1_error !== nothing) ? o1_error.match : o1  
    o2_error = Base.match(r"^[\w]+Error", o2)
    o2 = (o2_error !== nothing) ? o2_error.match : o2


    key = lexorderjoin(o1, o2, ", ")

    global OutputAbstractions

    # return the number corresponding to the key (key e.g, NormalOverweight), or length of dict if not found 
    return get!(OutputAbstractions, key, length(OutputAbstractions) + 1) 
end

function output_length_diff(args)
    o1, o2 = string(args[1]), string(args[2])

    # extract error type if any 
    # o1_error = Base.match(r"^[\w]+Error", o1)
    # o1 = (o1_error !== nothing) ? o1_error.match : o1
    # o2_error = Base.match(r"^[\w]+Error", o2)
    # o2 = (o2_error !== nothing) ? o2_error.match : o2
    return abs(length(o1) - length(o2))
end


function total_input_length(args)
    args_num = length(args[1])
    if args_num == 2
        return length(string(args[1][1])) + length(string(args[1][2])) + length(string(args[2][1])) + length(string(args[2][2]))
    elseif args_num == 3
        return length(string(args[1][1])) + length(string(args[1][2])) + length(string(args[1][3])) + length(string(args[2][1])) + length(string(args[2][2])) + length(string(args[2][3]))
    elseif args_num == 1
        return length(string(args[1][1])) + length(string(args[2][1]))
    end
end

function var_input_length(args)
    lengths = [length(string(x)) for x in vcat(Vector{Any}(args[1]), Vector{Any}(args[2]))]
    variance_length = Int(floor(Statistics.var(lengths)))
    
    return variance_length
end


behav_desc_functions_dic = Dict(
    "validity_group" => num_exceptions,
    "oan" => output_abstraction_number,
    "out_length_diff" => output_length_diff, 
    "in_length_total" => total_input_length, 
    "in_length_var" => var_input_length, 
)