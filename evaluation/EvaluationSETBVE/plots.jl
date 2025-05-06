using DataStructures  # for OrderedDict
using Plots.PlotMeasures  # for px

# Convert a method name to its canonical form.
function rename_bituniform_method(method::String)
    if method == "S:Bituniform"
        return "S:CTS+BU"   # Rename Bituniform to CTS+BU
    elseif method == "S+T:Bituniform"
        return "S+T:CTS+BU"
    else
        return method
    end
end

# Return a sort order (an integer) for a given canonical method name.
function method_sort_order(method::String)
    custom_order = Dict(
       "AutoBVA"        => 1,
       "S:Random"       => 2,
       "S:CTS+BU"       => 3,
       "S+E:Curiosity"  => 4,
       "S+E:Fitness"    => 5,
       "S+E:Uniform"    => 6,
       "S+T:CTS+BU"     => 7,
       "S+T:Curiosity"  => 8,
       "S+T:Fitness"    => 9,
       "S+T:Uniform"    => 10,
       "S+E+T:Curiosity"=> 11,
       "S+E+T:Fitness"  => 12,
       "S+E+T:Unifrom"  => 13
    )
    return get(custom_order, method, 14)  # Methods not in the dict get order 13
end



function find_unique_cells_pairwise(sut_name::String, run_duration::Integer, emitter::String, sampling_strategy::Union{String, Nothing}, 
    refine_budget::Union{Integer, Nothing}, args)

    if args[2] != run_duration  # This way we iterate only through the requested run_duration
        return 
    end
    combinations_dict = Dict()
    
    df = load_dataframe(sut_name, run_duration, emitter, sampling_strategy, refine_budget, ["AggregatedArchive" , args[1]])
    

    prefix = ""

    if refine_budget == 0
        if emitter == "AutoBVA"
            method_name = "AutoBVA"
        elseif emitter == "Bituniform"
            prefix = "S:"  # Sampler
            method_name = "$(prefix)CTS+BU"
        elseif emitter == "Random"
            prefix = "S:"
            method_name = "$(prefix)$(emitter)"
        else
            prefix = "S+E:"  # Sampler, Explorer
            method_name = "$(prefix)$(sampling_strategy)"
        end
    else
        if emitter == "Bituniform"
            prefix = "S+T:"  # Sampler, Tracer
            method_name = "$(prefix)CTS+BU"
        
        else
            prefix = "S+E+T:"  # Sampler, Explorer, Tracer
            method_name = "$(prefix)$(sampling_strategy)"
        end
    end

    if nrow(df) == 0 
        combinations_dict[method_name] = Set()
        return combinations_dict
    end

    sorted_column_names = sort(names(df))
    df = df[:, sorted_column_names] # sort column names to make sure that the order of bd columns is correct 
    cell_columns = filter(name -> startswith(name, "bd_"), names(df))

    unique_bd_combinations = unique(df[:, cell_columns])
    combinations_dict[method_name] = Set(eachrow(unique_bd_combinations))

    return combinations_dict
end

