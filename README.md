# Data and source code for figure generation in the QTrack manuscript

This repository contains the data, analysis scripts, and figure-generation code associated with the QTrack manuscript. It is intended to provide a clean, reproducible, and accessible set of materials for regenerating the figures presented in the paper.

The source code for QTrack is available on Github at <https://github.com/LabPresse/SP2T.jl>, and on Zenodo at <10.5281/zenodo.20656382>.

## Where to get the materials

These materials are distributed in two places:

- **Zenodo** (<https://doi.org/10.5281/zenodo.20656382>): the complete archive, including all precomputed simulation and inference results. Download this if you want to regenerate the figures directly from the precomputed results without rerunning simulations or inference.
- **GitHub** (<https://github.com/LabPresse/qtrack-paper-figures>): the code, parameter files, experimental data, and most precomputed simulations. The precomputed inference results (and the precomputed simulation for Fig. S3) are too large for GitHub and are only included in the Zenodo archive. From a GitHub clone you can still regenerate everything from scratch by running the simulation and inference scripts yourself.

## Overview

This repository regenerates **Figs. 2–7** and **Supplementary Figs. S1–S8**. (**Fig. 1** is a conceptual figure; only the complete SVG file is provided.)

The workflow is driven by four shell scripts in the main directory:

| Script | Purpose |
| --- | --- |
| `run_simulations.sh` | Regenerates all synthetic datasets from the parameter (`.toml`) files, writing to the `simulations/` folders (and `Fig_S3/sim_Fig_S3_motion_blur/`). |
| `run_inference_test.sh` | Runs the inference procedures. As provided, each call passes a `test` argument, which runs a shortened chain (1,000 iterations) and writes results to `test_inference_results/` folders. Removing the `test` argument runs the full inference used in the paper and writes to `inference_results/` folders. |
| `generate_figures_precomputed.sh` | Generates the figures from the precomputed results shipped in the Zenodo archive (`precomputed_simulations/`, `precomputed_inference_results/`). This requires no simulation or inference runs. |
| `generate_figures_test.sh` | Generates the figures from your own test-mode results. Requires `run_simulations.sh` and `run_inference_test.sh` to have been run first. |

All generated figures are saved to a `figures/` directory in the repository root.

Most figure scripts accept an optional mode argument:

- `precomputed` — read from the `precomputed_*` folders (Zenodo archive);
- `test` — read from your own `simulations/` and `test_inference_results/` folders;
- no argument — read from your own `simulations/` and full `inference_results/` folders.

To regenerate figures from your own *full* inference runs, remove the `test` arguments from `run_inference_test.sh`, run it, and then call the figure scripts with no mode argument (see `generate_figures_test.sh` for the list of calls).

### Requirements and runtime

A working Julia environment is provided through `Project.toml` and `Manifest.toml`. This environment specifies `CUDA.jl` version `5.9.6`. Although this exact version is not strictly required in every setup, it is the version used and tested for the present repository.

The inference scripts run on the GPU and require a CUDA-capable device. Generating figures from precomputed results runs on the CPU.

Some figures are substantially more computationally demanding than others. In particular, the full inference runs for **Fig. 2** and **Fig. S1** each take roughly 13 hours for their three diffusion-coefficient cases combined, whereas the remaining figures can generally be generated more quickly.

All simulation scripts use fixed random-number seeds (set in the simulation `.toml` files or in the scripts themselves), so rerunning the simulations reproduces the synthetic datasets exactly. The MCMC inference runs are **not** seeded: rerunning inference produces statistically consistent but not bit-identical chains. The precomputed inference results in the Zenodo archive are the exact chains used for the figures in the paper. If you encounter discrepancies beyond this, please feel free to contact us.

Unless otherwise noted, the naming conventions used in this repository are as follows:

- `simulation_with_toml.jl` generates synthetic data from a simulation parameter `.toml` file;
- `inference_with_toml.jl` performs inference as specified by an inference parameter `.toml` file;
- `Fig_x_script.jl` generates the corresponding figure;
- in the self-contained figure folders (Figs. 4–7), `simulation.jl` generates synthetic data, and `inference_cpu.jl` / `inference_gpu.jl` perform inference on the CPU / GPU.

## Source data

In addition to saving the figure PDFs, each figure script writes the numerical values behind its plotted elements (scatter and line series, binned histogram densities, and image pixel matrices) to `source_data/<figure>/` as CSV files, one file per panel element. Rgiunning

```bash
python3 make_source_data.py
```

(requires Python with the `openpyxl` package) assembles these CSVs into `Source_Data.xlsx` — the Source Data file accompanying the manuscript, with one sheet per figure and a README sheet describing the conventions. The figure scripts only write the CSVs; the workbook is produced exclusively by `make_source_data.py`, so rerunning figure scripts never overwrites it.

## Figure guide

### Figure 1

**Figure 1** is a conceptual figure. For this reason, only the complete SVG file is provided here (`Fig_1/fig1.svg`). Code used to generate individual components of the figure can be made available upon reasonable request.

### Figure 2, Figure S1, Figure S2, Figure S7, and Figure S8 (`Fig_2_S1_S2_S7_S8/`)

These figures are grouped together because they rely on related simulations and inference procedures, including inference on the included experimental data (`experimental_data/`).

- **Figure 2** presents the main benchmark results in the manuscript.
- **Figure S1** provides a complementary robustness analysis based on an alternative parameter setting related to Fig. 2.
- **Figure S2** shows the localization error as a function of exposure time for the Fig. 2, Fig. S1, and Fig. S2 parameter settings.
- **Figure S7** shows diffusion-coefficient posteriors across exposure times for the Fig. 2 simulations, providing an additional robustness check.
- **Figure S8** validates the experimental diffusion-coefficient posterior by showing consistency between inference performed with batch size 1 and batch size 2.

The corresponding simulations and inference runs are driven by the `.toml` files in `Fig_2_S1_S2_S7_S8/tomls/` through `run_simulations.sh` and `run_inference_test.sh`. Because inference for these figures can be time-consuming, users may wish to comment out sections corresponding to figures they do not need to regenerate.

### Figure 3 (`Fig_3/`)

**Figure 3** presents inference results on experimental fluorescent-bead data. The experimental frames and camera calibration data are included in the folder. Inference is performed by `Fig_3/inference_for_beads.jl` (called from `run_inference_test.sh`), and the figure is generated by `Fig_3/Fig_3_script.jl`.

### Figures 4 and 5 (`Fig_4/`, `Fig_5/`)

These folders are self-contained: they include the simulation and inference scripts (`simulation.jl`, `inference_cpu.jl`, `inference_gpu.jl`) together with the resulting frames and inference chains, so `Fig_4_script.jl` and `Fig_5_script.jl` can be run directly (from the repository root) without rerunning inference.

### Figures 6 and 7 (`Fig_6/`, `Fig_7/`)

These are computational benchmark figures. The timing values are recorded directly in `Fig_6_script.jl` and `Fig_7_script.jl`, which can be run directly (from the repository root). The scripts used to produce those timings are provided in the corresponding subfolders of `Fig_6/` (`framesize/`, `nframes/`, `nparticles/`, `weaklim/`) and in `Fig_7/`.

### Figure S3 (`Fig_S3/`)

**Figure S3** illustrates how motion blur arises as exposure time increases. It requires only a simulation (no inference), driven by `Fig_S3/sim_params_emccd.toml`. The precomputed simulation (`precomputed_sim_Fig_S3_motion_blur/`) is included only in the Zenodo archive due to its size.

### Figures S4 and S5 (`Fig_S4_S5/`)

- **Figure S4** shows three realizations of the same baseline Brownian trajectory, each paired with a different ON/OFF (photoblinking) state trace. It requires only the simulations.
- **Figure S5** shows the localization error for the non-blinking and blinking trajectories in the corresponding cases. It additionally requires the inference results.

### Figure S6 (`Fig_S6/`)

**Figure S6** shows apparent diffusion coefficients as a function of batch size, computed from trajectories simulated within the script itself. It is fully self-contained and requires no external data.

## Notes

- The shell scripts in the main directory are intended to automate the workflow from simulation and inference to plotting.
- Runtime varies substantially across figures, especially for those involving large-scale inference.
- The included Julia environment is provided to maximize reproducibility.
- As the QTrack API may evolve over time, some scripts in this repository may require minor updates to remain compatible with the latest version. If you encounter such an issue, please feel free to contact us.
