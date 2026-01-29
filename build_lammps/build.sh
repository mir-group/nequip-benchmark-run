#!/bin/bash
#SBATCH -J lmp_compile
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=16
#SBATCH --gres=gpu:1
#SBATCH -t 00:50:00
#SBATCH --mem=75GB
#SBATCH -o logs/%j.err
#SBATCH -e logs/%j.out
#SBATCH --account m4297
#SBATCH -C gpu
#SBATCH -q regular

source ~/.bashrc

# Laod modules
module load cmake/3.30.2
module load cudatoolkit/12.9
module load craype-accel-nvidia80
module load cudnn/9.5.0
module list

export CRAY_ACCEL_TARGET=nvidia80

# Activate micromamba env
micromamba activate mliap_benchmark_2025

# Build LAMMPS
export NVCC_WRAPPER_DEFAULT_COMPILER=$(which CC)  # for kokkos
cmake \
    -B build \
    -D CMAKE_BUILD_TYPE=Release \
    -D CMAKE_CXX_COMPILER=$(pwd)/lib/kokkos/bin/nvcc_wrapper \
    -D CMAKE_CXX_STANDARD=20 \
    -D CMAKE_PREFIX_PATH=`python -c 'import torch;print(torch.utils.cmake_prefix_path)'` \
    -D MKL_INCLUDE_DIR=/tmp \
    -D CAFFE2_USE_CUDNN=ON \
    -D BUILD_SHARED_LIBS=ON \
    -D PKG_KOKKOS=ON \
    -D Kokkos_ENABLE_SERIAL=ON \
    -D Kokkos_ENABLE_CUDA=ON \
    -D Kokkos_ARCH_AMPERE80=ON \
    -D NEQUIP_AOT_COMPILE=ON \
    -D BUILD_MPI=ON \
    -D PKG_ML-IAP=ON \
    -D PKG_ML-SNAP=ON \
    -D MLIAP_ENABLE_PYTHON=ON \
    -D PKG_PYTHON=ON \
    cmake

cmake --build build -j 16

cd build
make install-python
