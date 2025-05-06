using Plots, Statistics

function get_xlabel_ylabel(sut_name)
    if sut_name == "circle" || sut_name == "two_circles"
        return "X", "Y"
    elseif sut_name == "bmi"
        return "Weight", "Height"
    elseif sut_name == "date"
        return "Day", "Month"
    else
        return "Undefined", "Undefined"
    end
end

function split_by_color(df::DataFrame, col::Symbol)
    default_color = :black
    # double - means it's a valid Julia Date
    colors = [count(==('-'), val) >= 2 ? :green : get(output_color_map, val, default_color) for val in df[!, col]]
    return colors
end

function plot_circles!(sut_name::String, x_min::Integer, x_max::Integer, y_min::Integer, y_max::Integer)

    theta = LinRange(0, 2π, 100)

    if sut_name == "circle"
        x = circle_center_x .+ radius .* cos.(theta)
        y = circle_center_y .+ radius .* sin.(theta)
        Plots.plot!(x, y, aspect_ratio=:equal, legend=false, xlims=(x_min, x_max), ylims=(y_min, y_max), size=fig_size_dic[sut_name], color=:lightgray, label=false)
    elseif sut_name == "two_circles"
        x = circleA_center_x .+ radiusA .* cos.(theta)
        y = circleA_center_y .+ radiusA .* sin.(theta)
        Plots.plot!(x, y, aspect_ratio=:equal, legend=false, xlims=(x_min, x_max), ylims=(y_min, y_max), size=fig_size_dic[sut_name], color=:lightgray, label=false)
        
        x = circleB_center_x .+ radiusB .* cos.(theta)
        y = circleB_center_y .+ radiusB .* sin.(theta)
        Plots.plot!(x, y, aspect_ratio=:equal, legend=false, xlims=(x_min, x_max), ylims=(y_min, y_max), size=fig_size_dic[sut_name], color=:lightgray, label=false)
    end
end

function plot_zoomed_scatter(df::DataFrame, sut_name::String, emitter_type::String, bias_column::String, duration::Integer, vv_only::Bool, suffix::String, run_num::Integer, local_search_budget_ratio)
    println("Total number of records $(nrow(df))")
    df = filter(row -> row.fitness >= fitness_plot_threshold, df)
    
    if vv_only
        suffix = "$(suffix)(VV)"
        df = filter(row -> row.bd_validity_group == 0, df)
    end

    if bias_column == "NoSelection"
        output_filename = "$(dir_plots)Bituniform/$(sut_name)/$(duration)/$(sut_name)$(emitter_type)$(duration)$(suffix)-$(run_num).png"
    elseif bias_column == "AutoBVA"
        output_filename = "$(dir_plots)AutoBVA/$(sut_name)/$(duration)/$(sut_name)$(emitter_type)$(duration)$(suffix)-$(run_num).png"
    else
        output_filename = "$(dir_plots)$(round(Int,local_search_budget_ratio*100))%Tracer/$(bias_column)/$(sut_name)/$(emitter_type)/$(duration)/$(sut_name)$(emitter_type)$(bias_column)$(duration)$(suffix)-$(run_num).png"
    end
    
    xlabel, ylabel = get_xlabel_ylabel(sut_name)

    range_min_zoomed, range_max_zoomed = range_zoomed_dic[sut_name] 

    # filter out records out of zoomed range
    df = filter(row ->
            range_min_zoomed ≤ row.i1_1 ≤ range_max_zoomed &&
                range_min_zoomed ≤ row.i1_2 ≤ range_max_zoomed &&
                range_min_zoomed ≤ row.i2_1 ≤ range_max_zoomed &&
                range_min_zoomed ≤ row.i2_2 ≤ range_max_zoomed,
        # (haskey(row, :i1_3) ? range_min_zoomed ≤ row.i1_3 ≤ range_max_zoomed : true) &&  # filter i1_3 if it exists
        # (haskey(row, :i2_3) ? range_min_zoomed ≤ row.i2_3 ≤ range_max_zoomed : true),    # filter i2_3 if it exists
        df)

    sampling = (bias_column!="NoSelection") ? "$(bias_column) sampling" : ""
    title = "$(sut_name) SUT ($(duration) seconds, run $(run_num)) $(sampling)\nn=$(nrow(df)), PD>0.1, $(emitter_type) $(suffix)"
    println("Plotting zoomed in scatter with top $(nrow(df))")


    domain_error_pattern = r"DomainError"
    argument_error_pattern = r"ArgumentError"

    # Replace the error message with "DomainError" in output1 and output2 columns
    replace_errors!(df, :output1, domain_error_pattern, "DomainError")
    replace_errors!(df, :output1, argument_error_pattern, "ArgumentError")
    replace_errors!(df, :output2, domain_error_pattern, "DomainError")
    replace_errors!(df, :output2, argument_error_pattern, "ArgumentError")

    colors_output1 = split_by_color(df, :output1)
    colors_output2 = split_by_color(df, :output2)

    x1 = df[!, :i1_1]
    y1 = df[!, :i1_2]
    x2 = df[!, :i2_1]
    y2 = df[!, :i2_2]

    Plots.scatter(x1, y1, color=colors_output1, marker=:circle, markersize=2, markerstrokewidth=0.2, legend=false, label=false, xlims=(range_min_zoomed, range_max_zoomed), ylims=(range_min_zoomed, range_max_zoomed), dpi=1200, size=fig_size_dic[sut_name])
    plot = Plots.scatter!(x2, y2, color=colors_output2, marker=:circle, markersize=2, markerstrokewidth=0.2, legend=false, label=false, xlims=(range_min_zoomed, range_max_zoomed), ylims=(range_min_zoomed, range_max_zoomed), dpi=1200)

    if sut_name == "circle" || sut_name == "two_circles"
        plot_circles!(sut_name, range_min_zoomed, range_max_zoomed, range_min_zoomed, range_max_zoomed)
    end

    # Manually add legend for the color map
    unique_outputs = union(unique(df.output1), unique(df.output2))
    processed_outputs = [occursin("-", s) ? "ValidDate" : s for s in unique_outputs]  # for date SUT
    processed_outputs = unique(processed_outputs)

    for unique_output in processed_outputs
        index = findfirst(x -> x == get(output_color_map, unique_output, :black), colors_output1)
        if isnothing(index)
            index = findfirst(x -> x == get(output_color_map, unique_output, :black), colors_output2)
            Plots.scatter!([x2[index]], [y2[index]], color=colors_output2[index], marker=:circle, markersize=2, markerstrokewidth=0.2, label=unique_output, legend=true, xlims=(range_min_zoomed, range_max_zoomed), ylims=(range_min_zoomed, range_max_zoomed), dpi=1200)
        else
            Plots.scatter!([x1[index]], [y1[index]], color=colors_output1[index], marker=:circle, markersize=2, markerstrokewidth=0.2, label=unique_output, legend=true, xlims=(range_min_zoomed, range_max_zoomed), ylims=(range_min_zoomed, range_max_zoomed), dpi=1200)
        end
    end


    Plots.xlabel!(xlabel)
    Plots.ylabel!(ylabel)
    title!(title) 

    # save plot as PNG file
    create_dir_if_not_exists(output_filename)
    savefig(plot, output_filename)
