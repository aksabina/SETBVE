using Random


# ask Emitter to generate numcandidates number of solutions 
ask(e::AbstractEmitter{S}, numcandidates::Int) where {S} =
    return (1, S[ask(e) for _ in 1:numcandidates])

struct BitUniformRandomEmitter <: AbstractEmitter{S} 
    arg_number::Int8
    parent1_idx::Int8
    parent2_idx::Int8
end

struct RandomEmitter <: AbstractEmitter{S} 
    arg_number::Int8
    parent1_idx::Int8
    parent2_idx::Int8
end

mutable struct CrossoverAndMutateEmitter <: AbstractEmitter{S}
    archive::AbstractArchive
    bias_column::String
    parent1_idx::Integer
    parent2_idx::Integer
end


mutable struct MutateEmitter <: AbstractEmitter{S}
    archive::AbstractArchive
    bias_column::String
    parent1_idx::Integer
    parent2_idx::Integer
end


mutable struct LocalSearchEmitter <: AbstractEmitter{S}
    i_column_names::Vector{String}
    duration_per_row_ms::Integer
    sut_name::String
    search_area_dims::Vector{StepRange}
    max_distance::Number
end


function ask(e::BitUniformRandomEmitter)
    solution_vector = Integer[]
    for _ in 1:e.arg_number
        datatype = rand(datatypes)
        push!(solution_vector, bitlogsample(datatype))
    end
    return Dict("solution" => solution_vector, "curiosity" => 0.0)
end

function ask(e::RandomEmitter)
    solution_vector = Integer[]
    for _ in 1:e.arg_number
        push!(solution_vector, (rand(Int64)))
    end
    return Dict("solution" => solution_vector, "curiosity" => 0.0)
end

function ask(e::CrossoverAndMutateEmitter)
    parent1_idx, parent2_idx = sample(e.archive, 2, e.bias_column)
    parent1 = e.archive.cells[parent1_idx][1] 
    parent2 = e.archive.cells[parent2_idx][1]
    
    child_solution = crossover_arrays(parent1, parent2)  # single point crossover
    child_solution = Any[child_solution...]  # convert to type Any to be able to assign values of different types when mutating 

    # mutate one random position
    child_solution = shrink_move_mutation(child_solution)

    e.parent1_idx = parent1_idx
    e.parent2_idx = parent2_idx

    return Dict("solution" => child_solution, "curiosity" => 0.0)
end


function ask(e::MutateEmitter)
    parent_idx = sample(e.archive, 1, e.bias_column)[1]
    solution = deepcopy(e.archive.cells[parent_idx][1]["solution"])
    solution = Any[solution...]   

    # mutate one random position
    solution = shrink_move_mutation(solution)

    e.parent1_idx = parent_idx
    e.parent2_idx = 0  # this mutation uses one parent only

    return Dict("solution" => solution, "curiosity" => 0.0)
end


function ask(e::LocalSearchEmitter)
    neighbor_solutions = local_search(e.duration_per_row_ms, e.sut_name, e.search_area_dims, e.max_distance)
    neighbors_df = DataFrame([Symbol(col) => [] for col in e.i_column_names])

    for neighbor in neighbor_solutions
        new_row = Dict{Any,Any}()
        for (i, arg) in enumerate(neighbor)
            new_row[e.i_column_names[i]] = arg
        end
        append!(neighbors_df, DataFrame(new_row))
    end
    
    return neighbors_df
end 



tell!(e::BitUniformRandomEmitter) = nothing
tell!(e::RandomEmitter) = nothing
tell!(e::CrossoverAndMutateEmitter) = nothing
tell!(e::MutateEmitter) = nothing
tell!(e::LocalSearchEmitter) = nothing



function emit_solutions(o::DefaultOptimizer, sut_name, behav_descriptors)
    batchid, candidates = ask(o.emitter, o.batchsize) 
    N = length(candidates)
    evaluations = Array{evaluationtype(o.evaluator)}(undef, N)
    feedbacks = Array{ArchiveStatus}(undef, N)
    fitnesses = Array{Vector{Float64}}(undef, N)
    bd_values = Array{Vector{Any}}(undef, N)

    #Threads.@threads for i in 1:N  # evaluate solutions in parallel
    for i in 1:N
        fitnesses[i], bd_values[i] = evaluate(o.evaluator, sut_name, candidates[i], behav_descriptors)
        evaluations[i] = Evaluation(fitnesses[i], bd_values[i])
        
        f = feedbacks[i] = add!(o.archive, candidates[i], evaluations[i])
        reportfeedback(o, f)
        tell!(o.emitter)
    end
end
