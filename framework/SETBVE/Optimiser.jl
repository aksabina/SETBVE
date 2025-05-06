# Default optimizer ask emitter for a batch of new candidate solutions,
# evaluates them in parallel and then adds them to the archive.
# The evaluations and the archive feedback is then told to the emitter
# so it can, optionally, use the feedback to improve future emitting.
# This is called a scheduler in the RIBS framework.
struct DefaultOptimizer <: AbstractOptimizer
    batchsize::Int   # number of new candidate solutions
    archive::AbstractArchive  # stores solutions
    emitter::AbstractEmitter  # receives the evaluations and archive feedback from Optimizer 
    evaluator::AbstractEvaluator  # evaluator evaluates the candidate solutions
end