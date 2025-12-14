#!/bin/bash

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ID="tuuuur"
REGION="europe-west9"
ENV="stage"
APP_NAME="webplat"
PREFIX="${APP_NAME}-${ENV}"
NETWORK_NAME="${PREFIX}-vpc"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  GCP Ultimate Cleanup Script${NC}"
echo -e "${BLUE}  Project: ${PROJECT_ID}${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Fonction pour logger
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Définir le projet
gcloud config set project ${PROJECT_ID} &>/dev/null

# ============================================
# 1. Supprimer Redis (si existe encore)
# ============================================
log_info "Vérification de Redis..."
REDIS_EXISTS=$(gcloud redis instances list --region=${REGION} --filter="name=${PREFIX}-redis" --format="value(name)" 2>/dev/null)

if [ ! -z "$REDIS_EXISTS" ]; then
    log_info "Suppression de Redis: ${PREFIX}-redis"
    gcloud redis instances delete ${PREFIX}-redis --region=${REGION} --async --quiet 2>/dev/null || log_warn "Erreur lors de la suppression de Redis"
    log_info "Suppression asynchrone de Redis lancée. Attente de 30 secondes..."
    sleep 30
else
    log_info "✓ Redis déjà supprimé"
fi

# ============================================
# 2. Gérer le VPC Network et ses dépendances
# ============================================
log_info "Vérification du réseau VPC..."
NETWORK_EXISTS=$(gcloud compute networks list --filter="name=${NETWORK_NAME}" --format="value(name)" 2>/dev/null)

if [ -z "$NETWORK_EXISTS" ]; then
    log_info "✓ Le réseau VPC n'existe plus"
    exit 0
fi

log_info "Le réseau ${NETWORK_NAME} existe encore. Nettoyage des dépendances..."

# Étape 1: Supprimer tous les peerings (méthode alternative)
log_info "Suppression des peerings via Service Networking API..."
gcloud services vpc-peerings delete \
    --service=servicenetworking.googleapis.com \
    --network=${NETWORK_NAME} \
    --quiet 2>/dev/null && log_info "✓ Peering Service Networking supprimé" || log_warn "Peering déjà supprimé ou erreur"

# Attendre un peu
sleep 5

# Lister et supprimer les peerings restants
PEERINGS=$(gcloud compute networks peerings list --network=${NETWORK_NAME} --format="value(name)" 2>/dev/null)
for peering in $PEERINGS; do
    log_info "Suppression du peering: ${peering}"
    gcloud compute networks peerings delete ${peering} --network=${NETWORK_NAME} --quiet 2>/dev/null || log_warn "Impossible de supprimer ${peering}"
done

sleep 5

# Étape 2: Supprimer les adresses allouées pour Private Service Connection
log_info "Suppression des IP ranges allouées..."
ALLOCATED_RANGES=$(gcloud compute addresses list --global \
    --filter="purpose=VPC_PEERING" \
    --format="value(name)" 2>/dev/null)

for range in $ALLOCATED_RANGES; do
    log_info "Suppression de l'adresse allouée: ${range}"
    gcloud compute addresses delete ${range} --global --quiet 2>/dev/null || log_warn "Impossible de supprimer ${range}"
done

sleep 3

# Étape 3: Supprimer toutes les routes personnalisées
log_info "Suppression des routes..."
ROUTES=$(gcloud compute routes list --filter="network~${NETWORK_NAME}" --format="value(name)" 2>/dev/null)
for route in $ROUTES; do
    # Ignorer les routes par défaut
    if [[ ! "$route" =~ ^default- ]]; then
        log_info "Suppression de la route: ${route}"
        gcloud compute routes delete ${route} --quiet 2>/dev/null || log_warn "Impossible de supprimer ${route}"
    fi
done

sleep 3

# Étape 4: Supprimer toutes les règles de firewall
log_info "Suppression des règles de firewall..."
FIREWALL_RULES=$(gcloud compute firewall-rules list --filter="network~${NETWORK_NAME}" --format="value(name)" 2>/dev/null)
for rule in $FIREWALL_RULES; do
    log_info "Suppression de la règle: ${rule}"
    gcloud compute firewall-rules delete ${rule} --quiet 2>/dev/null || log_warn "Impossible de supprimer ${rule}"
done

sleep 3

# Étape 5: Supprimer tous les subnets
log_info "Suppression des subnets..."
SUBNETS=$(gcloud compute networks subnets list --network=${NETWORK_NAME} --format="csv[no-heading](name,region)" 2>/dev/null)
while IFS=',' read -r subnet_name subnet_region; do
    if [ ! -z "$subnet_name" ]; then
        log_info "Suppression du subnet: ${subnet_name} dans ${subnet_region}"
        gcloud compute networks subnets delete ${subnet_name} --region=${subnet_region} --quiet 2>/dev/null || log_warn "Impossible de supprimer ${subnet_name}"
    fi
done <<< "$SUBNETS"

sleep 5

# Étape 6: Tentative finale de suppression du réseau
log_info "Tentative finale de suppression du réseau VPC..."
if gcloud compute networks delete ${NETWORK_NAME} --quiet 2>&1; then
    log_info "✓ Réseau VPC supprimé avec succès"
else
    log_error "✗ Impossible de supprimer le réseau VPC"
    log_info "Détails du réseau:"
    gcloud compute networks describe ${NETWORK_NAME} 2>/dev/null || true
    
    log_info ""
    log_warn "Actions manuelles possibles:"
    echo "1. Vérifiez les peerings restants:"
    echo "   gcloud compute networks peerings list --network=${NETWORK_NAME}"
    echo ""
    echo "2. Vérifiez dans la console GCP:"
    echo "   https://console.cloud.google.com/networking/networks/details/${NETWORK_NAME}?project=${PROJECT_ID}"
    echo ""
    echo "3. Attendez quelques minutes (les suppressions peuvent prendre du temps) puis réessayez:"
    echo "   ./ultimate-cleanup.sh"
    exit 1
fi

# ============================================
# Nettoyage final
# ============================================
log_info "Recherche d'autres ressources orphelines..."

# Adresses IP globales
GLOBAL_IPS=$(gcloud compute addresses list --global --filter="name~${PREFIX}" --format="value(name)" 2>/dev/null)
for ip in $GLOBAL_IPS; do
    log_info "Suppression de l'adresse IP globale: ${ip}"
    gcloud compute addresses delete ${ip} --global --quiet 2>/dev/null || log_warn "Impossible de supprimer ${ip}"
done

# Adresses IP régionales
REGIONAL_IPS=$(gcloud compute addresses list --regions=${REGION} --filter="name~${PREFIX}" --format="value(name)" 2>/dev/null)
for ip in $REGIONAL_IPS; do
    log_info "Suppression de l'adresse IP régionale: ${ip}"
    gcloud compute addresses delete ${ip} --region=${REGION} --quiet 2>/dev/null || log_warn "Impossible de supprimer ${ip}"
done

echo ""
log_info "========================================="
log_info "✓ Nettoyage terminé !"
log_info "========================================="
echo ""
log_info "Exécutez ./verify-cleanup.sh pour vérifier que tout est bien supprimé."
