# Data Folder

This directory contains data from experimental runs of the SETBVE framework. It is structured into two main subfolders:

- `example_archive/`: Sample results from archive-based exploration.
- `per_run_stats/`: Precomputed statistics for each experimental run.

## example_archive/

This folder is organized to reflect different configurations of the SETBVE framework.

### Tracer Settings

- `0%Tracer/` and `10%Tracer/`: Represent different tracing budget splits (0% of the budget, 10% of the budget) used in our experiments.

### Parent Selection Strategies

Each tracer folder contains the following subfolders representing the parent selection strategies used:

- `Curiosity/`: Proportionate selection based on curiosity score.
- `Fitness/`: Proportionate selection based on the derivative of the program (fitness score).
- `Uniform/`: Uniform random selection from the archive.
- `NoSelection/`: No selection from the archive; only the `Sampler` component is active (no `Explorer`).

### SUTs (Software Under Test)

Inside each strategy folder, you’ll find subfolders for individual SUTs:

- Common SUTs across strategies: `BMI`, `Bytecount`, `JuliaDate`, `SolidCircle`
- Additional SUTs (only in `Uniform/`): `cld`, `fld`, `fldmod1`, `max`, `power_by_squaring`, `tailjoin` (Julia Base functions)

### Run Duration

Each SUT folder contains two subfolders:

- `30 seconds/`: Results from 30-second runs
- `600 seconds/`: Results from 600-second runs

## per_run_stats/

This folder contains summary statistics for each experimental run, grouped by configuration, SUT, and runtime.

