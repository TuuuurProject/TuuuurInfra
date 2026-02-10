#!/bin/bash

# ============================================
# Script complet de destruction Terraform + nettoyage GCP
# ============================================

set -e

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ID="tuuuur"
REGION="europe-west9"
ENV="preprod"
APP_NAME="webplat"
PREFIX="${APP_NAME}-${ENV}"
NETWORK_NAME="${PREFIX}-vpc"
BASTION_ZONE="europe-west9"

# Compteurs pour la vérification
TOTAL_CHECKS=0
RESOURCES_FOUND=0

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  Destruction Complète Infrastructure${NC}"
echo -e "${CYAN}  Project: ${PROJECT_ID}${NC}"
echo -e "${CYAN}  Environment: ${ENV}${NC}"
echo -e "${CYAN}========================================${NC}"
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

log_step() {
    echo ""
    echo -e "${BLUE}>>> $1${NC}"
    echo ""
}

# Vérifier que gcloud est installé
if ! command -v gcloud &> /dev/null; then
    log_error "gcloud CLI n'est pas installé."
    exit 1
fi

# Définir le projet
gcloud config set project ${PROJECT_ID} &>/dev/null

# ============================================
# PHASE 1: TERRAFORM DESTROY PRÉ-NETTOYAGE
# ============================================
log_step "PHASE 1: Pré-nettoyage pour Terraform Destroy"

log_info "Vérification des peerings VPC..."
PEERINGS=$(gcloud compute networks peerings list --network=$NETWORK_NAME --project=$PROJECT_ID --format="value(name)" 2>/dev/null || echo "")

if [ -n "$PEERINGS" ]; then
    log_info "Peerings VPC trouvés, suppression en cours..."
    echo "$PEERINGS" | while read -r peering; do
        if [ -n "$peering" ]; then
            log_info "  └─ Suppression: $peering"
            gcloud compute networks peerings delete "$peering" \
                --network=$NETWORK_NAME \
                --project=$PROJECT_ID \
                --quiet 2>/dev/null || log_warn "Déjà supprimé: $peering"
        fi
    done
    log_info "Attente de 5 secondes pour la propagation..."
    sleep 5
else
    log_info "✓ Aucun peering VPC à supprimer"
fi

log_info "Retrait de la Service Networking Connection du state Terraform..."
terraform state rm 'module.network.google_service_networking_connection.psa_connection[0]' 2>/dev/null && \
    log_info "✓ Ressource retirée du state" || \
    log_info "ℹ️  Ressource déjà absente du state"

log_info "Suppression de la connexion Service Networking..."
gcloud services vpc-peerings delete \
    --service=servicenetworking.googleapis.com \
    --network=$NETWORK_NAME \
    --project=$PROJECT_ID \
    --quiet 2>/dev/null && log_info "✓ Service Networking Connection supprimée" || log_info "ℹ️  Déjà supprimée"

sleep 3

# ============================================
# PHASE 2: TERRAFORM DESTROY
# ============================================
log_step "PHASE 2: Exécution de Terraform Destroy"

if terraform destroy "$@"; then
    log_info "✓ Terraform destroy réussi"
else
    log_error "✗ Terraform destroy a échoué"
    log_warn "Passage au nettoyage manuel des ressources restantes..."
fi

# ============================================
# PHASE 3: NETTOYAGE MANUEL DES RESSOURCES RESTANTES
# ============================================
log_step "PHASE 3: Nettoyage des ressources restantes"

# 3.1 - Cloud Run Services
log_info "Nettoyage des Cloud Run services..."
SERVICES=$(gcloud run services list --region=${REGION} --filter="metadata.name~${PREFIX}" --format="value(metadata.name)" 2>/dev/null || echo "")
for service in $SERVICES; do
    if [ -n "$service" ]; then
        log_info "  └─ Suppression: $service"
        gcloud run services delete $service --region=${REGION} --quiet 2>/dev/null || true
    fi
done

# 3.2 - Cloud Run Jobs
log_info "Nettoyage des Cloud Run jobs..."
JOBS=$(gcloud run jobs list --region=${REGION} --filter="metadata.name~${PREFIX}" --format="value(metadata.name)" 2>/dev/null || echo "")
for job in $JOBS; do
    if [ -n "$job" ]; then
        log_info "  └─ Suppression: $job"
        gcloud run jobs delete $job --region=${REGION} --quiet 2>/dev/null || true
    fi
done

# 3.3 - Load Balancer Components
log_info "Nettoyage des composants Load Balancer..."

