#!/bin/bash
set -e
SUTS=("bmi" "bytecount" "circle" "date")
TIMELIMIT=600

for SUT in "${SUTS[@]}"; do
  julia main.jl $SUT $TIMELIMIT Mutation Curiosity 0
  julia main.jl $SUT $TIMELIMIT Mutation Curiosity 0.1
  julia main.jl $SUT $TIMELIMIT Mutation Fitness 0
  julia main.jl $SUT $TIMELIMIT Mutation Fitness 0.1
  julia main.jl $SUT $TIMELIMIT Mutation Uniform 0
  julia main.jl $SUT $TIMELIMIT Mutation Uniform 0.1
  julia main.jl $SUT $TIMELIMIT Bituniform NoSelection 0
  julia main.jl $SUT $TIMELIMIT Bituniform NoSelection 0.1
  julia main.jl $SUT $TIMELIMIT Random NoSelection 0
done