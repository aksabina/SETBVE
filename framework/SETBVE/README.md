# SETBVE as a Julia package

SETBVE can be used from your own Julia code: register a function under test (SUT), choose how its pairs are scored and described, and run searches. This page lists what changed on the `framework-improvements` branch and how to use it. For reproducing the paper's results with `main.jl`, see [`../README.md`](../README.md).

## What's new

None of these changes alter a search that doesn't use them. Each was checked against seeded searches of the earlier version, whose archives stay byte-identical.

**Using SETBVE as a library**

| Change | What it gives you |
|---|---|
| **An installable package** | `using SETBVE` in any Julia environment. The module's files are in `src/`. |
| **`run_search`** | One full search (Sampler, Explorer, Tracer) as a function call that returns the archive. `main.jl` calls it for each run. |
| **`register_sut!`** | Your own SUTs, without editing `suts.jl`. |
| **`register_descriptor!`** | Your own behavioural descriptors. |
| **Input bounds** | Searches stay within each input's range instead of the whole integer range. |
| **A budget in evaluations** | A search stops after exactly *n* pairs, so a seeded search repeats exactly. |
| **Your own distances** | Your own output and input distances for the program derivative, and outputs that are numbers. |
| **Pairs that vary only some inputs** | Each pair differs only in the inputs you choose, as a causal pair test needs. |
| **A log of the search** | Every pair the search evaluated, in order, not only the archive. |
| **`set_output_dir!`, `set_verbose!`** | Choose where archives are written, and turn off progress bars and messages. |
| **Optional Plots and PyCall** | Loaded only if your code loads them (package extensions). |

**Fixes**

- **The Tracer's crashes:** it no longer fails on extreme candidates, from an `Int128` overflow or a search range wider than `typemax(Int128)`.
- **One descriptor signature:** every descriptor is called the same way, `f(i1, i2, output1, output2)`.
- **Archive inputs as `BigInt`:** the archive's input columns are returned as `BigInt`, so DataFrames can sort and deduplicate them. The CSV files are unchanged.
- **A seed for `main.jl`:** an optional sixth argument.

## Installing

From a clone of this repository:

```julia
using Pkg
Pkg.develop(path="path/to/SETBVE_replication_package/framework/SETBVE")
```

Or straight from GitHub:

```julia
using Pkg
Pkg.add(url="https://github.com/aksabina/SETBVE", subdir="framework/SETBVE", rev="framework-improvements")
```

SETBVE needs Julia 1.9 or later.

## Quick start

```julia
using SETBVE

# a SUT gets a vector of integer inputs and returns its output; an error it throws counts as an invalid output
verdict(x) = x[1] < 8 ? "violated" : (x[1] * x[2] > 900 ? "holds" : "uncertain")

# a descriptor gets a pair's inputs and outputs and returns an integer bin; the archive keeps the best pair per bin
register_descriptor!("width_bin", (i1, i2, o1, o2) -> Int(i1[1] ÷ 10))

register_sut!("verdict", verdict, 2;
              descriptors=["validity_group", "oan", "width_bin"],
              bounds=([1, 1], [89, 159]))           # input 1 in 1:89, input 2 in 1:159

result = run_search("verdict"; max_evaluations=1000, seed=1, log_evaluations=true)
result.archive        # DataFrame: the best pair per archive cell
result.evaluations    # DataFrame: every pair evaluated, in order
```

## Registering a SUT

```julia
register_sut!(name, f, n_inputs; descriptors, bounds, numeric_outputs, output_distance, input_distance)
```

| Argument | Meaning | Default |
|---|---|---|
| `f(inputs)` | The SUT. Gets a vector of `n_inputs` integers and returns its output. An error it throws is an invalid output, as in SETBVE's own SUTs. | required |
| `descriptors` | The behavioural descriptors that spread the archive: built-in names or your own (see below). | `["validity_group", "oan", "in_length_var", "in_length_total"]` |
| `bounds` | `(lower, upper)`, one value per input. The Sampler, the Explorer's mutations and the Tracer then stay within them. | none: the whole integer range |
| `numeric_outputs` | `true` if `f` returns numbers. The outputs' distance is then their absolute difference, not a string distance. | `false` |
| `output_distance(o1, o2)` | Your own distance between two outputs. | SETBVE's string distance (or the absolute difference) |
| `input_distance(i1, i2)` | Your own distance between a pair's two input vectors. | Euclidean |

SETBVE searches integers. For a real-valued input, search an integer *k* and let `f` use `k × step`.

A pair's score, its **program derivative**, is its output distance divided by its input distance. A pair with an error output is always scored by SETBVE's own program derivative.

## Behavioural descriptors

A descriptor puts each pair into a bin. The archive keeps the best pair for each combination of bins, so the descriptors decide what the archive keeps apart.

| Built-in | What it measures |
|---|---|
| `validity_group` | How many of the pair's two outputs are errors: 0, 1 or 2 |
| `oan` | Which combination of output classes the pair has |
| `out_length_diff` | The difference in length between the two outputs, as text |
| `in_length_total`, `in_length_var` | The total length of the inputs, in digits, and its variance |
| `in_array_length_total`, `in_array_length_var` | The same, for SUTs whose inputs are arrays |

Add your own with `register_descriptor!(name, f)`, before registering a SUT that uses it. `f(i1, i2, output1, output2)` gets the pair's two input vectors and two outputs, and returns an integer. It is used both when the Sampler and Explorer evaluate pairs and when the Tracer's pairs are added to the archive.

