# SETBVE Framework

## System Requirements

To run the SETBVE framework, ensure the following:

- Julia ≥ 1.9.4: [Download Julia](https://julialang.org/downloads/)
- Recommended Editor: [Visual Studio Code](https://code.visualstudio.com/) with the Julia extension
- Required Packages: Install via the provided setup script

### Required Packages Installation Steps

1. Clone or download this repository.
2. Open a terminal in the project directory, (e.i. `framework/SETBVE`).
3. Run the setup script to install all required packages:

   ```bash
   julia setup.jl
   ```

---

## Reproducing Results (For Researchers)

> ⚠️ **Warning: Disk Space Usage**  
> Running all `run*.sh` scripts will generate approximately **20 GB** of data.  
> Please ensure sufficient disk space is available before proceeding.

> ⏱️ **Warning: Execution Time**    
> These scripts run the SETBVE framework on 10 FUTs:  
> - **4 FUTs** (bytecount, bmi, circle, date) with **9 SETBVE configurations** each  
>   → Scripts: `run30sec4SUTs.sh`, `run600sec4SUTs.sh`  
> - **6 FUTs** (cld, fld, fldmod1, max, power_by_squaring, tailjoin) with **2 SETBVE configurations** each  
>   → Scripts: `run30sec6SUTs.sh`, `run600sec6SUTs.sh`  
>
> Each configuration is executed 20 times for either **30 seconds** or **600 seconds** per run.  
>
> Estimated total time:  
> - **30-second runs** (`run30sec4SUTs.sh` + `run30sec6SUTs.sh`): ~8 hours  
> - **600-second runs** (`run600sec4SUTs.sh` + `run600sec6SUTs.sh`): ~160 hours  
>
> Please plan your time accordingly.

### ▶️ Running the Experiment
1. **Navigate to directory** `framework/SETBVE`
2. **Make the script executable** (only needed once):
   ```bash
   chmod +x run30sec4SUTs.sh
   ```

3. **Run the script**:
   ```bash
   ./run30sec4SUTs.sh
   ```

> 💡 Repeat the steps for other scripts: `run30sec6SUTs.sh`, `run600sec4SUTs.sh` and `run600sec6SUTs.sh`.

---
## Using the Framework (For Practitioners)

> ⚠️ **Warning: Disk Space Usage**  
> Each run may generate between **1MB and 100MB** of data, depending on the FUT, run duration, and configuration.  
> With the default **20 runs**, total storage requirements can become significant. Please ensure you have enough disk space before proceeding.

> ⏱️ **Warning: Execution Time**  
> The current version of SETBVE runs sequentially and is not parallelized.  
> A single configuration with a 600-second run will take over 200 minutes to complete all 20 runs. Plan accordingly if you choose long durations.

### Framework Overview

The framework is composed of three main components:

- **Sampler** – generates inputs
- **Explorer** – mutates inputs selected from archive
- **Tracer** – refines found boundaries 

These components can be enabled in various combinations.

### Running the Framework

To execute the framework, 1) open a terminal in the project directory (e.i. `framework/SETBVE`) and 2) use the following command structure:

```bash
julia main.jl [fut_name] [duration_in_sec] [emitter_type] [parent_selection] [tracer_budget] [seed]
```

### Parameters

| Parameter            | Description                                                                                       | Options                                                                                     |
|----------------------|---------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------|
| `fut_name`           | Function Under Test                                                                               | `circle`, `bytecount`, `bmi`, `date`, `cld`, `fld`, `fldmod1`, `max`, `power_by_squaring`, `tailjoin` |
| `duration_in_sec`    | Duration of the run (in seconds)                                                                  | `30` `600`                                                                                 |
| `emitter_type`       | Method for generating inputs                                                                      | `Random`, `Bituniform`, `Mutation`                                                         |
| `parent_selection`   | Strategy for selecting parents for mutation                                                       | `Uniform`, `Fitness`, `Curiosity`, `NoSelection`                                           |
| `tracer_budget`      | Proportion of total time budget used for the Tracer                               | `0`, `0.1`                                                                                  |
| `seed` (optional)    | Seeds the random number generator; run *k* uses `seed + k - 1`. Without it, runs are unseeded as before | any integer, e.g. `42`                                                                      |

> **Note:** All parameter values are **case sensitive**. Use them exactly as shown.

> **Note:** Runs are limited by time, not by a number of evaluations, so a seeded run repeats exactly only if it completes the same number of evaluations in that time. The seed fixes the sequence of random choices, not how many of them fit into the budget.

### Examples

```bash
julia main.jl bmi 30 Mutation Uniform 0.1
julia main.jl bytecount 30 Bituniform NoSelection 0
```

### Component Combinations

| Emitter Type         | Parent Selection            | Tracer Budget | SETBVE Components Used            |
|----------------------|-----------------------------|---------------|----------------------------------|
| `Bituniform`, `Random` | `NoSelection`                | `0`           | Sampler                     |
| `Bituniform`, `Random` | `NoSelection`                | `0.1`         | Sampler + Tracer                 |
| `Mutation`             | `Uniform`, `Fitness`, `Curiosity` | `0`           | Sampler + Explorer               |
| `Mutation`             | `Uniform`, `Fitness`, `Curiosity` | `0.1`         | Sampler + Explorer + Tracer      |


### Configuration

By default, the framework runs each configuration **20 times**.  
To modify this, open the `runparameters.jl` file and change the value of the `number_of_runs` variable:

```julia
number_of_runs = 20  # Change to your desired number
```

### Optional Dependencies

`Plots` (for the figures) and `PyCall` (for the `python_normalize` FUT) are loaded by default. To run SETBVE without them, for example when they aren't installed, set these environment variables before starting Julia:

```bash
SETBVE_PLOTS=false SETBVE_PYTHON=false julia main.jl bmi 30 Mutation Uniform 0.1
```

Without `Plots`, `main.jl` skips the figures; without `PyCall`, the `python_normalize` FUT is unavailable.

### Using SETBVE from Julia Code

Your own FUTs and behavioural descriptors can be registered and searched without editing SETBVE's files:

```julia
include("SETBVE.jl")
using .SETBVE

# a descriptor gets a pair's inputs and outputs, (i1, i2, output1, output2), and returns an integer bin
register_descriptor!("sum_bin", (i1, i2, o1, o2) -> ndigits(sum(BigInt, i1)))

# a FUT gets a vector of integer inputs; an error it throws counts as an invalid output
register_sut!("my_fut", x -> x[1] < x[2] ? "less" : "not less", 2;
              descriptors=["validity_group", "oan", "sum_bin"])

result = run_search("my_fut", 30; emitter="Mutation", selection="Curiosity", tracer_budget=0.1, seed=1)
result.archive       # DataFrame: the Sampler's and Explorer's solutions
result.with_tracer   # DataFrame: the same plus the Tracer's (nothing when tracer_budget is 0)
```

`run_search` performs one run as `main.jl` does, and writes the same CSV files.

---

## Output Files

After running the framework, the following directories and files will be generated automatically in the project folder:

- **Archive/** – stores the results of each run in CSV format. Each file includes generated inputs, outputs and relevant metadata.
- **Plots/** – created only for the `bmi` and `circle` FUTs. This folder contains visualizations of a subset of the boundary candidates discovered during the run.

When SETBVE is used from other Julia code, `set_output_dir!(dir)` writes these folders under `dir` instead of the working directory, and `set_verbose!(false)` turns off its progress bars and messages.