#!/bin/bash

# Update and install prerequisites
sudo apt-get update && sudo apt-get install -y \
    curl git build-essential libssl-dev libreadline-dev zlib1g-dev

# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source $HOME/.cargo/env

# Install Aptos CLI
cargo install aptos --locked

# Install Move Analyzer (Language Server)
cargo install move-analyzer

# Verify installations
echo "Installed Versions:"
aptos --version
move-analyzer --version

# Create default Aptos configuration
aptos init --assume-yes