function plot_heatmap_paiwise_cells(sut_name::String, run_duration::Integer; top_ranked_only = false)
    include_autobva = true  # Always include AutoBVA in the pairwise comparison
    prefix = top_ranked_only ? "TopRanked" : "UniqueCells"
    list_bd_combinations_per_method = iterate_function(find_unique_cells_pairwise, sut_name; args=[prefix, run_duration])

    num_methods = length(list_bd_combinations_per_method)
    # Matrix dimensions: one row per method and one extra column for "Any other"
    overlap_matrix = zeros(Float64, num_methods, num_methods+1) 

    dict_bd_combinations_per_method = reduce(merge, list_bd_combinations_per_method)

    # Sort the method keys using our custom order (apply canonical renaming for sorting)
    sorted_method_keys = sort(collect(keys(dict_bd_combinations_per_method)),
        by = x -> method_sort_order(rename_bituniform_method(x))
    )
    # Use the canonical names for display (i.e. row labels)
    canonical_sorted_method_names = [rename_bituniform_method(x) for x in sorted_method_keys]

    # Build an ordered dictionary based on the sorted keys
    sorted_bd_combinations_dict = OrderedDict(k => dict_bd_combinations_per_method[k] for k in sorted_method_keys)
    
    # Fill in the overlap matrix for each pair of methods
    for i in 1:num_methods
        for j in 1:num_methods
            key_i = sorted_method_keys[i]
            key_j = sorted_method_keys[j]
            unique_j_count = length(setdiff(sorted_bd_combinations_dict[key_j], sorted_bd_combinations_dict[key_i]))
            overlap_matrix[j, i] = unique_j_count
        end
    end

    # Compute the globally unique BD count per method (for the extra column)
    dict_global_unique_bd_count = Dict()
    for (method, combinations) in sorted_bd_combinations_dict
        other_methods_union = Set()
        for (other_method, other_combinations) in sorted_bd_combinations_dict
            if other_method != method
                other_methods_union = union(other_methods_union, other_combinations)
            end
        end
        global_unique_combinations = setdiff(combinations, other_methods_union)
        dict_global_unique_bd_count[method] = length(global_unique_combinations)
    end

    # Fill the extra column (last column) with the global unique counts.
    for (i, method_name) in enumerate(sorted_method_keys)
        overlap_matrix[i, num_methods+1] = dict_global_unique_bd_count[method_name]
    end

    # For the CSV, we want:
    # - Row labels: the canonical method names (length = N)
    # - Column headers: the canonical method names plus an extra "Any other" (length = N+1)
    row_labels = canonical_sorted_method_names
    col_headers = vcat(row_labels, "Any other")

    # Save the overlap matrix to a CSV file.
    output_filename = "Plots/Diversity/$(prefix)/PairwiseHeatmap$(prefix)$(sut_name)$(run_duration).csv" 
    create_dir_if_not_exists(output_filename)

    # Convert overlap matrix values to integers.
    overlap_matrix_int = round.(Int, overlap_matrix)
    df_overlap = DataFrame(overlap_matrix_int, :auto)
    
    if size(df_overlap, 2) != length(col_headers)
        error("Mismatch: DataFrame has $(size(df_overlap, 2)) columns but expected $(length(col_headers)).")
    end

    # Add the row labels as the first column.
    df_overlap.Method = row_labels
    df_overlap = select(df_overlap, :Method, :)
    
    # Rename columns: first "Method" then the column headers.
    rename!(df_overlap, vcat(["Method"], string.(col_headers)))
    
    CSV.write(output_filename, df_overlap)
        
    # (The remainder of your plotting code follows here unchanged.)
    plot_title = top_ranked_only ? "SUT: $(sut_name), Search duration: $(run_duration) sec\nComparison of Boundary Candidates Uniquely Discovered by Different Methods" : 
                                    "$(sut_name) $(run_duration) sec\nPairwise Comparison in Discovered Archive Cells"
    
    color_bins = range(0, stop=maximum(overlap_matrix), length=5)
    color_scheme = top_ranked_only ? purple_color_scheme : blue_color_scheme

    p = heatmap(overlap_matrix, xlabel="Not found by Method", ylabel="Found by Method", fig_size = fig_size, rotation = 30, 
        xticks=(1: num_methods+1, col_headers), yticks=(1:num_methods, row_labels), color=color_scheme, 
        colorbins = color_bins,
        clims = (0, maximum(overlap_matrix)),
        titlefontsize=12,
        xguidefontsize=10, 
        yguidefontsize=10, 
        colorbar_titlefontsize=10, 
        colorbar_titlepadding=15px, 
        colorbar_ticks=color_bins, 
        colorbar_tick_labels=string.(round.(color_bins)), 
        dpi=dpi,
        xtickfontsize=6, 
        ytickfontsize=6
    )        
        
    # Annotate each cell with its value.
    for i in 1:size(overlap_matrix, 1)
        for j in 1:size(overlap_matrix, 2)
            p = annotate!(j, i, text(round(Int, overlap_matrix[i, j]), 5, :black))
        end
    end

    # Add a vertical line between the data columns and the extra column.
    x_pos = size(overlap_matrix, 2) - 0.5
    p = vline!([x_pos], color=:black, lw=1, legend=false)
    
    # Save the plot (adjusting the output filename extension).
    output_filename = replace(output_filename, ".csv" => ".png")
    create_dir_if_not_exists(output_filename)
    savefig(p, output_filename)
