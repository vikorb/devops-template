#!/bin/bash
#
# Script de vérification post-déploiement
# Ce script effectue une série de tests pour vérifier qu'un déploiement s'est correctement déroulé
#
# Usage:
#   ./deploy-verify.sh <application_url> [options]
#
# Exemple:
#   ./deploy-verify.sh https://example.com --health-path=/health --skip-ssl

set -e  # Sortir immédiatement en cas d'erreur

# Couleurs pour l'affichage
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Variables par défaut
HEALTH_PATH="/health"
TIMEOUT=60
SKIP_SSL=false
VERBOSE=false
MAX_RETRY=5
RETRY_INTERVAL=10

# Fonction pour afficher les messages
log() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Afficher le message d'aide
show_help() {
  echo "Script de vérification post-déploiement"
  echo
  echo "Usage:"
  echo "  $0 <application_url> [options]"
  echo
  echo "Arguments:"
  echo "  application_url     URL de l'application à vérifier"
  echo
  echo "Options:"
  echo "  --health-path=PATH  Chemin de l'endpoint de santé (défaut: /health)"
  echo "  --timeout=SEC       Timeout en secondes (défaut: 60)"
  echo "  --skip-ssl          Ignorer la vérification SSL"
  echo "  --verbose           Mode verbeux (affiche plus de détails)"
  echo "  --max-retry=N       Nombre maximal de tentatives (défaut: 5)"
  echo "  --retry-interval=SEC Intervalle entre les tentatives en secondes (défaut: 10)"
  echo "  -h, --help          Affiche ce message d'aide"
}

# Parser les arguments
parse_args() {
  URL=$1
  shift
  
  if [ -z "$URL" ]; then
    log_error "URL de l'application manquante"
    show_help
    exit 1
  fi
  
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --health-path=*)
        HEALTH_PATH="${1#*=}"
        ;;
      --timeout=*)
        TIMEOUT="${1#*=}"
        ;;
      --max-retry=*)
        MAX_RETRY="${1#*=}"
        ;;
      --retry-interval=*)
        RETRY_INTERVAL="${1#*=}"
        ;;
      --skip-ssl)
        SKIP_SSL=true
        ;;
      --verbose)
        VERBOSE=true
        ;;
      -h|--help)
        show_help
        exit 0
        ;;
      *)
        log_error "Option inconnue: $1"
        show_help
        exit 1
        ;;
    esac
    shift
  done
}

# Vérifier l'état de santé de l'application
check_health() {
  log "Vérification de l'état de santé à $URL$HEALTH_PATH"
  
  local curl_args="-s -o /dev/null -w \"%{http_code}\" --max-time $TIMEOUT"
  if [ "$SKIP_SSL" = true ]; then
    curl_args="$curl_args -k"
  fi
  if [ "$VERBOSE" = true ]; then
    curl_args="-v $curl_args"
  fi
  
  local retry=0
  local status
  
  while [ $retry -lt $MAX_RETRY ]; do
    log "Tentative $((retry+1))/$MAX_RETRY..."
    
    status=$(eval "curl $curl_args $URL$HEALTH_PATH")
    
    if [ "$status" = "200" ] || [ "$status" = "204" ]; then
      log_success "Endpoint de santé OK (statut: $status)"
      return 0
    else
      log_warning "Endpoint de santé non disponible (statut: $status)"
      retry=$((retry+1))
      
      if [ $retry -lt $MAX_RETRY ]; then
        log "Nouvel essai dans $RETRY_INTERVAL secondes..."
        sleep $RETRY_INTERVAL
      fi
    fi
  done
  
  log_error "L'endpoint de santé n'est pas disponible après $MAX_RETRY tentatives"
  return 1
}

