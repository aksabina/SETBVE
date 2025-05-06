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


## Usage

The framework is composed of three main components:

- **Sampler** – generates inputs
- **Explorer** – mutates inputs selected from archive
- **Tracer** – refines found boundaries 

These components can be enabled in various combinations.

### Running the Framework

To execute the framework, use the following command structure:

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
