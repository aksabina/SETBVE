# SETBVE Framework

## System Requirements

To run the SETBVE framework, ensure the following:

- Julia ≥ 1.9.4: [Download Julia](https://julialang.org/downloads/)
- Recommended Editor: [Visual Studio Code](https://code.visualstudio.com/) with the Julia extension
- Required Packages: Install via the provided setup script

### Required Packages Installation Steps

1. Clone or download this repository.
2. Open a terminal in the project directory, e.g., `framework/SETBVE`.
3. Run the setup script to install all required packages:

   ```bash
   julia setup.jl
   ```

---

## Reproducing Results (For Researchers)

> ⚠️ **Warning: Disk Space Usage**  
> Running all `run*.sh` scripts will generate approximately **50 GB** of data.  
> Please ensure sufficient disk space is available before proceeding.

> ⏱️ **Warning: Execution Time**    
> These scripts run the SETBVE framework on 10 SUTs:  
> - **4 SUTs** (bytecount, bmi, circle, date) with **9 SETBVE configurations** each  
>   → Scripts: `run30sec4SUTs.sh`, `run600sec4SUTs.sh`  
> - **6 SUTs** (cld, fld, fldmod1, max, power_by_squaring, tailjoin) with **2 SETBVE configurations** each  
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

1. **Make the script executable** (only needed once):
   ```bash
   chmod +x run30sec4SUTs.sh
   ```

2. **Run the script**:
   ```bash
   ./run30sec4SUTs.sh
   ```

> 💡 Repeat the steps for other scripts: `run30sec6SUTs.sh`, `run600sec4SUTs.sh` and `run600sec6SUTs.sh`.

---
## Using the Framework (For Practitioners)

> ⚠️ **Warning: Disk Space Usage**  
> Each run may generate between **1MB and 100MB** of data, depending on the SUT, run duration, and configuration.  
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

To execute the framework, 1) open a terminal in the project directory e.g., `framework/SETBVE` and 2) use the following command structure:

```bash
julia main.jl [sut_name] [duration_in_sec] [emitter_type] [parent_selection] [tracer_budget]
```

### Parameters

| Parameter            | Description                                                                                       | Options                                                                                     |
|----------------------|---------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------|
| `sut_name`           | System Under Test                                                                                 | `circle`, `bytecount`, `bmi`, `date`, `cld`, `fld`, `fldmod1`, `max`, `power_by_squaring`, `tailjoin` |
| `duration_in_sec`    | Duration of the run (in seconds)                                                                  | `30` `600`                                                                                 |
| `emitter_type`       | Method for generating inputs                                                                      | `Random`, `Bituniform`, `Mutation`                                                         |
| `parent_selection`   | Strategy for selecting parents for mutation                                                       | `Uniform`, `Fitness`, `Curiosity`, `NoSelection`                                           |
| `tracer_budget`      | Proportion of total time budget used for the Tracer                               | `0`, `0.1`                                                                                  |

> **Note:** All parameter values are **case sensitive**. Use them exactly as shown.

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
---

## Output Files

After running the framework, the following directories and files will be generated automatically in the project folder:

- **Archive/** – stores the results of each run in CSV format. Each file includes generated inputs, outputs and relevant metadata.
- **Plots/** – created only for the `bmi` and `circle` SUTs. This folder contains visualizations of a subset of the boundary candidates discovered during the run.