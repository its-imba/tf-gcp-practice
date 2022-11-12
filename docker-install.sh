# Install docker and add Docker user with permissions
sudo apt-get update
sudo apt install curl -y
curl https://get.docker.com | sudo bash
sudo usermod -aG docker $(whoami)

