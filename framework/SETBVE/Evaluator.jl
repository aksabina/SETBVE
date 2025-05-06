behavioraldescriptors(e::AbstractEvaluation) = e.behavioraldescriptors
fitness(e::AbstractEvaluation) = e.fitness

evaluationtype(e::AbstractEvaluator{E}) where {E} = E
evaluate(e::AbstractEvaluator, sut_name, solution, behav_descriptors) = error("'evaluate' not implemented!")

struct Evaluation <: AbstractEvaluation{Vector{Float64},Vector{Int}}
    fitness::Vector{Float64}
    behavioraldescriptors::Vector{Int}
end

struct Evaluator <: AbstractEvaluator{Evaluation} end

function evaluate(e::Evaluator, sut_name::String, solution::Dict{String,Any}, behav_descriptors::Vector{<:String})

    i1, i2 = extract_i1_i2(solution["solution"])
    output1 = get_sut_output(i1, sut_name)
    output2 = get_sut_output(i2, sut_name) 

    fitness = calculate_pd(i1, i2, output1, output2)

    bd_fun_args = Dict{String, Vector{Any}}(
    "validity_group" => Any[output1, output2],
    "oan" => Any[output1, output2],
    "out_length_diff" => Any[output1, output2],
    "in_length_total" => Any[i1, i2],
    "in_length_var" => Any[i1, i2],
    "i1_1_bits" => Any[i1[1]],
    "i2_1_bits" => Any[i2[1]])

    fs = Float64[-fitness]  # invert the fitnesses so we can minimize => maximize PD
    bd_values = []


    for bd in behav_descriptors
        func = behav_desc_functions_dic[bd]
        args = bd_fun_args[bd]
        push!(bd_values, func(args))
    end


    return fs, bd_values
end

function hat_compare_pareto(u, v)
    res = 0
    @inbounds for i in 1:length(u)
        delta = u[i] - v[i]
        if delta >= 0.0
            if res == 0
                res = 1
            elseif res == -1
                return 0 # non-dominated
            end
        elseif delta < 0.0
            if res == 0
                res = -1
            elseif res == 1
                return 0 # non-dominated
            end
        end
    end
    return res
end

function isbetter(e1::AbstractEvaluation{F,BD}, e2::AbstractEvaluation{F,BD};
    minimizing::Bool=true) where {BD,F<:Vector{<:Number}}
    res = hat_compare_pareto(fitness(e1), fitness(e2))
    if (minimizing && res == -1) || (!minimizing && res == 1)
        return true   #* e1 is better than e2
    else
        return false  #* e2 is better than e1 
    end
end