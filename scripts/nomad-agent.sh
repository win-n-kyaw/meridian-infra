export DEBIAN_FRONTEND=noninteractive
sudo -E apt update
sudo -E apt-get install curl -y
curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | sudo bash
sudo sed -i 's/noble/jammy/g' /etc/apt/sources.list.d/ookla_speedtest-cli.list
sudo -E apt install dnsmasq iptables-persistent speedtest -y
curl -s https://raw.githubusercontent.com/khantzawhein/outline-server-dnsmasq-setup/refs/heads/main/setup_dnsmasq.sh | sudo bash
sudo iptables -I INPUT -j ACCEPT
sudo netfilter-persistent save
sudo -E apt update
sudo -E apt install vnstat iftop fail2ban -y
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
sudo -E apt update
sudo -E apt install ca-certificates curl -y
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo -E apt update
sudo -E apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
sudo bash -c "$(wget -qO- https://raw.githubusercontent.com/Jigsaw-Code/outline-apps/master/server_manager/install_scripts/install_server.sh)"

echo "Adding HashiCorp GPG key..."
wget -O- https://apt.releases.hashicorp.com/gpg | \
sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg --yes

# Add the official HashiCorp repository
echo "Adding HashiCorp repository to sources..."
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
sudo tee /etc/apt/sources.list.d/hashicorp.list > /dev/null

# Update and install Nomad
echo "Installing Nomad..."
sudo apt-get install -y nomad

# Verify installation
echo "Installation complete. Verification:"
nomad version