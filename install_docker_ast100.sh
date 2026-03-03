# Mise à jour des dépôts
sudo apt update

# Installation des outils nécessaires
sudo apt install ca-certificates curl gnupg lsb-release -y

# Ajout de la clé de sécurité Docker
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Ajout du dépôt Docker dans tes sources
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Installation finale
sudo apt update
sudo apt install docker-ce docker-ce-cli containerd.io docker-compose-plugin -y
