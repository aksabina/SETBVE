# SETBVE Evaluation

This document provides instructions for setting up and running the evaluation of the SETBVE experiments.

---

## System Requirements

To run the evaluation scripts, ensure the following prerequisites are met:

- **Julia ≥ 1.9.4**  
  Download from [julialang.org](https://julialang.org/downloads/)

- **Recommended Editor**  
  [Visual Studio Code](https://code.visualstudio.com/) with the [Julia extension](https://marketplace.visualstudio.com/items?itemName=julialang.language-julia)

---

## Setup Instructions

### 1. Clone the Repository

```bash
git clone https://github.com/aksabina/SETBVE.git
cd SETBVE/evaluation/EvaluationSETBVE
```

### 2. Install Required Packages

Run the provided setup script to activate the environment and install dependencies:

```bash
julia setup.jl
```
---

## Required Folder: `Archive`

The evaluation scripts depend on a folder named `Archive`, which must be located in the root of the evaluation directory:

```
evaluation/EvaluationSETBVE/Archive/
```

This folder contains results from all SETBVE configurations per SUT. Without it, evaluation cannot proceed.

### How to Obtain the Archive Folder

1. Go to [SETBVE dataset](https://doi.org/10.5281/zenodo.15364606).
2. Download the file `Archive.zip` (9 GB compressed, 20 GB uncompressed).
3. Extract `Archive.zip` and move the resulting `Archive` folder into the `evaluation/EvaluationSETBVE/` directory.

Your directory structure should look like:

```
evaluation/
└── EvaluationSETBVE/
    ├── main.jl
    ├── setup.jl
    └── Archive/
        ├── 0%Tracer/
        ├── 10%Tracer/
```

## ▶️ Running the Evaluation

From the `evaluation/EvaluationSETBVE/` directory, run the evaluation using:

```bash
julia main.jl [sut_name]
```

Where `[sut_name]` is one of the following options **(case-sensitive)**:

```
bmi, bytecount, circle, date, cld, fld, fldmod1, max, power_by_squaring, tailjoin
```

Example:

```bash
julia main.jl bmi
```
---

## Output Files

After running the evaluation, the following directories and files will be generated automatically in the project folder:

- **AggregatedArchive/** – This folder contains processed Archive files.
- **Plots/** – This folder contains visualizations of pairwise comparisons between methods of discovered archive cells per SUT.
- **Stats/** – This folder contains the results of evaluations RAC and RPD.
