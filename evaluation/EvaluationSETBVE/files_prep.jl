using DataFrames, CSV, Glob, Dates

function process_folder(root::String)
    files = String[]
    for (dirpath, _, filenames) in walkdir(root)
        for file in filenames
            endswith(file, ".csv") && push!(files, joinpath(dirpath, file))
        end
    end
    n = length(files)
    start_time = time()
    println("Processing $n files...")
    
    for (i, file) in enumerate(files)
        # Read and clean DataFrame
        df = CSV.read(file, DataFrame)
        for col in [:elapsed_millis, :cumulative_fitness, :curiosity, :fitness_strlength]
            if hasproperty(df, col)
                select!(df, Not(col))
            end
        end
        if hasproperty(df, :fitness)
            df = filter(:fitness => x -> x != 0, df)
        end

        # Rename file if needed
        newfile = occursin("LocalSearch", file) ? replace(file, "LocalSearch" => "Tracer") : file
        
        # Save cleaned DataFrame
        CSV.write(newfile, df)

        # ETA
        elapsed = time() - start_time
        remaining = (elapsed / i) * (n - i)
        println("Processed $i/$n. ETA: $(round(remaining, digits=1)) seconds.")
    end
end

function delete_localsearch_files(root::String)
    for (dirpath, _, filenames) in walkdir(root)
        for file in filenames
            if !occursin("_1.csv", file)
                rm(joinpath(dirpath, file))
            end
        end
    end
end


#process_folder("SETBVE_Experiments/archive_raw_data")  # Adjust the path as needed

delete_localsearch_files("SETBVE_Experiments/archive_raw_data")  # Adjust the path as needed