# Forwarding Rules
FORWARDING_RULES=$(gcloud compute forwarding-rules list --global --filter="name~${PREFIX}" --format="value(name)" 2>/dev/null || echo "")
for rule in $FORWARDING_RULES; do
    if [ -n "$rule" ]; then
        log_info "  └─ Forwarding rule: $rule"
        gcloud compute forwarding-rules delete $rule --global --quiet 2>/dev/null || true
    fi
done

# Target Proxies
TARGET_PROXIES=$(gcloud compute target-https-proxies list --filter="name~${PREFIX}" --format="value(name)" 2>/dev/null || echo "")
for proxy in $TARGET_PROXIES; do
    if [ -n "$proxy" ]; then
        log_info "  └─ HTTPS proxy: $proxy"
        gcloud compute target-https-proxies delete $proxy --quiet 2>/dev/null || true
    fi
done

TARGET_HTTP_PROXIES=$(gcloud compute target-http-proxies list --filter="name~${PREFIX}" --format="value(name)" 2>/dev/null || echo "")
for proxy in $TARGET_HTTP_PROXIES; do
    if [ -n "$proxy" ]; then
        log_info "  └─ HTTP proxy: $proxy"
        gcloud compute target-http-proxies delete $proxy --quiet 2>/dev/null || true
    fi
done

# URL Maps
URL_MAPS=$(gcloud compute url-maps list --filter="name~${PREFIX}" --format="value(name)" 2>/dev/null || echo "")
for map in $URL_MAPS; do
    if [ -n "$map" ]; then
        log_info "  └─ URL map: $map"
        gcloud compute url-maps delete $map --quiet 2>/dev/null || true
    fi
done

# Backend Services
BACKEND_SERVICES=$(gcloud compute backend-services list --global --filter="name~${PREFIX}" --format="value(name)" 2>/dev/null || echo "")
for backend in $BACKEND_SERVICES; do
    if [ -n "$backend" ]; then
        log_info "  └─ Backend service: $backend"
        gcloud compute backend-services delete $backend --global --quiet 2>/dev/null || true
    fi
done

