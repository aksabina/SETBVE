module SETBVE
using Distances, Dates, CSV, DataFrames, ProgressMeter, Base

include("interfaces.jl")
include("constants.jl")
include("suts.jl")
include("distances.jl")
include("utils.jl")
include("plots.jl")

include("Optimiser.jl")
include("Emitter.jl")
include("Archive.jl")
include("BehavioralDescriptor.jl")
include("Evaluator.jl")

include("runparameters.jl")


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
distance_jaccard,

# Archive.jl
IntGridArchive,
cellid, archivesize, cells, cellids,
reportfeedback,

# utils.jl
bitlogsample, sample,
lexorderjoin,
save_archive_to_csv, calculate_localsearch_dims,
max_distance_inside_search_area, 
shrink_move_mutation, local_search, local_search_iteration, 
replace_errors!, extract_i1_i2, calculate_pd, get_sut_output, 
append_archive_with_local_search_sols, get_local_search_rows_num_per_validity_group,

# plots.jl
plot_zoomed_scatter,

# Optimiser.jl
DefaultOptimizer,

# Emitter.jl
BitUniformRandomEmitter,
emit_solutions, ask, 
MutateEmitter, 
LocalSearchEmitter, 
RandomEmitter,

# BehavioralDescriptor.jl
behav_desc_functions_dic,

# Evaluator.jl
Evaluator, Evaluation,
isbetter,

# runparameters.jl
bituniform_init_budget_ratio, 
behavioural_descriptors,
number_of_runs

end  # module