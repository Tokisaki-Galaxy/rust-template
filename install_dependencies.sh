#!/bin/bash
# Install musl cross-compilation toolchains
# Prerequisites: build-essential, musl-tools, Rust stable + nightly toolchains
# In CI, these prerequisites are handled by the workflow (build.yml)

set -e

INSTALL_BASE="/opt/musl-cross"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=========================================="
echo "Install cross-compilation toolchains"
echo "Install directory: $INSTALL_BASE"
echo "=========================================="

# Define toolchains to install
# Format: "toolchain_name:linker_name"
declare -A TOOLCHAINS=(
    ["arm-linux-musleabihf-cross"]="arm-linux-musleabihf-gcc"
    ["arm-linux-musleabi-cross"]="arm-linux-musleabi-gcc"
    ["aarch64-linux-musl-cross"]="aarch64-linux-musl-gcc"
    ["riscv64-linux-musl-cross"]="riscv64-linux-musl-gcc"
    ["powerpc64le-linux-musl-cross"]="powerpc64le-linux-musl-gcc"
    ["mips-linux-musl-cross"]="mips-linux-musl-gcc"
    ["mipsel-linux-musl-cross"]="mipsel-linux-musl-gcc"
)

MUSL_CC_BASE="https://github.com/timsaya/musl-cc/releases/download/v0.1.0/"

# Create install directory
mkdir -p "$INSTALL_BASE"

# Install each toolchain
echo ""
echo -e "${YELLOW}[1/2] Downloading and installing cross toolchains...${NC}"
INSTALLED_COUNT=0
SKIPPED_COUNT=0

for toolchain_name in "${!TOOLCHAINS[@]}"; do
    linker_name="${TOOLCHAINS[$toolchain_name]}"
    install_dir="$INSTALL_BASE/$toolchain_name"
    download_url="$MUSL_CC_BASE/$toolchain_name.tgz"
    
    echo -n "  Checking $toolchain_name ... "
    
    # Check if toolchain is already fully installed (directory and linker both exist)
    if [ -d "$install_dir" ] && [ -f "$install_dir/bin/$linker_name" ] && [ -x "$install_dir/bin/$linker_name" ]; then
        echo -e "${GREEN}Already exists, skipping${NC}"
        SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
        continue
    fi
    
    # If directory exists but linker doesn't, it might be a broken install - clean up
    if [ -d "$install_dir" ]; then
        echo -n "Cleaning broken install... "
        rm -rf "$install_dir"
    fi
    
    # Download and install
    echo "Downloading and installing..."
    cd /tmp
    if curl -L -o "${toolchain_name}.tgz" "$download_url" && [ -f "${toolchain_name}.tgz" ] && [ -s "${toolchain_name}.tgz" ]; then
        tar -xzf "${toolchain_name}.tgz" -C "$INSTALL_BASE"
        rm -f "${toolchain_name}.tgz"
        
        # Verify installation
        if [ -d "$install_dir" ] && [ -f "$install_dir/bin/$linker_name" ] && [ -x "$install_dir/bin/$linker_name" ]; then
            echo -e "${GREEN}Success${NC}"
            INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
        else
            echo -e "${RED}Failed (verification failed after install)${NC}"
        fi
    else
        echo -e "${RED}Failed (download or extraction error)${NC}"
    fi
done

# Verify all toolchains
echo ""
echo -e "${YELLOW}[2/2] Verifying installation...${NC}"
for toolchain_name in "${!TOOLCHAINS[@]}"; do
    linker_name="${TOOLCHAINS[$toolchain_name]}"
    install_dir="$INSTALL_BASE/$toolchain_name"
    
    if [ -d "$install_dir" ] && [ -f "$install_dir/bin/$linker_name" ] && [ -x "$install_dir/bin/$linker_name" ]; then
        version=$("$install_dir/bin/$linker_name" --version 2>&1 | head -1 || echo "Unable to get version")
        echo -e "  ${GREEN}✓${NC} $linker_name: $version"
    else
        echo -e "  ${RED}✗${NC} $linker_name: Not installed or broken"
    fi
done

# Summary
echo ""
echo "=========================================="
echo "Installation complete"
echo "=========================================="
echo "Newly installed: $INSTALLED_COUNT"
echo "Already existed: $SKIPPED_COUNT"
echo "Total: ${#TOOLCHAINS[@]}"
echo ""
echo "Toolchain location: $INSTALL_BASE"
echo ""
