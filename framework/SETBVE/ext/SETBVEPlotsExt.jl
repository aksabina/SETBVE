# SETBVE's figures: a package extension, loaded when the code using SETBVE loads Plots (`using Plots`). It defines
# plot_zoomed_scatter and the other plotting functions in plots.jl.
module SETBVEPlotsExt

using SETBVE, DataFrames, StatsBase
import SETBVE: plot_zoomed_scatter
using SETBVE: circle_center_x, circle_center_y, circleA_center_x, circleA_center_y, circleB_center_x, circleB_center_y,
              radius, radiusA, radiusB, create_dir_if_not_exists, dir_plots, fig_size_dic, fitness_plot_threshold,
              lexorderjoin, num_exceptions, output_color_map, output_dir, range_zoomed_dic, verbose

include("plots.jl")

end  # module
