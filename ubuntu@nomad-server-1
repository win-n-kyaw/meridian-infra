#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

echo "Updating system packages..."
sudo apt-get update && sudo apt-get install -y wget gpg coreutils lsb-release

# Create directory for keyrings if it doesn't exist
sudo mkdir -p -m 755 /usr/share/keyrings

# Download HashiCorp GPG key and dearmor it
# The -f flag overwrites the file if you run the script twice
echo "Adding HashiCorp GPG key..."
wget -O- https://apt.releases.hashicorp.com/gpg | \
sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg --yes

# Add the official HashiCorp repository
echo "Adding HashiCorp repository to sources..."
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
sudo tee /etc/apt/sources.list.d/hashicorp.list > /dev/null

# Update and install Nomad
echo "Installing Nomad..."
sudo apt-get update && sudo apt-get install -y nomad

# Verify installation
echo "Installation complete. Verification:"
nomad version