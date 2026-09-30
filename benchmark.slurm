#!/bin/bash
#SBATCH -J nequip
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -c 32
#SBATCH --gpus-per-task=1
#SBATCH --constraint="gpu&hbm80g"
#SBATCH --qos=shared
#SBATCH -t 08:00:00
#SBATCH --mem-per-gpu=48G
#SBATCH --account=m5156

set -e

WORK="$SLURM_SUBMIT_DIR/nequip-benchmark-$SLURM_JOB_ID"
mkdir "$WORK"
exec >"$WORK/benchmark.${SLURM_JOB_ID}.out" 2>"$WORK/benchmark.${SLURM_JOB_ID}.err"

source ~/.bashrc

module load PrgEnv-gnu
module load cmake/3.30.2
module load cudatoolkit/13.2
module load craype-accel-nvidia80
module list

export CRAY_ACCEL_TARGET=nvidia80
export CC="$(command -v cc)"
export CXX="$(command -v CC)"
export FC="$(command -v ftn)"
export NVCC_WRAPPER_DEFAULT_COMPILER="$CXX"
export SLURM_CPU_BIND=cores
export OMP_NUM_THREADS=1
export MPICH_GPU_SUPPORT_ENABLED=1

cd "$WORK"

micromamba create -y -p "$WORK/env" python=3.11 pip
micromamba activate "$WORK/env"

# PyTorch 2.9 is the newest series supported by NequIP's TorchScript compiler.
pip install \
    --extra-index-url https://download.pytorch.org/whl/cu130 \
    torch==2.9.1+cu130 \
    cython==3.0.11 \
    cupy-cuda12x \
    openequivariance==0.6.8 \
    cuequivariance==0.10.0 \
    cuequivariance-torch==0.10.0 \
    cuequivariance-ops-torch-cu13==0.10.0
python -c 'import torch; assert torch.__version__ == "2.9.1+cu130", torch.__version__'
pip check

git clone --depth=1 https://github.com/mir-group/nequip.git
pip install -e nequip
git clone --depth=1 https://github.com/mir-group/allegro.git
pip install -e allegro
python -c 'import torch; assert torch.__version__ == "2.9.1+cu130", torch.__version__'
pip check
git clone --depth=1 https://github.com/mir-group/pair_nequip_allegro.git

curl -L https://github.com/lammps/lammps/releases/download/patch_30Mar2026/lammps-src-30Mar2026.tar.gz \
    -o lammps-src-30Mar2026.tar.gz
tar -xzf lammps-src-30Mar2026.tar.gz

cd pair_nequip_allegro
./patch_lammps.sh ../lammps-30Mar2026/
cd ..

cmake \
    -S lammps-30Mar2026/cmake \
    -B lammps-build \
    -D CMAKE_BUILD_TYPE=Release \
    -D CMAKE_CXX_COMPILER="$WORK/lammps-30Mar2026/lib/kokkos/bin/nvcc_wrapper" \
    -D CMAKE_CXX_STANDARD=20 \
    -D CMAKE_PREFIX_PATH="$(python -c 'import torch; print(torch.utils.cmake_prefix_path)')" \
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
    -D PKG_PYTHON=ON

cmake --build lammps-build -j "$SLURM_CPUS_PER_TASK"
cmake --build lammps-build --target install-python -j "$SLURM_CPUS_PER_TASK"

# TorchInductor needs a conventional host compiler at runtime
export CC="$(command -v gcc)"
export CXX="$(command -v g++)"
export LIBRARY_PATH="${LD_LIBRARY_PATH}${LIBRARY_PATH:+:$LIBRARY_PATH}"

mkdir models results
curl -L https://zenodo.org/api/records/18775904/files/NequIP-OAM-L-0.1.nequip.zip/content \
    -o models/NequIP-OAM-L-0.1.nequip.zip
curl -L https://raw.githubusercontent.com/mir-group/nequip-benchmark-run/8507cd5dbc2329235d40aa58964ca1ad9bf816da/runs/baseline_measurement/structure/structure_conventional.data \
    -o structure.data

nequip-prepare-lmp-mliap \
    models/NequIP-OAM-L-0.1.nequip.zip \
    models/NequIP-L-mliap-a100.nequip.lmp.pt

nequip-prepare-lmp-mliap \
    models/NequIP-OAM-L-0.1.nequip.zip \
    models/NequIP-L-mliap-cueq-a100.nequip.lmp.pt \
    --modifiers enable_CuEquivariance

nequip-prepare-lmp-mliap \
    models/NequIP-OAM-L-0.1.nequip.zip \
    models/NequIP-L-mliap-openeq-a100.nequip.lmp.pt \
    --modifiers enable_OpenEquivariance

nequip-compile \
    models/NequIP-OAM-L-0.1.nequip.zip \
    models/NequIP-L-torchscript-a100.nequip.pth \
    --device cuda \
    --mode torchscript

cat >mliap.in <<'EOF'
units         metal
boundary      p p p
atom_style    atomic
atom_modify   map yes
newton        on

read_data     structure.data
replicate     6 6 6

pair_style    mliap unified ${model} 0
pair_coeff    * * Li P S Cl
velocity      all create 300.0 123 rot yes dist gaussian

timestep      0.001
thermo        100

fix           f1 all nve
run           500
run           2000
EOF

cat >torchscript.in <<'EOF'
units         metal
boundary      p p p
atom_style    atomic
atom_modify   map yes
newton        off

read_data     structure.data
replicate     6 6 6

pair_style    nequip
pair_coeff    * * ${model} Li P S Cl
velocity      all create 300.0 123 rot yes dist gaussian

timestep      0.001
thermo        100

fix           f1 all nve
run           500
run           2000
EOF


echo "Running compiled ML-IAP baseline"
srun lammps-build/lmp \
    -k on g 1 -sf kk -pk kokkos newton on neigh half \
    -var model "$WORK/models/NequIP-L-mliap-a100.nequip.lmp.pt" \
    -in mliap.in -log results/mliap.log -screen results/mliap.screen \
    -pk kokkos gpu/aware on

echo "Running compiled ML-IAP with cuEquivariance"
srun lammps-build/lmp \
    -k on g 1 -sf kk -pk kokkos newton on neigh half \
    -var model "$WORK/models/NequIP-L-mliap-cueq-a100.nequip.lmp.pt" \
    -in mliap.in -log results/cueq.log -screen results/cueq.screen \
    -pk kokkos gpu/aware on

echo "Running compiled ML-IAP with OpenEquivariance"
srun lammps-build/lmp \
    -k on g 1 -sf kk -pk kokkos newton on neigh half \
    -var model "$WORK/models/NequIP-L-mliap-openeq-a100.nequip.lmp.pt" \
    -in mliap.in -log results/openeq.log -screen results/openeq.screen \
    -pk kokkos gpu/aware on

echo "Running TorchScript"
srun lammps-build/lmp \
    -k on g 1 -sf kk -pk kokkos newton on neigh half \
    -var model "$WORK/models/NequIP-L-torchscript-a100.nequip.pth" \
    -in torchscript.in -log results/torchscript.log -screen results/torchscript.screen \
    -pk kokkos gpu/aware on
