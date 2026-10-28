module SETBVE
using StatsBase, Random, Base.Threads
using Statistics
using StringDistances, InformationDistances
using Printf
using Distances, Dates, CSV, DataFrames, ProgressMeter, Base

# Plots (for main.jl's figures) and PyCall (for the python_normalize SUT) are optional. Set the environment variable
# SETBVE_PLOTS=false or SETBVE_PYTHON=false before loading SETBVE to leave them out, e.g. when they aren't installed.
const WITH_PLOTS = !(get(ENV, "SETBVE_PLOTS", "true") in ("false", "0"))
const WITH_PYTHON = !(get(ENV, "SETBVE_PYTHON", "true") in ("false", "0"))

if WITH_PYTHON
    using PyCall
    include("python_suts.jl")
end

include("interfaces.jl")
include("constants.jl")
include("suts.jl")
include("distances.jl")
include("utils.jl")
if WITH_PLOTS
    include("plots.jl")
end

include("Optimiser.jl")
include("Emitter.jl")
include("Archive.jl")
include("BehavioralDescriptor.jl")
include("Evaluator.jl")

include("runparameters.jl")
include("search.jl")


export

# interfaces.jl
S, F, BD, 
AbstractArchive, ArchiveStatus, 
AbstractEmitter, AbstractOptimizer,
AbstractEvaluation, AbstractEvaluator,

# constants.jl
batch_size, total_args_num, 
radius, circle_center_x, circle_center_y,
radiusA, circleA_center_x, circleA_center_y,
radiusB, circleB_center_x, circleB_center_y,
datatypes, local_search_neighbors_num,
dir_archive, dir_plots, local_search_delta_calc_rows,
fig_size_dic, range_zoomed_dic, fitness_plot_threshold, 
output_color_map, dir_comparisons, 
default_parent_id,

# suts.jl
sut_functions_dic,

# distances.jl
distance_jaccard, distance_ncd,

# Archive.jl
IntGridArchive,
cellid, archivesize, cells, cellids,
reportfeedback,

# utils.jl
set_output_dir!, set_verbose!,
bitlogsample, sample,
lexorderjoin,
save_archive_to_csv, calculate_localsearch_dims,
max_distance_inside_search_area, 
shrink_move_mutation, local_search, local_search_iteration, vector_mutation,
replace_errors!, extract_i1_i2, calculate_pd, get_sut_output, 
append_archive_with_local_search_sols, get_local_search_rows_num_per_validity_group,

# plots.jl
plot_zoomed_scatter,

# Optimiser.jl
DefaultOptimizer,

# Emitter.jl
BitUniformRandomEmitter,
BitUniformVectorRandomEmitter,
emit_solutions, ask, 
MutateEmitter, MutateVectorEmitter,
LocalSearchEmitter, LocalSearchVectorEmitter,
RandomEmitter,

# BehavioralDescriptor.jl
behav_desc_functions_dic, var_array_length, var_input_length, total_array_length, total_input_length, output_length_diff, num_exceptions,

# Evaluator.jl
Evaluator, Evaluation,
isbetter,

# runparameters.jl
bituniform_init_budget_ratio, 
behavioural_descriptors,
number_of_runs,

# search.jl
register_descriptor!, register_sut!, run_search

end  # module