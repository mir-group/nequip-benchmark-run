#!/bin/bash
#SBATCH -J lmp_compile
#SBATCH -p gpu
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=16
#SBATCH --gres=gpu:1
#SBATCH -t 00:10:00
#SBATCH --mem=75GB
#SBATCH -o logs/%j.err
#SBATCH -e logs/%j.out
#SBATCH --account m5156
#SBATCH --constraint gpu

source ~/.bashrc

# Laod modules
module load cmake/3.30.2
module load cudatoolkit/12.9
module load craype-accel-nvidia80
module load cudnn/9.5.0
module list

# Activate micromamba env
micromamba activate mliap_benchmark_2025

# Get model zip 
wget https://zenodo.org/api/records/16980200/files/NequIP-OAM-L-0.1.nequip.zip/content \
     -O NequIP-OAM-L-0.1.nequip.zip

# Job working directory (where sbatch was run from)
WORK_DIR=$(pwd)
# Compile model
nequip-prepare-lmp-mliap \
	"${WORK_DIR}/NequIP-OAM-L-0.1.nequip.zip" \
	"${WORK_DIR}/NequIP-OAM-L-OEQ-a100.nequip.lmp.pt"
