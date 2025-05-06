module EvaluationSETBVE 
using CSV, DataFrames, Glob
using Statistics
using StatsBase
using Plots

include("constants.jl")
include("utils.jl")
include("preprocessing.jl")
include("diversity_metrics.jl")
include("plots.jl")
include("quality_metrics.jl")

export 

# constants
path_agg_archive, path_archive, path_stats, path_plots,
list_run_duration,
purple_color_scheme, fig_size, dpi, blue_color_scheme, method_colors, path_autobva, top_rank_quantile,

# utils
create_dir_if_not_exists, get_filename, get_directory_path, 
iterate_function, 
load_dataframe, 
parse_bigint_with_bool,

# preprocessing
aggregate_archive, 
extract_unique_cells_from_agg_archive_per_method,
extract_unique_cells_from_agg_archive_per_sut,
add_max_fitness_column, assign_oan, assign_boundary_candidate_rank, 
rename_autobva_files, preprocess_autobva_df, 

# diversity_metrics
save_archive_coverage,

# plots.jl
plot_heatmap_paiwise_cells, plot_qd_scatter,


# quality_metrics.jl 
save_top_ranked_cells_per_sut, save_top_ranked_cells_per_method,
save_pd_metrics


end # module