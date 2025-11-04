
# Prints one final line:
# MEAN_ALL,<num_runs_used>,<mean(avg_coverage)>,<mean(sign_cov_mean)>,<mean(parity_cov_mean)>,<mean(bitlen_cov_mean)>
#
# Assumptions:
#  - Each CSV has input columns named like i1_1, i1_2, i2_1, i2_2 ... (pattern ^i\d+(_\d+)?$).
#  - Values are integers or parseable to integers.
#  - One file per run.

using CSV
using DataFrames

# --- Helpers ---
to_int(v) = v === missing ? 0 :
            v isa Integer ? Int(v) :
            v isa AbstractFloat ? Int(trunc(v)) :
            (
    try
        parse(Int, String(v))
    catch
        try
            Int(trunc(parse(Float64, String(v))))
        catch
            0
        end
    end
)

to_bigint(v)::BigInt = v === missing ? big(0) :
                       v isa Bool ? (v ? big(1) : big(0)) :
                       v isa Integer ? BigInt(v) :
                       v isa AbstractFloat ? BigInt(trunc(v)) :
                       let s = String(v) |> strip
    ls = lowercase(s)
    if ls == "true"
        return big(1)
    elseif ls == "false"
        return big(0)
    end
    try
        return parse(BigInt, s)
    catch
        try
            return BigInt(trunc(parse(Float64, s)))
        catch
            return big(0)
        end
    end
end

bitlen(x::Integer) = x == 0 ? 0 : ndigits(abs(x), base=2)

function range_mag_bin_row(vals::AbstractVector{<:Integer})
    isempty(vals) && return nothing
    r = maximum(vals) - minimum(vals)
    return bitlen(r)  # Int bucket
end

function find_input_cols(df::DataFrame)
    cols = [c for c in names(df) if occursin(r"^i\d+(_\d+)?$", String(c))]
    if !isempty(cols)
        return cols
    end
    # Fallback: any 'i*' column that looks numeric
    out = Symbol[]
    for c in names(df)
        if startswith(String(c), "i")
            col = df[!, c]
            ok = true
            @inbounds for val in col
                to_bigint(val) 
            end
            ok && push!(out, c)
        end
    end
    return out
end

function collect_global_bitlens(df_all::DataFrame)
    global_bl = Set{Int}()
    
    inputs = find_input_cols(df_all)
    for c in inputs
        for v in df_all[!, c]
            push!(global_bl, bitlen(to_bigint(v)))
        end
    end
    return global_bl
end

function collect_global_range_mag_bins_per_row(df_all::DataFrame)::Set{Int}
    global_rm = Set{Int}()
    
    inputs = find_input_cols(df_all)
    
    for r in 1:nrow(df_all)
        vals = BigInt[]
        for c in inputs
            push!(vals, to_bigint(df_all[r, c]))
        end
        b = range_mag_bin_row(vals)
        b === nothing || push!(global_rm, b)
    end
    
    return global_rm
end

# --- Coverage for one run using per-row rm_seen ---
function range_mag_coverage_per_run(df::DataFrame, global_rm::Set{Int})
    inputs = find_input_cols(df)
    #isempty(inputs) && return (false, 0.0)

    rm_seen = Set{Int}()
    @inbounds for r in 1:nrow(df)
        rowvals = BigInt[]
        for c in inputs
            push!(rowvals, to_bigint(df[r, c]))
        end
        b = range_mag_bin_row(rowvals)
        b === nothing || push!(rm_seen, b)
    end

    denom = max(length(global_rm), 1)
    cov = length(intersect(rm_seen, global_rm)) / denom
    return cov
end


function coverage_for_run(df::DataFrame, global_bl::Set{Int}, global_rm::Set{Int})

    inputs = find_input_cols(df)
    isempty(inputs) && return (false, 0.0, 0.0, 0.0, 0.0)

    # === NEW: combine ALL inputs across all input columns ===
    vals = Integer[]
    for c in inputs
        append!(vals, map(to_bigint, df[!, c]))
    end

    # --- Sign coverage over {neg,pos}; zeros ignored here.
    sign_seen = Set{Symbol}()
    for v in vals
        if v < 0
            push!(sign_seen, :neg)
        elseif v > 0
            push!(sign_seen, :pos)
        else
            push!(sign_seen, :zero)
        end
    end
    sign_cov = length(sign_seen) / 3 

    # --- Parity coverage over {even,odd} (0 is even)
    parity_seen = Set{Symbol}()
    for v in vals
        push!(parity_seen, iseven(v) ? :even : :odd)
    end
    parity_cov = length(parity_seen) / 2

    # --- Bit-length coverage using global denominator
    bl_seen = Set{Int}()
    for v in vals
        push!(bl_seen, bitlen(v))
    end
    denom_bl = max(length(global_bl), 1)
    bitlen_cov = length(intersect(bl_seen, global_bl)) / denom_bl

    # --- Bit-length range coverage using global denominator
    rm_coverage = range_mag_coverage_per_run(df, global_rm)

    # Run-level average coverage (mean of the three features)
    avg_coverage = (sign_cov + parity_cov + bitlen_cov) / 3

    return (true, avg_coverage, sign_cov, parity_cov, bitlen_cov)
end

