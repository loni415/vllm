#!/bin/bash
set -euo pipefail

echo "=============================================="
echo "vLLM HPC Environment Setup - Task 1"
echo "=============================================="

# -----------------------------------------------------------------------------
# 1) Load modules (CUDA 12.8.0 + Python 3.11 via miniforge)
# -----------------------------------------------------------------------------
echo "[1/6] Loading modules..."
if command -v module >/dev/null 2>&1; then
  module purge
  module load miniforge/24.3.0-py3.11
  module load cuda/12.8.0
  echo "✓ Modules loaded"
else
  echo "⚠ 'module' command not found. Assuming non-HPC environment."
  echo "  Ensure Python 3.11+ and CUDA libraries are available."
fi

# -----------------------------------------------------------------------------
# 2) Set CUDA environment variables (prefer module-provided CUDA; fallback if needed)
# -----------------------------------------------------------------------------
echo "[2/6] Setting CUDA environment variables..."

# Prefer CUDA location already set by the module, if present
if [ -n "${CUDA_HOME:-}" ] && [ -d "${CUDA_HOME}" ]; then
  :
elif [ -n "${CUDA_PATH:-}" ] && [ -d "${CUDA_PATH}" ]; then
  export CUDA_HOME="${CUDA_PATH}"
else
  # Try a known site path, then fallback to inferring from nvcc
  CANDIDATE="/opt/nvidia/hpc_sdk/Linux_x86_64/24.5/cuda"
  if [ -d "$CANDIDATE" ]; then
    export CUDA_HOME="$CANDIDATE"
  elif command -v nvcc >/dev/null 2>&1; then
    export CUDA_HOME="$(dirname "$(dirname "$(command -v nvcc)")")"
  else
    echo "WARNING: nvcc not found and no CUDA_HOME/CUDA_PATH set."
    echo "  Proceeding assuming pre-built wheels will be used (which don't require nvcc)."
    # Fallback to empty or system default
    CUDA_HOME=""
  fi
fi

if [ -n "$CUDA_HOME" ]; then
  export CUDA_PATH="$CUDA_HOME"
  export PATH="$CUDA_HOME/bin:$PATH"
  export LD_LIBRARY_PATH="$CUDA_HOME/lib64:${LD_LIBRARY_PATH:-}"
  echo "CUDA_HOME = $CUDA_HOME"
else
  echo "CUDA_HOME not set (nvcc missing). Skipping CUDA env exports."
fi

# -----------------------------------------------------------------------------
# 3) Verify CUDA installation
# -----------------------------------------------------------------------------
echo "[3/6] Verifying CUDA..."
if command -v nvcc >/dev/null 2>&1; then
  nvcc --version
  echo "✓ CUDA verified"
else
  echo "⚠ nvcc not found (skipping verification)"
fi

# -----------------------------------------------------------------------------
# 4) Verify compiler toolchain
# -----------------------------------------------------------------------------
echo "[4/6] Verifying compiler toolchain..."
gcc --version | head -n1
g++ --version | head -n1
cmake --version | head -n1
echo "✓ Compiler toolchain verified"

# -----------------------------------------------------------------------------
# 5) Create Python virtual environment (uv-recommended for vLLM)
#    Creates ./vllm in the *current directory* (not $HOME), per your desired pattern
# -----------------------------------------------------------------------------
echo "[5/6] Creating Python virtual environment with uv..."
VENV_DIR="mineru"

# Ensure uv exists (install to user-space if missing)
if ! command -v uv >/dev/null 2>&1; then
  echo "uv not found; installing uv into user site-packages..."
  python3 -m pip install --user -U uv
  export PATH="$HOME/.local/bin:$PATH"
fi

if [ -d "$VENV_DIR" ]; then
  echo "✓ Virtual environment directory '$VENV_DIR' already exists"
else
  uv venv --python 3.11 --seed "$VENV_DIR"
  echo "✓ Virtual environment created at $(pwd)/$VENV_DIR"
fi

# -----------------------------------------------------------------------------
# 6) Activate venv and upgrade packaging tools
# -----------------------------------------------------------------------------
echo "[6/6] Activating virtualenv and upgrading pip..."
# shellcheck disable=SC1090
source "$VENV_DIR/bin/activate"
echo "✓ Virtual environment activated: ${VIRTUAL_ENV}"

# Verify venv is using uv's Python
python --version

python -m pip install -U pip setuptools wheel
echo "✓ pip upgraded"

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
echo ""
echo "=============================================="
echo "Environment Summary:"
echo "=============================================="
echo "CUDA_HOME: $CUDA_HOME"
echo "Python: $(python --version 2>&1)"
echo "NVCC: $(nvcc --version | grep -E 'release|V[0-9]+' || true)"
echo "GCC: $(gcc --version | head -n1 || true)"
echo "CMake: $(cmake --version | head -n1 || true)"
echo "Virtual Env: $(pwd)/$VENV_DIR"
echo "Virtual Env Active: ${VIRTUAL_ENV:-none}"
echo "=============================================="
echo "✓ Task 1 Complete - Ready for Task 2 (PyTorch)"