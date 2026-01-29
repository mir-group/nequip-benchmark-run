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

# Public Allegro
git clone https://github.com/mir-group/allegro.git
cd allegro 
pip install -e .

# LAMMPS: Release 10 December 2025
git clone https://github.com/lammps/lammps.git
cd lammps

# see build.sh for script on building LAMMPS
