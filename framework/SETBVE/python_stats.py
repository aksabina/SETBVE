import os 
import pandas as pd

def check_validity_groups_distribution(root_dir):
    all_counts = []
    all_percentages = []

    for subdir, _, files in os.walk(root_dir):
        for file in files:
            
            if file.endswith(".csv"):
                path = os.path.join(subdir, file)
                try:
                    df = pd.read_csv(path, low_memory=False)

                    # Skip if no rows left
                    if df.empty:
                        continue

                    # Count occurrences
                    counts = df['bd_validity_group'].value_counts()
                    percentages = df['bd_validity_group'].value_counts(normalize=True) * 100

                    all_counts.append(counts)
                    all_percentages.append(percentages)

                except Exception as e:
                    print(f"Error processing {path}: {e}")

    # Combine all results
    if not all_counts:
        print("No valid CSV files found.")
        return None, None

    # Align all indexes (fill missing values with 0)
    counts_df = pd.concat(all_counts, axis=1).fillna(0)
    percentages_df = pd.concat(all_percentages, axis=1).fillna(0)

    # Compute average occurrences and percentages
    avg_counts = counts_df.mean(axis=1).sort_index()
    avg_percentages = percentages_df.median(axis=1).sort_index()

    print("Average occurrences across all files:")
    print(avg_counts)
    print("\nAverage percentages across all files:")
    print(avg_percentages)

    return avg_counts, avg_percentages



# Example usage
if __name__ == "__main__":
    root_directory = "MainSUTs/0%Tracer"
    avg_counts, avg_percentages = analyze_csvs(root_directory)
