using CSV
using DataFrames
using Glob
using Statistics


function get_fitness_threshold(df; quantile_thresh=0.99)
    
    fitness_quantile = quantile(df[!, :fitness], quantile_thresh)

    println("Fitness quantile at ", quantile_thresh, ": ", fitness_quantile)

    return fitness_quantile
    
end

function average_rows_with_fitness(dir::AbstractString, fitness_threshold::Float64)
    files = glob("*.csv", dir)
    if isempty(files)
        @warn "No CSV files found in $dir"
        return 0.0
    end

    total_rows = 0
    counted_files = 0
    for f in files
        df = CSV.read(f, DataFrame)
        if "fitness" in names(df)
            # keep rows with fitness > 0
            filtered = filter(:fitness => x -> x >= fitness_threshold, df)
            total_rows += nrow(filtered)
            counted_files += 1
        else
            @warn "File $(f) has no :fitness column; skipped."
        end
    end

    avg_rows = counted_files > 0 ? total_rows / counted_files : 0.0
    println("📂 Folder: $dir")
    println("  Files with :fitness column: ", counted_files)
    println("  Total top ranked rows: ", total_rows)
    println("  Average top ranked rows: ", round(avg_rows, digits=2))
    return avg_rows
end

function to_symbol_names!(df::DataFrame)
    rename!(df, Dict(n => Symbol(n) for n in names(df) if n isa AbstractString))
    return df
end

function combine_unique_csvs(dir::AbstractString)
    files = glob("*.csv", dir)
    isempty(files) && @warn "No CSV files found in $dir"
    dfs = [CSV.read(f, DataFrame) for f in files]
    foreach(to_symbol_names!, dfs)
    df = isempty(dfs) ? DataFrame() : reduce(vcat, dfs; cols=:union)
    to_symbol_names!(df)  # ensure symbol names after union
    unique!(df)
    return df
end

function suffix_columns(df::DataFrame, lang::AbstractString; keys=[:i1_1, :i2_1])
    cols = names(df)                    # could be Vector{String} or Vector{Symbol}
    symkeys = Set(Symbol.(keys))        # compare using Symbols
    # Dict key type matches current column name type (String or Symbol)
    mapping = Dict{eltype(cols),Symbol}()
    for c in cols
        if Symbol(c) ∉ symkeys
            mapping[c] = Symbol(string(c), "_", lang)
        end
    end
    return rename(copy(df), mapping)
end

# 2) load & combine each language folder
df_java = combine_unique_csvs("Archive/10%Tracer/Uniform/java_normalize/Mutation/600")
df_py = combine_unique_csvs("Archive/10%Tracer/Uniform/python_normalize/Mutation/600")
df_julia = combine_unique_csvs("Archive/10%Tracer/Uniform/normalize/Mutation/600")

# fitness threshold
fitness_java = get_fitness_threshold(df_java)
fitness_py = get_fitness_threshold(df_py)
fitness_julia = get_fitness_threshold(df_julia)

# # 3) keep rows that have matching (i1_1, i2_1) across ALL THREE
# keys = [:i1_1, :i2_1]

# df_java_s = suffix_columns(df_java, "java"; keys=keys)
# df_py_s = suffix_columns(df_py, "python"; keys=keys)
# df_julia_s = suffix_columns(df_julia, "julia"; keys=keys)

# # 5) inner-join on keys to keep only rows present in all three
# tmp = innerjoin(df_java_s, df_py_s; on=keys, makeunique=true)
# res = innerjoin(tmp, df_julia_s; on=keys, makeunique=true)
# sort!(res, :fitness_julia, rev=true)
#CSV.write("matched_rows_combined.csv", res)

avg_java = average_rows_with_fitness("Archive/10%Tracer/Uniform/java_normalize/Mutation/600", fitness_java)
avg_py = average_rows_with_fitness("Archive/10%Tracer/Uniform/python_normalize/Mutation/600", fitness_py)
avg_julia = average_rows_with_fitness("Archive/10%Tracer/Uniform/normalize/Mutation/600", fitness_julia)