# Vérifier le certificat SSL
check_ssl() {
  if [ "$SKIP_SSL" = true ]; then
    log "Vérification SSL ignorée"
    return 0
  fi
  
  log "Vérification du certificat SSL pour $URL"
  
  local domain=$(echo "$URL" | sed -e 's|^[^/]*//||' -e 's|/.*$||')
  local port=443
  
  if echo "$domain" | grep -q ":"; then
    port=$(echo "$domain" | cut -d: -f2)
    domain=$(echo "$domain" | cut -d: -f1)
  fi
  
  local expiry_date=$(echo | openssl s_client -servername "$domain" -connect "$domain:$port" 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null | sed -e 's/notAfter=//')
  
  if [ -z "$expiry_date" ]; then
    log_error "Impossible de récupérer les informations du certificat SSL"
    return 1
  fi
  
  local expiry_epoch=$(date -d "$expiry_date" +%s)
  local current_epoch=$(date +%s)
  local days_left=$(( (expiry_epoch - current_epoch) / 86400 ))
  
  if [ $days_left -lt 0 ]; then
    log_error "Le certificat SSL a expiré il y a $((days_left * -1)) jours"
    return 1
  elif [ $days_left -lt 30 ]; then
    log_warning "Le certificat SSL expire dans $days_left jours"
  else
    log_success "Certificat SSL valide (expire dans $days_left jours)"
  fi
  
  return 0
}

# Vérifier les ressources principales
check_resources() {
  log "Vérification des ressources principales..."
  
  local resources=(
    "/"
    "/css/main.css"
    "/js/main.js"
  )
  
  local failures=0
  
  for resource in "${resources[@]}"; do
    local curl_args="-s -o /dev/null -w \"%{http_code}\" --max-time $TIMEOUT"
    if [ "$SKIP_SSL" = true ]; then
      curl_args="$curl_args -k"
    fi
    
    local status=$(eval "curl $curl_args $URL$resource")
    
    if [ "$status" = "200" ]; then
      log_success "Ressource $resource OK (statut: $status)"
    else
      log_warning "Ressource $resource non disponible (statut: $status)"
      failures=$((failures+1))
    fi
  done
  
  if [ $failures -gt 0 ]; then
    log_warning "$failures ressources non disponibles"
    return 1
  else
    log_success "Toutes les ressources sont disponibles"
    return 0
  fi
}

# Vérifier les en-têtes de sécurité
check_security_headers() {
  log "Vérification des en-têtes de sécurité..."
  
  local curl_args="-s -I --max-time $TIMEOUT"
  if [ "$SKIP_SSL" = true ]; then
    curl_args="$curl_args -k"
  fi
  
  local headers=$(eval "curl $curl_args $URL")
  local failures=0
  
  # Liste des en-têtes de sécurité à vérifier
  local security_headers=(
    "Strict-Transport-Security"
    "X-Content-Type-Options"
    "X-Frame-Options"
    "Content-Security-Policy"
    "X-XSS-Protection"
  )
  
  for header in "${security_headers[@]}"; do
    if echo "$headers" | grep -q "$header"; then
      log_success "En-tête $header présent"
    else
      log_warning "En-tête $header manquant"
      failures=$((failures+1))
    fi
  done
  
  if [ $failures -gt 0 ]; then
    log_warning "$failures en-têtes de sécurité manquants"
  else
    log_success "Tous les en-têtes de sécurité sont présents"
  fi
  
  return 0
}

# Exporter les résultats au format JSON
export_results() {
  local result=$1
  local output_file="deploy-verify-$(date +%Y%m%d-%H%M%S).json"
  
  cat > "$output_file" << EOF
{
  "url": "$URL",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "success": $result,
  "checks": [
    {
      "name": "health",
      "status": $HEALTH_CHECK_RESULT
    },
    {
      "name": "ssl",
      "status": $SSL_CHECK_RESULT
    },
    {
      "name": "resources",
      "status": $RESOURCES_CHECK_RESULT
    },
    {
      "name": "security_headers",
      "status": $HEADERS_CHECK_RESULT
    }
  ]
}
EOF
  
  log "Résultats exportés dans $output_file"
}

# Fonction principale
main() {
  parse_args "$@"
  
  log "Démarrage de la vérification pour $URL"
  
  # Exécuter les vérifications
  check_health
  HEALTH_CHECK_RESULT=$?
  
  check_ssl
  SSL_CHECK_RESULT=$?
  
  check_resources
  RESOURCES_CHECK_RESULT=$?
  
  check_security_headers
  HEADERS_CHECK_RESULT=$?
  
  # Déterminer le résultat global
  if [ $HEALTH_CHECK_RESULT -eq 0 ] && [ $SSL_CHECK_RESULT -eq 0 ] && [ $RESOURCES_CHECK_RESULT -eq 0 ]; then
    log_success "Vérification du déploiement réussie"
    export_results true
    exit 0
  else
    log_error "Vérification du déploiement échouée"
    export_results false
    exit 1
  fi
}

main "$@"