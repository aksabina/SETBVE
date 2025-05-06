S = Dict{String,Any}  #* solution
F = Vector{Float64}  #* fitness
BD = Vector{Float64}  #* behaviour descriptors

# Archive stores solutions of type S having an evaluation of type E
abstract type AbstractArchive{S,E} end
# ArchiveStatus is a feedback from Archive about a new solution
# Basic ArchiveStatus: NewCell, BetterSolution, NoUpdate 
abstract type ArchiveStatus end

# Emitter generates solution of type S
abstract type AbstractEmitter{S} end

# Evaluation contains both the fitness F and the behaviour descriptors BD.
abstract type AbstractEvaluation{F,BD} end
# Evaluator evaluates solutions and returns Evaluations {F, BD}
abstract type AbstractEvaluator{E} end

# Optimizer passes information between Archive, Evaluator and Emitter
abstract type AbstractOptimizer end
