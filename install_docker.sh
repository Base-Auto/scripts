#!/bin/bash
# =============================================================================
# Script d'installation automatique de Docker
# Supporte : Ubuntu, Debian
# Usage    : sudo bash install_docker.sh
# =============================================================================

set -euo pipefail

# --- Couleurs ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log()     { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }
section() { echo -e "\n${BLUE}==> $*${NC}"; }

# --- Vérification root ---
if [[ "$EUID" -ne 0 ]]; then
    error "Ce script doit être exécuté en tant que root (sudo bash $0)"
fi

# --- Détection de la distribution ---
section "Détection de la distribution"

if [[ ! -f /etc/os-release ]]; then
    error "Impossible de détecter la distribution (fichier /etc/os-release absent)"
fi

source /etc/os-release

DISTRO="${ID}"
VERSION_CODENAME="${VERSION_CODENAME:-}"

# Fallback pour les distros dérivées (ex: Linux Mint basé sur Ubuntu)
if [[ -z "$VERSION_CODENAME" && -n "${UBUNTU_CODENAME:-}" ]]; then
    VERSION_CODENAME="$UBUNTU_CODENAME"
fi

case "$DISTRO" in
    ubuntu)
        log "Distribution détectée : Ubuntu $VERSION_ID ($VERSION_CODENAME)"
        DOCKER_REPO="https://download.docker.com/linux/ubuntu"
        ;;
    debian)
        log "Distribution détectée : Debian $VERSION_ID ($VERSION_CODENAME)"
        DOCKER_REPO="https://download.docker.com/linux/debian"
        ;;
    *)
        error "Distribution non supportée : $DISTRO. Ce script supporte uniquement Ubuntu et Debian."
        ;;
esac

if [[ -z "$VERSION_CODENAME" ]]; then
    error "Impossible de déterminer le codename de la distribution."
fi

# --- Vérification si Docker est déjà installé ---
section "Vérification de l'installation existante"

if command -v docker &>/dev/null; then
    CURRENT_VERSION=$(docker --version 2>/dev/null || echo "inconnue")
    warn "Docker est déjà installé : $CURRENT_VERSION"
    read -rp "Voulez-vous réinstaller/mettre à jour Docker ? [o/N] " confirm
    if [[ ! "$confirm" =~ ^[oOyY]$ ]]; then
        log "Installation annulée."
        exit 0
    fi
fi

# --- Suppression des anciens paquets ---
section "Suppression des anciens paquets Docker"

OLD_PACKAGES=(docker docker-engine docker.io containerd runc docker-compose)
for pkg in "${OLD_PACKAGES[@]}"; do
    if dpkg -l "$pkg" &>/dev/null 2>&1; then
        log "Suppression de $pkg..."
        apt-get remove -y "$pkg" 2>/dev/null || true
    fi
done
log "Nettoyage terminé."

# --- Mise à jour et dépendances ---
section "Installation des dépendances"

apt-get update -qq
apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# --- Ajout de la clé GPG officielle Docker ---
section "Ajout de la clé GPG Docker"

install -m 0755 -d /etc/apt/keyrings
curl -fsSL "${DOCKER_REPO}/gpg" | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
log "Clé GPG ajoutée."

# --- Ajout du dépôt Docker ---
section "Ajout du dépôt Docker"

ARCH=$(dpkg --print-architecture)
echo \
    "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.gpg] ${DOCKER_REPO} \
    ${VERSION_CODENAME} stable" \
    > /etc/apt/sources.list.d/docker.list

log "Dépôt Docker ajouté pour ${DISTRO} ${VERSION_CODENAME} (${ARCH})."

# --- Installation de Docker ---
section "Installation de Docker Engine"

apt-get update -qq
apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

# --- Activation et démarrage du service ---
section "Activation du service Docker"

systemctl enable docker
systemctl start docker
log "Service Docker démarré et activé au démarrage."

# --- Ajout de l'utilisateur au groupe docker ---
section "Configuration des permissions (groupe docker)"

# Priorité : SUDO_USER (l'utilisateur qui a lancé sudo), sinon on demande
REAL_USER="${SUDO_USER:-}"

# Si lancé en root direct ou SUDO_USER vide, on demande
if [[ -z "$REAL_USER" || "$REAL_USER" == "root" ]]; then
    # Lister les utilisateurs humains (UID >= 1000) comme suggestion
    HUMAN_USERS=$(awk -F: '$3 >= 1000 && $3 < 65534 {print $1}' /etc/passwd | tr '\n' ' ')
    if [[ -n "$HUMAN_USERS" ]]; then
        warn "Utilisateurs disponibles sur ce système : $HUMAN_USERS"
    fi
    read -rp "Quel utilisateur ajouter au groupe docker ? (laisser vide pour ignorer) : " REAL_USER
fi

if [[ -n "$REAL_USER" && "$REAL_USER" != "root" ]]; then
    if id "$REAL_USER" &>/dev/null; then
        usermod -aG docker "$REAL_USER"
        log "Utilisateur '$REAL_USER' ajouté au groupe 'docker'."
    else
        error "L'utilisateur '$REAL_USER' n'existe pas sur ce système."
    fi
else
    warn "Aucun utilisateur ajouté au groupe docker. Pour le faire manuellement :"
    warn "  sudo usermod -aG docker <votre_utilisateur>"
fi

# --- Vérification ---
section "Vérification de l'installation"

docker --version && log "Docker Engine installé avec succès !"
docker compose version && log "Docker Compose plugin installé avec succès !"

# Test rapide (lancé en root ici, pas besoin du groupe)
log "Test de Docker avec l'image hello-world..."
docker run --rm hello-world && log "Docker fonctionne correctement !"

echo ""
echo -e "${GREEN}=============================================="
echo -e "  Installation Docker terminée avec succès !"
echo -e "==============================================${NC}"

# --- Rechargement de session sans déco/reco ---
if [[ -n "$REAL_USER" && "$REAL_USER" != "root" ]]; then
    echo ""
    log "Rechargement de votre session pour activer le groupe docker immédiatement..."
    log "Vous pouvez utiliser 'docker' sans sudo dès maintenant !"
    log "(tapez 'exit' pour revenir à votre shell précédent si besoin)"
    echo ""
    exec su - "$REAL_USER"
fi