end

# Define the function for calculating output abstraction number
function output_abstraction_number_with_key(args)
    o1, o2 = string(args[1]), string(args[2])

    # Extract error type if any
    o1_error = Base.match(r"^[\w]+Error", o1)
    o1 = (o1_error !== nothing) ? o1_error.match : o1
    o2_error = Base.match(r"^[\w]+Error", o2)
    o2 = (o2_error !== nothing) ? o2_error.match : o2

    # Create the key by lexicographically ordering the outputs
    
    key = o1==o2 ? "same" : lexorderjoin(o1, o2, ", ")

    global OutputAbstractions

    # Return the number corresponding to the key, or add new one if not found
    return get!(OutputAbstractions, key, length(OutputAbstractions) + 1), key
end

function add_oan_outputpairs_col!(df::DataFrame)
    # Initialize empty columns for bd_oan and outputpair
    n_rows = nrow(df)
    df[!, :outputpair] = fill("0", n_rows)
    df[!, :bd_oan] = fill(-1, n_rows)

    # Iterate through the rows and compute the abstraction number and key
    for row_idx in 1:n_rows
        row = df[row_idx, :]
        # Get the output abstraction number and the key
        if "n_output" in names(df)
            oan, key = output_abstraction_number_with_key([row.output, row.n_output])
        else
            oan, key = output_abstraction_number_with_key([row.output1, row.output2])
        end
        df.outputpair[row_idx] = key
        df.bd_oan[row_idx] = oan
    end

    return df
end

function add_validity_group_columns!(df::DataFrame)
    n_rows = nrow(df)
    df[!, :bd_validity_group] = fill("-1", n_rows)

    for row_idx in 1:n_rows
        row = df[row_idx, :]
        val_group = num_exceptions([row.output, row.n_output])
        df.bd_validity_group[row_idx] = "$val_group"
    end

    return df
end

# Function to count unique bd_oan values
function count_unique_bdoan(df::DataFrame)::Int
    if "bd_oan" in names(df)
        return length(unique(df.bd_oan))
    else
        println("Bd_oan not found in column list")
        return nothing
    end
end

# Function to plot bar chart for unique bd_oan values
function plot_unique_bdoan_counts(dfs::Dict{String,DataFrame}, sut_name)
    labels = collect(keys(dfs))  # Extract dictionary keys (dataset names) in the same order
    counts = [count_unique_bdoan(dfs[label]) for label in labels]  # Ensure counts follow the same order
    bar(labels, counts, legend=false, title="Number of Boundaries Found for $(sut_name)", xlabel="", ylabel="Count", size=fig_size_dic["default"])
end



# Function to group by key and plot the counts
function plot_counts_per_column(df::DataFrame, key_column::Symbol, method::String, sut_name::String)
    # Group by the key and count occurrences

    x_label_dic = Dict(
        :outputpair => "Boundary", 
        :bd_validity_group => "Validity Group"
    )
    
    df[!, string(key_column)] = string.(df[!, string(key_column)])  # to make it appear as category on the plot 
    counts = countmap(df[!, key_column])  # count occurrences of each key

    # Extract keys and values from the dictionary
    categories = collect(keys(counts))
    counts = collect(values(counts))

    # Create the bar plot
    plot = bar(categories, counts, legend=false, xlabel=x_label_dic[key_column], ylabel="Count", size=fig_size_dic["default"], title="$(method), $(sut_name)", rotation=45)
    # Increase the font size for the plot
    theme(:default, titlefont=18, guidefont=14, tickfont=12)
    output_filename = replace("$(dir_comparisons)$(bias_column)/$(sut_name)/$(x_label_dic[key_column])$(method).png", " " => "")
    savefig(plot, output_filename)
end