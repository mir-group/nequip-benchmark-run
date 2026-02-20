## Nequip MLIAP Benchmarking Perlmutter

#### DONE INTERACTIVELY ON CPU ####
# Micromamba
micromamba create -p ./env
micromamba activate ./env

# Python 
micromamba install python==3.11 

# Torch
pip install torch==2.9.0 --index-url https://download.pytorch.org/whl/cu129

# Wandb
pip install wandb

# cython
pip install cython==3.0.11 cupy-cuda12x

# Public Nequip
git clone https://github.com/mir-group/nequip.git
cd nequip
pip install -e .

# LAMMPS: Release 10 December 2025
git clone https://github.com/lammps/lammps.git

git clone --depth=1 https://github.com/mir-group/pair_nequip_allegro
cd pair_nequip_allegro/
./patch_lammps.sh ../lammps/

cd ..
cd lammps

# see build.sh for script on building LAMMPS
