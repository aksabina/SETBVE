abstract type AbstractGridArchive{S,E} <: AbstractArchive{S,E} end
cellside(a::AbstractGridArchive) = 1

# cell was empty
struct NewCellStatus <: ArchiveStatus
    cell
end

# cell had a solution replaced by a better one 
struct BetterEvaluationStatus <: ArchiveStatus  
    cell
    newsolution
    neweval
    oldeval
end

# new solution is worse than the stored solution
struct NoUpdateStatus <: ArchiveStatus end   

# returns a list containing coordinates of a cell. With a cellside=1, the coordinates of the cell are the values of the behavioral descriptors
function cellid(archive::AbstractGridArchive{S,E}, evaluation::E) where {F,BD<:AbstractVector{<:Number},S<:AbstractDict{String,Any},E<:AbstractEvaluation{F,BD}}
    bd_values = behavioraldescriptors(evaluation) 
    ndims = length(bd_values)
    
    cell_coordinates = Vector{Int}(undef, ndims)
    cell_coordinates = [round(Int, bd_values[i] / cellside(archive)) for i in 1:ndims]

    return cell_coordinates
end


struct IntGridArchive{S,E} <: AbstractGridArchive{S,E}
    grid::Dict{Vector{Int},Int} # maps gridified behavioral descriptors into indices of the cells array
    cells::Vector{Tuple{S,E}} # (solution, evaluation) per cell
    cellside::Int8
end

IntGridArchive{S,E}(cellside::Int8=Int8(1)) where {E,S<:AbstractDict{String,Any}} =
    IntGridArchive{S,E}(Dict{Vector{Int},Int}(), Tuple{S,E}[], cellside)

archivesize(a::IntGridArchive) = length(a.grid)
cells(a::IntGridArchive) = [(key, a.cells[idx]) for (key, idx) in a.grid]
cellids(a::IntGridArchive) = [key for key in keys(a.grid)]  # cellid is the behav descriptor (coordinates)

# potentially add a new solution to the archive
function add!(archive::IntGridArchive{S,E}, solution::S, evaluation::E) where {S,E}
    cid = cellid(archive, evaluation)  # cellid is the behav descriptor (coordinates)
    idx = get(archive.grid, cid, nothing)  #* get "flattened" index (location) of the cid. Return nothing if not found
    if isnothing(idx)  # the cell is empty   
        push!(archive.cells, (solution, evaluation))
        archive.grid[cid] = archivesize(archive) + 1 
        return NewCellStatus(cid)
    else
        oldcell = archive.cells[idx]  #* get content of the cell
        oldeval = oldcell[2]  # evaluation is stored on position 2 of cell [solution, evaluation]
        if isbetter(evaluation, oldeval)
            archive.cells[idx] = (solution, evaluation)  # replace the existing solution stored in the archive 
            return BetterEvaluationStatus(cid, solution, evaluation, oldeval)
        else
            return NoUpdateStatus()
        end
    end
end 
    
function reportfeedback(o::AbstractOptimizer, f::NewCellStatus)

    parent1_idx = o.emitter.parent1_idx

    if parent1_idx == 0  # there are no parents (e.g., BitUniformRandomEmitter)
        #printstyled("New cell added: $(f.cell)\n"; color=:blue)
        return  # return to save compute resources 
    end

    o.emitter.archive.cells[parent1_idx][1]["curiosity"] += 1
    parent2_idx = o.emitter.parent2_idx

    if parent2_idx != 0  # there are no parents for bituniform emitter 
        o.emitter.archive.cells[parent2_idx][1]["curiosity"] += 1
    end
    
    
    #printstyled("New cell added: $(f.cell)\n"; color=:blue)
end

function reportfeedback(o::AbstractOptimizer, f::NoUpdateStatus)

    parent1_idx = o.emitter.parent1_idx

    if parent1_idx == 0  # there are no parents (e.g., BitUniformRandomEmitter)
       #printstyled("No archive update!\n"; color=:red)
       return  # return to save compute resources 
    end

    o.emitter.archive.cells[parent1_idx][1]["curiosity"] -= 0.5
    parent2_idx = o.emitter.parent2_idx

    if parent2_idx != 0  # there are no parents for bituniform emitter 
        o.emitter.archive.cells[parent2_idx][1]["curiosity"] -= 0.5
    end
    

    #printstyled("No archive update!\n"; color=:red)
end

function reportfeedback(o::AbstractOptimizer, f::BetterEvaluationStatus)
    
    parent1_idx = o.emitter.parent1_idx

    if parent1_idx == 0  # there are no parents (e.g., BitUniformRandomEmitter)
        #printstyled("Better candidate found: $(f.newsolution)\n  old fitness: $(f.oldeval)\n  new fitness: $(f.neweval)\n"; color=:green)
        return  # return to save compute resources 
    end

    o.emitter.archive.cells[parent1_idx][1]["curiosity"] += 1
    parent2_idx = o.emitter.parent2_idx

    if parent2_idx != 0  # there are no parents for bituniform emitter 
        o.emitter.archive.cells[parent2_idx][1]["curiosity"] += 1
    end

    #printstyled("Better candidate found: $(f.newsolution)\n  old fitness: $(f.oldeval)\n  new fitness: $(f.neweval)\n"; color=:green)
end