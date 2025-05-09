using Pkg
Pkg.activate(@__DIR__)      # activates the folder where the file lives
Pkg.instantiate()  

include("EvaluationSETBVE.jl")
using .EvaluationSETBVE

sut_name = ARGS[1] # bmi, circle, date, bytecount, bytecount, power_by_squaring, tailjoin, max, cld, fldmod1, fld

println(sut_name, ": Converting AutoBVA to Archive structure") 
rename_autobva_files(sut_name)
preprocess_autobva_df(sut_name)

println(sut_name, ": SETBVE evaluation started") 
iterate_function(assign_oan, sut_name)
iterate_function(assign_boundary_candidate_rank, sut_name)
iterate_function(aggregate_archive, sut_name)
iterate_function(extract_unique_cells_from_agg_archive_per_method, sut_name; args = ["UniqueCells"])
extract_unique_cells_from_agg_archive_per_sut(sut_name)
iterate_function(add_max_fitness_column, sut_name)

println("Analysing Top ranked solutions")
save_top_ranked_cells_per_sut(sut_name)
iterate_function(save_top_ranked_cells_per_method, sut_name; args = ["TopRanked"])
println(sut_name, ": Plotting pairwise heatmaps for top solutions")
plot_heatmap_paiwise_cells(sut_name, 600; top_ranked_only=true)
plot_heatmap_paiwise_cells(sut_name, 30; top_ranked_only=true)
println(sut_name, ": Calculating relative archive coverage (RAC)")
save_archive_coverage(sut_name; top_ranked_only=true, all_groups=false)


# # Quality metrics
println(sut_name, ": Calculating relative program derivative (RPD)")
save_pd_metrics(sut_name; top_ranked_only=true, all_groups=false)  # Top ranked only
