#!/usr/bin/env bash
set -euo pipefail

echo "Making Fig 4..."
julia --project=. ./Fig_4/Fig_4_script.jl

echo "Making Fig 5..."
julia --project=. ./Fig_5/Fig_5_script.jl

echo "Making Fig 6..."
julia --project=. ./Fig_6/Fig_6_script.jl

echo "Making Fig 7..."
julia --project=. ./Fig_7/Fig_7_script.jl