A descriptor that describes *where* a pair is often spreads the archive better than the default ones on a bounded domain: for example, the bin of each input's midpoint.

## Running a search

```julia
run_search(sut_name, duration=0; max_evaluations, emitter, selection, tracer_budget, vary, categorical,
           log_evaluations, seed, run_num)
```

| Argument | Meaning | Default |
|---|---|---|
| `duration` or `max_evaluations` | The budget: seconds, or a number of evaluations. Give exactly one. One evaluation is one pair, so 2 runs of the SUT. | required |
| `emitter` | `"Mutation"` (Sampler, then Explorer), `"Bituniform"` or `"Random"` (random pairs only) | `"Mutation"` |
| `selection` | Which archive pairs `"Mutation"` mutates: `"Uniform"`, `"Fitness"` or `"Curiosity"`. Use `"NoSelection"` with the other emitters. | `"Curiosity"` |
| `tracer_budget` | The share of the time given to the Tracer's local search (0: off). Its budget is in seconds, so it must be 0 with `max_evaluations`. | `0.0` |
| `vary`, `categorical` | Pairs that vary only some inputs (below) | none |
| `log_evaluations` | Also return every pair evaluated, in order | `false` |
| `seed` | Seeds Julia's random number generator first | none |
| `run_num` | Numbers the output files | `1` |

It returns a named tuple:

| Field | What it holds |
|---|---|
| `archive` | The best pair per archive cell, from the Sampler and the Explorer |
| `with_tracer` | The same plus the Tracer's pairs (`nothing` without the Tracer) |
| `evaluations` | With `log_evaluations=true`: every pair evaluated, in order (`nothing` otherwise) |

Each pair is a row with its descriptor bins (`bd_<name>`), its inputs (`i1_k`, `i2_k`), outputs, fitness and, in the archive, its curiosity score. `evaluations` adds the evaluation's number, its phase (`"sampler"` or `"explorer"`), and what it did to the archive (`"new cell"`, `"better"` or `"no update"`). The Tracer's own trials aren't logged.

**Budgets and repeatability.** The Sampler gets 10% of the budget (`bituniform_init_budget_ratio`), the Explorer the rest. With a duration, the number of evaluations depends on the machine's speed. With `max_evaluations` and a `seed`, a search repeats exactly. The `oan` descriptor numbers output classes in the order a Julia session first meets them, so run repeatable searches in a fresh session.

## Pairs that vary only some inputs

```julia
run_search("verdict"; max_evaluations=1000, vary=[1])     # pairs differ only in input 1
```

With `vary`, a pair's two inputs are equal in every input not listed, in the Sampler's, the Explorer's and the Tracer's pairs alike. A pair then shows what changing those inputs alone does, and its program derivative is their local effect. This is the shape of a pair test of a causal claim.

- **Bounds are required**, so pairs can be drawn within the domain.
- **The Sampler, and the `"Bituniform"` and `"Random"` emitters,** draw such pairs uniformly within the bounds.
- **The `"Mutation"` emitter** either moves the whole pair along an input it holds equal (by up to a quarter of that input's range), or shrinks and moves it along a varied input, as SETBVE's own mutation does.
- **A varied input that ends up equal in both** is moved one step apart, since the pair would test nothing.
- **`categorical`** lists inputs whose values have no order, such as codes for categories. The mutation moves them to any value rather than to a nearby one.

## Output files and messages

`run_search` writes the archive as CSV under `Archive/`, as `main.jl` does. Files of a search with `max_evaluations` are named by that budget, e.g. `…500evals_1.csv`.

```julia
set_output_dir!("results/setbve")   # write Archive/ and Plots/ here instead of the working directory
set_verbose!(false)                 # no progress bars or messages
```

## Plots and the Python SUT

Plots and PyCall are optional package extensions:
- **Plots:** `using Plots` loads SETBVE's plotting, including `plot_zoomed_scatter`.
- **PyCall:** `using PyCall` registers the `python_normalize` SUT.

Without them, SETBVE loads in about a second, and neither needs to be installed.

## Running the paper's experiments

`main.jl` and the `run*.sh` scripts work as before. `julia setup.jl` installs their environment, `env/`: SETBVE from this folder, with Plots and PyCall. Two options are new:
- **A seed:** `julia main.jl bmi 30 Mutation Uniform 0.1 42`. Run *k* is seeded with `42 + k − 1`. Runs are budgeted in seconds, so they repeat exactly only if they complete the same number of evaluations.
- **Leaving out the optional parts:** `SETBVE_PLOTS=false` skips the figures, and `SETBVE_PYTHON=false` doesn't load PyCall.

Code that included SETBVE's source (`include("SETBVE.jl"); using .SETBVE`) still works: `SETBVE.jl` in this folder includes `src/`. Plots and the Python SUT need the package (`using SETBVE`).

## Using SETBVE from Python

SETBVE runs in a Python process through [juliacall](https://github.com/JuliaPy/PythonCall.jl): add SETBVE to the Julia environment juliacall uses, then call `register_sut!` and `run_search` with Python functions as the SUT and descriptors. [CausalBVE](https://github.com/neilwalkinshaw/CausalBVE) does this. A Python package that wraps it isn't part of SETBVE yet.

## Known issues

- **`tailjoin` results depend on the Julia session.** Its outputs are error messages that include Julia's internal "world age", which changes when any code is loaded, so the search goes differently.
- **The `element_at_position` SUT with the `"Mutation"` emitter crashes,** because the mutation does arithmetic between arrays of different lengths.
