# VS Code Extension Issue Fixes

This document provides solutions for the VS Code extension issues encountered in the AutoGen project.

## Docker Extension Issue

**Problem**: An unsupported version of the Docker extension is installed.

**Solution**:
1. A script `update-docker-extension.ps1` has been created to uninstall the old Docker extension
2. After running the script, follow the on-screen instructions to install the latest Docker extension (version 2.0.0 or later)
3. Restart VS Code after installation

## C/C++ Configuration Warning

**Problem**: The C/C++ extension can't find the NVIDIA CUDA compiler at `C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.8\bin\nvcc.exe`

**Solution**:
1. A proper C/C++ configuration file has been created: `.vscode/c_cpp_properties.json`
2. The compilerPath has been intentionally left blank since the CUDA toolkit isn't installed
3. If you need CUDA support, install the NVIDIA CUDA Toolkit and update the `compilerPath` accordingly

## If You Need CUDA Support

If you actually need CUDA support for this project:

1. Download and install the NVIDIA CUDA Toolkit from: https://developer.nvidia.com/cuda-downloads
2. After installation, update the `.vscode/c_cpp_properties.json` file with the correct path to `nvcc.exe`
3. Typical path after installation: `C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v<version>\bin\nvcc.exe`

## Additional Information

If you encounter any other extension issues:
1. Check the VS Code Output panel (View > Output)
2. Select the problematic extension from the dropdown
3. Look for error messages that provide more details
