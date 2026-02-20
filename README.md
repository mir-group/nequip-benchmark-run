# NequIP Foundation Model and LAMMPS ML-IAP

This repository contains scripts and examples for building LAMMPS with the ML-IAP and NequIP pair styles, preparing NequIP foundation models for LAMMPS, and running MD benchmarks.

---

## build_lammps/

Setup and build scripts for a micromamba environment with NequIP dependencies and for compiling LAMMPS with the ML-IAP pair style and Kokkos (CUDA, Ampere80).

| File | Description |
|------|-------------|
| **env_setup.sh** | Instructions (meant to be run interactively on CPU) for creating a micromamba env, installing Python 3.11, PyTorch (CUDA 12.9), NequIP, and LAMMPS, and applying the `pair_nequip_allegro` patch. |
| **build.sh** | SLURM build script that loads modules, activates the micromamba env, and runs CMake. Builds the `lmp` executable in `build/` |

---

## models/

Scripts to download the NequIP-L foundation model and compile it for use with LAMMPS. It needs to be run on the same hardware + environment as the final runs.

| Script | Purpose |
|--------|---------|
| **compile_for_baseline.sh** | Downloads the model and produces two variants under `compiled_models/`: (1) `nequip-prepare-lmp-mliap --no-compile` for the ML-IAP integration, and (2) `nequip-compile --mode torchscript` for the `pair_style nequip` TorchScript backend. |
| **compile_for_test.sh** | Same but for test purposes (without requesting the A100 80GB). |

Ensure the micromamba env path (e.g. `../build_lammps/env`) and SLURM account/partition match your system before submitting.

---

## runs/

Example LAMMPS input files and SLURM submission scripts for running NequIP models with Kokkos GPU.

| Path | Description |
|------|-------------|
| **baseline_measurement/** | Baseline performance runs for the $Li_6 P S_5 Cl$ system (6x6x6 supercell with 11232 atoms). **torchscript/** uses `pair_style nequip` and the TorchScript `.pth` from `compile_for_baseline.sh`; **mliap-nocompile/** uses `pair_style mliap unified` with the `.nequip.lmp.pt` potential.|
| **test/** | Example 1-GPU run for Si |

Update paths in the run scripts (`lammps` executable, micromamba env, and model paths in each `lammps.in`) to match your `build_lammps` and `models` locations.