# Network Endpoint Groups
NEGS=$(gcloud compute network-endpoint-groups list --filter="name~${PREFIX}" --format="csv[no-heading](name,location)" 2>/dev/null || echo "")
while IFS=',' read -r neg_name neg_location; do
    if [ -n "$neg_name" ]; then
        log_info "  └─ NEG: $neg_name in $neg_location"
        if [[ "$neg_location" == *"/"* ]]; then
            # Zone-based NEG
            gcloud compute network-endpoint-groups delete $neg_name --zone=${neg_location##*/} --quiet 2>/dev/null || true
        else
            # Region-based NEG
            gcloud compute network-endpoint-groups delete $neg_name --region=$neg_location --quiet 2>/dev/null || true
        fi
    fi
done <<< "$NEGS"

# SSL Certificates
SSL_CERTS=$(gcloud compute ssl-certificates list --filter="name~${PREFIX}" --format="value(name)" 2>/dev/null || echo "")
for cert in $SSL_CERTS; do
    if [ -n "$cert" ]; then
        log_info "  └─ SSL cert: $cert"
        gcloud compute ssl-certificates delete $cert --quiet 2>/dev/null || true
    fi
done

# 3.4 - Cloud SQL
log_info "Nettoyage de Cloud SQL..."
SQL_INSTANCES=$(gcloud sql instances list --filter="name~${PREFIX}" --format="value(name)" 2>/dev/null || echo "")
for instance in $SQL_INSTANCES; do
    if [ -n "$instance" ]; then
        log_info "  └─ Cloud SQL: $instance"
        gcloud sql instances delete $instance --quiet 2>/dev/null || true
    fi
done

# 3.5 - Redis
log_info "Nettoyage de Redis..."
REDIS_INSTANCES=$(gcloud redis instances list --region=${REGION} --filter="name~${PREFIX}" --format="value(name)" 2>/dev/null || echo "")
for redis in $REDIS_INSTANCES; do
    if [ -n "$redis" ]; then
        log_info "  └─ Redis: $redis"
        gcloud redis instances delete $redis --region=${REGION} --quiet --async 2>/dev/null || true
    fi
done

if [ -n "$REDIS_INSTANCES" ]; then
    log_info "Attente de 30 secondes pour la suppression asynchrone de Redis..."
    sleep 30
fi

# 3.6 - VPC Connector
log_info "Nettoyage des VPC Connectors..."
VPC_CONNECTORS=$(gcloud compute networks vpc-access connectors list --region=${REGION} --filter="name~${PREFIX}" --format="value(name)" 2>/dev/null || echo "")
for connector in $VPC_CONNECTORS; do
    if [ -n "$connector" ]; then
        log_info "  └─ VPC Connector: $connector"
        gcloud compute networks vpc-access connectors delete $connector --region=${REGION} --quiet 2>/dev/null || true
    fi
done

# 3.7 - Compute Engine (Bastion)
log_info "Nettoyage des VMs Compute Engine..."
INSTANCES=$(gcloud compute instances list --filter="name~${PREFIX}" --format="csv[no-heading](name,zone)" 2>/dev/null || echo "")
while IFS=',' read -r instance_name instance_zone; do
    if [ -n "$instance_name" ]; then
        log_info "  └─ VM: $instance_name in $instance_zone"
        gcloud compute instances delete $instance_name --zone=$instance_zone --quiet 2>/dev/null || true
    fi
done <<< "$INSTANCES"

# 3.8 - Disques persistants
log_info "Nettoyage des disques persistants..."
DISKS=$(gcloud compute disks list --filter="name~${PREFIX}" --format="csv[no-heading](name,zone)" 2>/dev/null || echo "")
while IFS=',' read -r disk_name disk_zone; do
    if [ -n "$disk_name" ]; then
        log_info "  └─ Disk: $disk_name in $disk_zone"
        gcloud compute disks delete $disk_name --zone=$disk_zone --quiet 2>/dev/null || true
    fi
done <<< "$DISKS"

# 3.9 - Firewall Rules
log_info "Nettoyage des règles de firewall..."
FIREWALL_RULES=$(gcloud compute firewall-rules list --filter="network~${NETWORK_NAME}" --format="value(name)" 2>/dev/null || echo "")
for rule in $FIREWALL_RULES; do
    if [ -n "$rule" ]; then
        log_info "  └─ Firewall rule: $rule"
        gcloud compute firewall-rules delete $rule --quiet 2>/dev/null || true
    fi
done

# 3.10 - Routes personnalisées
log_info "Nettoyage des routes..."
ROUTES=$(gcloud compute routes list --filter="network~${NETWORK_NAME}" --format="value(name)" 2>/dev/null || echo "")
for route in $ROUTES; do
    if [[ ! "$route" =~ ^default- ]] && [ -n "$route" ]; then
        log_info "  └─ Route: $route"
        gcloud compute routes delete $route --quiet 2>/dev/null || true
    fi
done

# 3.11 - Subnets
log_info "Nettoyage des subnets..."
SUBNETS=$(gcloud compute networks subnets list --network=${NETWORK_NAME} --format="csv[no-heading](name,region)" 2>/dev/null || echo "")
while IFS=',' read -r subnet_name subnet_region; do
    if [ -n "$subnet_name" ]; then
        log_info "  └─ Subnet: $subnet_name in $subnet_region"
        gcloud compute networks subnets delete $subnet_name --region=$subnet_region --quiet 2>/dev/null || true
    fi
done <<< "$SUBNETS"

sleep 5

# 3.12 - Adresses IP réservées
log_info "Nettoyage des adresses IP..."

# Globales
GLOBAL_IPS=$(gcloud compute addresses list --global --filter="name~${PREFIX}" --format="value(name)" 2>/dev/null || echo "")
for ip in $GLOBAL_IPS; do
    if [ -n "$ip" ]; then
        log_info "  └─ Global IP: $ip"
        gcloud compute addresses delete $ip --global --quiet 2>/dev/null || true
    fi
done

# Régionales
REGIONAL_IPS=$(gcloud compute addresses list --filter="name~${PREFIX}" --format="csv[no-heading](name,region)" 2>/dev/null || echo "")
while IFS=',' read -r ip_name ip_region; do
    if [ -n "$ip_name" ]; then
        log_info "  └─ Regional IP: $ip_name in $ip_region"
        gcloud compute addresses delete $ip_name --region=$ip_region --quiet 2>/dev/null || true
    fi
done <<< "$REGIONAL_IPS"

# 3.13 - VPC Network
log_info "Suppression du réseau VPC..."
NETWORK_EXISTS=$(gcloud compute networks list --filter="name=${NETWORK_NAME}" --format="value(name)" 2>/dev/null || echo "")
if [ -n "$NETWORK_EXISTS" ]; then
    gcloud compute networks delete ${NETWORK_NAME} --quiet 2>/dev/null && \
        log_info "✓ VPC Network supprimé" || \
        log_warn "Impossible de supprimer le VPC (peut nécessiter quelques minutes)"
fi

# 3.14 - Secrets
log_info "Nettoyage des secrets..."
SECRETS=$(gcloud secrets list --filter="name~${PREFIX}" --format="value(name)" 2>/dev/null || echo "")
for secret in $SECRETS; do
    if [ -n "$secret" ]; then
        log_info "  └─ Secret: $secret"
        gcloud secrets delete $secret --quiet 2>/dev/null || true
    fi
done

# 3.15 - Service Accounts
log_info "Nettoyage des service accounts..."
SERVICE_ACCOUNTS=$(gcloud iam service-accounts list --filter="email~${PREFIX}" --format="value(email)" 2>/dev/null || echo "")
for sa in $SERVICE_ACCOUNTS; do
    if [ -n "$sa" ]; then
        log_info "  └─ Service Account: $sa"
        gcloud iam service-accounts delete $sa --quiet 2>/dev/null || true
    fi
done

# ============================================
# PHASE 4: VÉRIFICATION FINALE
# ============================================
log_step "PHASE 4: Vérification finale"

check_resource() {
    local description=$1
    local command=$2
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    local result=$(eval "$command" 2>/dev/null || echo "")
    
    if [ -z "$result" ]; then
        echo -e "  ${GREEN}✓${NC} $description"
        return 0
    else
        echo -e "  ${RED}✗${NC} $description"
        RESOURCES_FOUND=$((RESOURCES_FOUND + 1))
        return 1
    fi
}

echo "Vérification des ressources restantes..."
echo ""

check_resource "Cloud Run Services" \
    "gcloud run services list --region=${REGION} --filter='metadata.name~${PREFIX}' --format='value(metadata.name)'"

check_resource "Cloud Run Jobs" \
    "gcloud run jobs list --region=${REGION} --filter='metadata.name~${PREFIX}' --format='value(metadata.name)'"

check_resource "Load Balancer Forwarding Rules" \
    "gcloud compute forwarding-rules list --global --filter='name~${PREFIX}' --format='value(name)'"

check_resource "SSL Certificates" \
    "gcloud compute ssl-certificates list --filter='name~${PREFIX}' --format='value(name)'"

check_resource "Cloud SQL Instances" \
    "gcloud sql instances list --filter='name~${PREFIX}' --format='value(name)'"

check_resource "Redis Instances" \
    "gcloud redis instances list --region=${REGION} --filter='name~${PREFIX}' --format='value(name)'"

check_resource "VPC Connectors" \
    "gcloud compute networks vpc-access connectors list --region=${REGION} --filter='name~${PREFIX}' --format='value(name)'"

check_resource "Compute Instances" \
    "gcloud compute instances list --filter='name~${PREFIX}' --format='value(name)'"

check_resource "Firewall Rules" \
    "gcloud compute firewall-rules list --filter='name~${PREFIX}' --format='value(name)'"

check_resource "VPC Networks" \
    "gcloud compute networks list --filter='name~${PREFIX}' --format='value(name)'"

check_resource "Secrets" \
    "gcloud secrets list --filter='name~${PREFIX}' --format='value(name)'"

check_resource "Service Accounts" \
    "gcloud iam service-accounts list --filter='email~${PREFIX}' --format='value(email)'"

# ============================================
# RÉSUMÉ FINAL
# ============================================
echo ""
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  Résumé de la Destruction${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

if [ $RESOURCES_FOUND -eq 0 ]; then
    echo -e "${GREEN}✓✓✓ SUCCÈS COMPLET ✓✓✓${NC}"
    echo ""
    echo -e "${GREEN}Toutes les ${TOTAL_CHECKS} vérifications ont réussi !${NC}"
    echo -e "${GREEN}L'infrastructure a été complètement détruite.${NC}"
    echo ""
    exit 0
else
    echo -e "${YELLOW}⚠ DESTRUCTION PARTIELLE ⚠${NC}"
    echo ""
    echo -e "${YELLOW}${RESOURCES_FOUND}/${TOTAL_CHECKS} types de ressources restent présents${NC}"
    echo ""
    log_warn "Quelques ressources n'ont pas pu être supprimées."
    log_info "Raisons possibles:"
    echo "  - Délai de propagation (réessayez dans quelques minutes)"
    echo "  - Dépendances externes"
    echo "  - Permissions insuffisantes"
    echo ""
    log_info "Actions suggérées:"
    echo "  1. Attendez 5 minutes et réexécutez ce script"
    echo "  2. Consultez la console GCP:"
    echo "     https://console.cloud.google.com/home/dashboard?project=${PROJECT_ID}"
    echo "  3. Supprimez manuellement les ressources restantes"
    echo ""
    exit 1
fi