end


function plot_qd_scatter(sut_name::String; top_ranked_only=false, all_groups=true)

    if top_ranked_only
        additional_arg = "TopRanked"
    else
        if all_groups
            additional_arg = "UniqueCells"
        else
            additional_arg = "NoPD0"
        end 
    end

    diversity_filename = "$(path_stats)/$(sut_name)/$(sut_name)ArchiveCoverage$(additional_arg).csv"
    quality_filename = "$(path_stats)/$(sut_name)/$(sut_name)Quality$(additional_arg).csv"

    df_diversity = CSV.read(diversity_filename, DataFrame)
    df_quality = CSV.read(quality_filename, DataFrame)

    df_diversity.TraceBudget = coalesce.(df_diversity.TraceBudget, "")
    df_quality.TraceBudget = coalesce.(df_quality.TraceBudget, "")
    df_quality.PDMeanPhase2 = coalesce.(df_quality.PDMeanPhase2, df_quality.PDMeanPhase1)
    df_diversity.CoverageMean2 = coalesce.(df_diversity.CoverageMean2, df_diversity.CoverageMean1)

    df_diversity.method_name = ["$(row.Duration)sec:$(row.Method)$(row.TraceBudget)" for row in eachrow(df_diversity)]
    df_quality.method_name = ["$(row.Duration)sec:$(row.Method)$(row.TraceBudget)" for row in eachrow(df_quality)]

    # Merge the two dataframes on method_name to align CoverageMean2 and PDMeanPhase2
    df_combined = innerjoin(df_diversity[:, [:method_name, :CoverageMean2]], 
                            df_quality[:, [:method_name, :PDMeanPhase2]], 
                            on=:method_name)

    # Extract the data for plotting
    x = df_combined.CoverageMean2
    y = df_combined.PDMeanPhase2
    labels = df_combined.method_name
    # Assign colors based on the method name
    point_colors = []
    for label in labels
        if label == "30sec:AutoBVA0"
            label = "30sec:AutoBVA"
        elseif label == "600sec:AutoBVA0"
            label = "600sec:AutoBVA"
        end
        push!(point_colors, method_colors[label])
    end


    # Plot settings
    p = scatter(x, y, 
        label=labels, 
        xlabel="Mean Archive Coverage, %", 
        ylabel="Mean PD/PD_max", 
        title="Coverage vs PD for $sut_name ($(additional_arg))",
        xlim=(-1, maximum(x) + 10), 
        ylim=(-0.1, 1.1), 
        color=point_colors,
        marker=(4, :circle), 
        fig_size=(2400, 800), 
        dpi=dpi, alpha=0.5, legend=false)

    # Annotate each point with jittered labels
    for i in 1:length(labels)
        # Generate small random jitter values
        #jitter_x = rand([0, 0.5, 1])  # Jitter for x-axis
        jitter_y = rand([-0.02, -0.04, 0.04, 0.02]) # Jitter for y-axis

        # Annotate with a slight shift
        annotate!(x[i], y[i] + jitter_y, text(labels[i], :left, 3, point_colors[i]))
    end


    output_filename = "$(path_plots)/$(sut_name)QvsD$(additional_arg).png"
    create_dir_if_not_exists(output_filename)
    savefig(p, output_filename)


end
