#!/bin/bash
#SBATCH -N 1
#SBATCH -n 2
#SBATCH -c 4
#SBATCH -t 00:20:00          
#SBATCH -J MD
#SBATCH -o runout.%j  
#SBATCH -e runerr.%j  
#SBATCH -p gpu
#SBATCH --gres=gpu:2
#SBATCH --mem=16000
#SBATCH --account m5156
#SBATCH --constraint gpu

infile=lammps.in
num_gpu_per_node=1
nodes_per_run=1
#Num nodes times num gpu
num_task=$((num_gpu_per_node*nodes_per_run))

export OMP_PROC_BIND=spread
export OMP_PLACES=threads

source ~/.bashrc

# Laod modules
module load cmake/3.30.2
module load cudatoolkit/12.9
module load craype-accel-nvidia80
module load cudnn/9.5.0
module list

# Activate micromamba env
micromamba activate mliap_benchmark_2025
lammps=/lammps/build/lmp

nvidia-smi
export OMP_NUM_THREADS=1

# Update with path to LAMMPS executable
srun -n $num_task $lammps -k on g $num_gpu_per_node -sf kk -pk kokkos newton on neigh half -in $infile -pk kokkos gpu/aware on
