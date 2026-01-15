#!/bin/bash
set -euo pipefail

echo "=============================================="
echo "MinerU Integration with vLLM - Task 4"
echo "=============================================="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VLLM_VENV_DIR="mineru"
VLLM_VENV_PATH="${SCRIPT_DIR}/${VLLM_VENV_DIR}"

# -----------------------------------------------------------------------------
# 1) Verify vLLM Environment Exists
# -----------------------------------------------------------------------------
echo "[1/2] Verifying vLLM virtual environment..."

if [ ! -d "$VLLM_VENV_PATH" ]; then
  echo "ERROR: vLLM virtual environment not found at: $VLLM_VENV_PATH"
  echo "Please run setup1.sh, setup2.sh, and setup3.sh first."
  exit 1
fi

if [ ! -f "$VLLM_VENV_PATH/bin/activate" ]; then
  echo "ERROR: Invalid venv at $VLLM_VENV_PATH (missing bin/activate)."
  exit 1
fi

echo "✓ Found vLLM venv at: $VLLM_VENV_PATH"

# -----------------------------------------------------------------------------
# 1.5) Fix for GCC 15 incompatibility (Force nvcc to use gcc-12)
# -----------------------------------------------------------------------------
if [ -f "/usr/bin/gcc-12" ]; then
    echo "Configuring NVCC to use gcc-12..."
    export NVCC_CCBIN="/usr/bin/gcc-12"
    
    # Persist in activate script if not already present
    if ! grep -q "NVCC_CCBIN" "$VLLM_VENV_PATH/bin/activate"; then
        echo "" >> "$VLLM_VENV_PATH/bin/activate"
        echo "# Fix for GCC 15+ incompatibility with CUDA 12.8" >> "$VLLM_VENV_PATH/bin/activate"
        echo "export NVCC_CCBIN=/usr/bin/gcc-12" >> "$VLLM_VENV_PATH/bin/activate"
        echo "Added NVCC_CCBIN export to activate script."
    fi
else
    echo "WARNING: gcc-12 not found. You may encounter JIT compilation errors if system GCC is > 14."
fi

# -----------------------------------------------------------------------------
# 2) Run MinerU Installation targeting the vLLM venv
# -----------------------------------------------------------------------------
echo "[2/2] Installing MinerU into vLLM environment..."
echo "  Calling: MINERU_VENV_DIR=$VLLM_VENV_DIR ./install_mineru.sh"
echo ""

# We set MINERU_VENV_DIR to 'vllm' so install_mineru.sh uses the existing env.
# install_mineru.sh has protection logic to avoid downgrading vLLM's critical deps.
export MINERU_VENV_DIR="$VLLM_VENV_DIR"

"${SCRIPT_DIR}/install_mineru.sh"

echo ""
echo "=============================================="
echo "Task 4 Complete"
echo "=============================================="
echo "MinerU has been installed into the vLLM environment."
echo "You can now run vLLM and MinerU in the same process."
echo "Activate with: source ${VLLM_VENV_DIR}/bin/activate"
echo "=============================================="
