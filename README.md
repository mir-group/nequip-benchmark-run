# NequIP Foundation Model and LAMMPS MLIAP 

## build_lammps
Folder containing information on how to setup a micromamba environment with ```nequip``` dependencies and compile LAMMPS with the mliap pairstyle and kokkos. 
- env_setup.md: micromamba environment with ```nequip``` dependencies
- build.sh: script to build LAMMPS with mliap pair style and kokkos

## models
Example script to download and compile a ```nequip``` foundation model for LAMMPS mliap pair style

## run_lmp/1gpu
Example LAMMPS input and submission scripts for running a ```nequip``` foundation model with the mliap pair style on 1 gpu.