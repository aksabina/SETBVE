using ProgressMeter

function iterate_function(fn::Function, sut_name::String; args=nothing)  # args[1] corresponds to include_autobva boolean
    results = []  
    list_emitter = (sut_name in ["bytecount", "bmi", "circle", "date"]) ? ["AutoBVA", "Bituniform", "Random", "Mutation"] : ["AutoBVA", "Mutation"]
    list_sampling_strategy = (sut_name in ["bytecount", "bmi", "circle", "date"]) ? ["Curiosity", "Fitness", "Uniform"] : ["Uniform"]  # Julia Base SUTs are evaluated only with Uniform sampling strategy
    p = Progress(length(list_run_duration) * length(list_emitter))

    for run_duration in list_run_duration
        for emitter in list_emitter

            if emitter == "Mutation" || emitter == "Bituniform"
                list_refine_budget = [0, 10]  
                for refine_budget in list_refine_budget
                    if emitter == "Mutation"
                        for sampling_strategy in list_sampling_strategy
                            result = fn(sut_name, run_duration, emitter, sampling_strategy, refine_budget, args)
                            if result !== nothing  # Only store non-nothing results
                                push!(results, result)
                            end
                        end
                    elseif emitter == "Bituniform"
                        result = fn(sut_name, run_duration, emitter, "NoSelection", refine_budget, args)
                        if result !== nothing  # Only store non-nothing results
                            push!(results, result)
                        end
                    end
                end
            
            else  # Random emitter
                result = fn(sut_name, run_duration, emitter, "NoSelection", 0, args)
                if result !== nothing  # Only store non-nothing results
                    push!(results, result)
                end
            end
            next!(p)
        end
            
    end

    return results  # Return the list of results
end


function parse_bigint_with_bool(value)
    if value == "false" || value == "FALSE" || value == "False"
        return BigInt(0)
    elseif value == "true" || value == "TRUE" || value == "True"
        return BigInt(1)
    elseif typeof(value) == String || typeof(value) == String15 || typeof(value) == String7 || typeof(value) == String31
        return parse(BigInt, value)
    else
        return BigInt(value)
    end
end


function create_dir_if_not_exists(filepath::String)
    last_slash_index = findlast('/', filepath)
    dirpath = filepath[1:last_slash_index]

    if !isdir(dirpath)
        mkpath(dirpath)
    end
end


function get_directory_path(main_dir::String, sut_name::String, run_duration::Integer, emitter::String,  
    sampling_strategy::Union{String, Nothing}, refine_budget::Union{Integer, Nothing})

    if emitter == "AutoBVA"
            directory = "$(main_dir)/$(emitter)/$(sut_name)/$(run_duration)/" 
    elseif emitter == "Random" || emitter == "Bituniform" 
        directory = "$(main_dir)/$(refine_budget)%Tracer/NoSelection/$(sut_name)/$(emitter)/$(run_duration)/"
    else
        directory = "$(main_dir)/$(refine_budget)%Tracer/$(sampling_strategy)/$(sut_name)/$(emitter)/$(run_duration)/"
    end

    return directory

end


function get_filename(main_dir::String, sut_name::String, run_duration::Integer, emitter::String, 
    sampling_strategy::Union{String, Nothing}, refine_budget::Union{Integer, Nothing}, extension::String, prefix::Union{String, Nothing})

    directory = get_directory_path(main_dir, sut_name, run_duration,  emitter, sampling_strategy, refine_budget)
    
    if emitter == "AutoBVA"
        filename = (prefix==nothing) ? "$(directory)$(main_dir)$(sut_name)$(run_duration).$(extension)" : "$(directory)$(prefix)$(main_dir)$(sut_name)$(run_duration).$(extension)"
    elseif emitter == "Random" || emitter == "Bituniform"
        filename = (prefix==nothing) ? "$(directory)$(main_dir)$(sut_name)NoSelection$(run_duration).$(extension)" : "$(directory)$(prefix)$(main_dir)$(sut_name)NoSelection$(run_duration).$(extension)"

    else
        filename = (prefix==nothing) ? "$(directory)$(main_dir)$(sut_name)$(sampling_strategy)$(run_duration).$(extension)" : "$(directory)$(prefix)$(main_dir)$(sut_name)$(sampling_strategy)$(run_duration).$(extension)"
    end

    return filename
end


function load_dataframe(sut_name::String, run_duration::Integer, emitter::String, sampling_strategy::Union{String, Nothing}, refine_budget::Union{Integer, Nothing}, args)
    main_dir = args[1]
    prefix = args[2]
    input_filename = get_filename(main_dir, sut_name, run_duration, emitter, sampling_strategy, refine_budget, "csv", prefix)
    df = CSV.read(input_filename, DataFrame, types=String)
    df[!, :top_pd_config] .= "$(run_duration)$(emitter)$(sampling_strategy)$(refine_budget)"

    return df
end