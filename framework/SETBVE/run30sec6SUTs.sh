#!/bin/bash
set -e
SUTS=("cld" "fld" "fldmod1" "max" "power_by_squaring" "tailjoin")
TIMELIMIT=30

# Run the tests for each SUT with different configurations
for SUT in "${SUTS[@]}"; do
  julia main.jl $SUT $TIMELIMIT Mutation Uniform 0
  julia main.jl $SUT $TIMELIMIT Mutation Uniform 0.1
done