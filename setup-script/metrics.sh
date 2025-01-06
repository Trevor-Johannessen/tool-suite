# This script downloads the prometheus exporter for general linux metrics. It deploys the exporter as a service which is then enabled.

# Abort if not root
if [ "$EUID" -ne 0 ]; then 
    echo "error: This script must be ran as root"
    echo "Exiting..."
    exit 1
fi

# Save the current working directory
CWD=$(pwd)

# Install dependencies
sudo dnf install -y util-linux-user

# Create needed users and groups
sudo useradd node_exporter
sudo groupadd node_exporter
chsh -s /sbin/nologin node_exporter

# Create needed directories
sudo mkdir -p /etc/sysconfig/node_exporter
sudo mkdir -p /var/lib/node_exporter/textfile_collector

sudo chown node_exporter:node_exporter /var/lib/node_exporter/textfile_collector

# Download the program
wget https://github.com/prometheus/node_exporter/releases/download/v1.8.2/node_exporter-1.8.2.linux-amd64.tar.gz
tar xvfz  node_exporter-*.*-amd64.tar.gz
cd node_exporter-*-amd64
sudo chmod 755 node_exporter
sudo chown node_exporter:node_exporter node_exporter

# Download the config files
#sudo curl https://raw.githubusercontent.com/prometheus/node_exporter/refs/heads/master/examples/systemd/node_exporter.service > /etc/systemd/system/node_exporter.service
cp ./services/node_exporter.service /etc/systemd/system/node_exporter/node_exporter.service
sudo curl https://raw.githubusercontent.com/prometheus/node_exporter/refs/heads/master/examples/systemd/node_exporter.socket > /etc/systemd/system/node_exporter.socket
sudo curl https://raw.githubusercontent.com/prometheus/node_exporter/refs/heads/master/examples/systemd/sysconfig.node_exporter > /etc/sysconfig/node_exporter/sysconfig.node_exporter

# Install the program
mv node_exporter /bin/node_exporter
ln -s /bin/node_exporter /usr/sbin/node_exporter

# Create an exception for SELinux
sudo chcon -t bin_t /usr/sbin/node_exporter

# Set firewall rules
sudo firewall-cmd --permanent --add-port 9100/tcp
sudo firewall-cmd --reload

# Start and enable the service
sudo systemctl daemon-reload
sudo systemctl start node_exporter
sudo systemctl enable node_exporter

# Clean up
rm -r node_exporter*amd6*

# Return to the current working directory
cd $CWD
