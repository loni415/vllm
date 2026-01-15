# MinerU Installation Guide

This document describes the `install_mineru.sh` script for installing MinerU on your system.

## Overview

MinerU is a powerful PDF document extraction tool that converts PDF documents into structured formats. The `install_mineru.sh` script automates the installation process by:

1. Creating a Python virtual environment named `mineru`
2. Activating the virtual environment
3. Installing MinerU (magic-pdf) with all necessary dependencies
4. Verifying the installation

## System Requirements

- **Operating System**: Debian GNU/Linux (or compatible)
- **Python**: 3.10 or higher (tested with 3.13.11)
- **GPU**: NVIDIA GPU with CUDA support (optional but recommended)
  - Example: RTX 5090 with CUDA 12.0 compute capability
  - Driver: 580.126.09 or compatible
- **RAM**: At least 8 GB recommended
- **Disk Space**: ~2-5 GB for MinerU and dependencies

## Quick Start

### Basic Installation

```bash
chmod +x install_mineru.sh
./install_mineru.sh
```

This will:
- Create a `mineru/` directory with a Python virtual environment
- Install MinerU with all recommended dependencies (`magic-pdf[full]`)
- Create an installation log at `mineru_install.log`

### Using the Virtual Environment

After installation, activate the virtual environment:

```bash
source mineru/bin/activate
```

Run MinerU commands:

```bash
magic-pdf --help
```

Deactivate when done:

```bash
deactivate
```

## Advanced Options

### Install System Dependencies

To automatically install system-level dependencies (requires sudo):

```bash
MINERU_INSTALL_SYSTEM_DEPS=1 ./install_mineru.sh
```

This installs:
- `python3-venv`, `python3-dev`
- Build tools (`build-essential`, `pkg-config`)
- PDF/OCR tools (`poppler-utils`, `tesseract-ocr`)
- OpenCV runtime libraries

### Recreate Virtual Environment

To force recreation of an existing virtual environment:

```bash
MINERU_VENV_RECREATE=1 ./install_mineru.sh
```

### Custom Package Specification

To install a different version or configuration:

```bash
# Install minimal version without extras
MINERU_PIP_SPEC='magic-pdf' ./install_mineru.sh

# Install specific version
MINERU_PIP_SPEC='magic-pdf[full]==0.7.0' ./install_mineru.sh
```

## Troubleshooting

### Python 3.13 Compatibility

If you encounter wheel availability issues with Python 3.13:

```bash
# Create venv with Python 3.11 (if available)
python3.11 -m venv mineru
source mineru/bin/activate
pip install --upgrade pip setuptools wheel
pip install magic-pdf[full]
```

### Missing System Dependencies

If installation fails due to missing libraries:

```bash
# On Debian/Ubuntu
sudo apt-get update
sudo apt-get install -y python3-venv python3-dev build-essential \
  poppler-utils tesseract-ocr libgl1 libglib2.0-0
```

### GPU/CUDA Issues

MinerU can work with or without GPU acceleration:
- **With GPU**: Automatically uses CUDA if PyTorch with CUDA support is installed
- **Without GPU**: Falls back to CPU processing (slower but functional)

The installation script installs CPU versions by default. For GPU support, you may need to install PyTorch with CUDA separately:

```bash
source mineru/bin/activate
pip install torch torchvision --index-url https://download.pytorch.org/whl/cu121
```

### Verification Failures

If the verification step fails:

1. Check the installation log:
   ```bash
   cat mineru_install.log
   ```

2. Try importing manually:
   ```bash
   source mineru/bin/activate
   python -c "import magic_pdf; print(magic_pdf)"
   ```

3. List installed packages:
   ```bash
   source mineru/bin/activate
   pip list | grep -i magic
   ```

## File Structure

After running the script, you'll have:

```
project/
├── install_mineru.sh       # Installation script
├── mineru/                 # Virtual environment (gitignored)
│   ├── bin/
│   ├── lib/
│   └── ...
└── mineru_install.log      # Installation log (gitignored)
```

## Usage Examples

### Basic PDF Processing

```python
from magic_pdf import MagicPDF

# Process a PDF file
pdf = MagicPDF("document.pdf")
result = pdf.extract()
```

### Command Line Usage

```bash
# Activate the virtual environment
source mineru/bin/activate

# Process a PDF (check magic-pdf documentation for exact CLI usage)
magic-pdf --help
magic-pdf extract input.pdf --output output.json
```

## Environment Variables

The script respects these environment variables:

- `MINERU_INSTALL_SYSTEM_DEPS`: Install OS dependencies (default: 0)
- `MINERU_VENV_RECREATE`: Recreate venv if exists (default: 0)
- `MINERU_PIP_SPEC`: Package specification to install (default: `magic-pdf[full]`)
- `PIP_DISABLE_PIP_VERSION_CHECK`: Set to 1 by script
- `PIP_NO_INPUT`: Set to 1 by script

## Integration with vLLM Project

This script is designed to work alongside the vLLM installation scripts:
- `setup1.sh`: Creates `vllm/` venv for vLLM
- `setup2.sh`: Installs PyTorch in `vllm/` venv
- `setup3.sh`: Installs vLLM in `vllm/` venv
- `install_mineru.sh`: Creates separate `mineru/` venv for MinerU

The separate virtual environments prevent dependency conflicts (Recommended).

### Combined Installation (Advanced)

If you need to run MinerU and vLLM in the same Python process, you can attempt to install MinerU into the existing vLLM virtual environment.

**Warning**: This may cause dependency conflicts. The installation script attempts to protect critical vLLM packages (like `torch`, `vllm`, and `opencv`) by pinning them to their current versions. If MinerU requires incompatible versions, the installation will fail with an error to prevent breaking your vLLM setup.

To attempt a combined install, run the dedicated integration script after completing setup 1-3:

```bash
./setup4_mineru_into_vllm.sh
```

Or manually:

```bash
# Install into the 'vllm' directory created by setup1.sh
MINERU_VENV_DIR="vllm" ./install_mineru.sh
```

If this fails due to version conflicts, you should stick to the separate environment approach.

## References

- **MinerU GitHub**: https://github.com/opendatalab/MinerU
- **magic-pdf PyPI**: https://pypi.org/project/magic-pdf/
- **Python venv documentation**: https://docs.python.org/3/library/venv.html

## Support

For issues specific to:
- **MinerU/magic-pdf**: Check the [MinerU GitHub Issues](https://github.com/opendatalab/MinerU/issues)
- **This installation script**: Create an issue in this repository
- **vLLM integration**: See vLLM documentation

## License

This installation script is part of the vLLM project and follows the same license.
