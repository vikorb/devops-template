#!/bin/bash
#
# Script pour effectuer des vérifications de sécurité sur le code et l'infrastructure
# Utilise des outils comme Trivy, TFSec, et OWASP Dependency Check

set -e  # Sortir immédiatement en cas d'erreur

# Couleurs pour l'affichage
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

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

# Vérifier les dépendances
check_deps() {
  log "Vérification des dépendances d'outils de sécurité..."
  
  missing_tools=()
  
  if ! command -v trivy &> /dev/null; then
    missing_tools+=("trivy")
  fi
  
  if ! command -v tfsec &> /dev/null; then
    missing_tools+=("tfsec")
  fi
  
  if ! command -v dependency-check &> /dev/null; then
    missing_tools+=("dependency-check")
  fi
  
  if ! command -v bandit &> /dev/null; then
    missing_tools+=("bandit")
  fi
  
  if [ ${#missing_tools[@]} -gt 0 ]; then
    log_warning "Outils manquants : ${missing_tools[*]}"
    log "Installation des outils manquants..."
    
    # Installer les outils manquants
    for tool in "${missing_tools[@]}"; do
      case $tool in
        trivy)
          log "Installation de Trivy..."
          curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin
          ;;
        tfsec)
          log "Installation de TFSec..."
          curl -s https://raw.githubusercontent.com/aquasecurity/tfsec/master/scripts/install_linux.sh | bash
          ;;
        dependency-check)
          log "Installation de OWASP Dependency Check..."
          mkdir -p "$HOME/dependency-check"
          curl -sL https://github.com/jeremylong/DependencyCheck/releases/download/v7.4.0/dependency-check-7.4.0-release.zip -o "$HOME/dependency-check.zip"
          unzip -q "$HOME/dependency-check.zip" -d "$HOME"
          rm "$HOME/dependency-check.zip"
          echo 'export PATH="$HOME/dependency-check/bin:$PATH"' >> ~/.bashrc
          export PATH="$HOME/dependency-check/bin:$PATH"
          ;;
        bandit)
          log "Installation de Bandit..."
          pip install bandit
          ;;
      esac
    done
  else
    log_success "Tous les outils de sécurité sont installés"
  fi
}

# Analyser les vulnérabilités des dépendances
check_dependencies() {
  log "Analyse des vulnérabilités des dépendances..."
  
  # Vérifier les dépendances Node.js
  if [ -f "package.json" ]; then
    log "Analyse des dépendances Node.js..."
    if command -v dependency-check &> /dev/null; then
      dependency-check --scan . --out reports/dependency-check --format "HTML" --failOnCVSS 7
    else
      npm audit --json > reports/npm-audit.json
      log_warning "Rapport NPM Audit généré : reports/npm-audit.json"
    fi
  fi
  
  # Vérifier les dépendances Python
  if [ -f "requirements.txt" ]; then
    log "Analyse des dépendances Python..."
    mkdir -p reports
    pip-audit -r requirements.txt -o json > reports/pip-audit.json
    log_warning "Rapport pip-audit généré : reports/pip-audit.json"
  fi
  
  log_success "Analyse des dépendances terminée"
}

# Analyser le code source
check_source_code() {
  log "Analyse du code source..."
  mkdir -p reports
  
  # Vérifier le code JavaScript/TypeScript
  if ls *.js *.ts 2>/dev/null; then
    log "Analyse du code JavaScript/TypeScript..."
    if command -v eslint &> /dev/null; then
      eslint --ext .js,.ts . -o reports/eslint-report.html -f html || true
    fi
    
    if command -v njsscan &> /dev/null; then
      njsscan . --json -o reports/njsscan-report.json
    fi
  fi
  
  # Vérifier le code Python
  if ls *.py 2>/dev/null || [ -d "app" ]; then
    log "Analyse du code Python..."
    if command -v bandit &> /dev/null; then
      bandit -r . -f json -o reports/bandit-report.json
    fi
  fi
  
  log_success "Analyse du code source terminée"
}

# Vérifier les configurations Terraform
check_terraform() {
  if [ -d "terraform" ]; then
    log "Vérification des configurations Terraform..."
    
    if command -v tfsec &> /dev/null; then
      mkdir -p reports
      tfsec terraform --format json > reports/tfsec-report.json
      
      # Comptage des vulnérabilités
      high_vulns=$(jq '.results | map(select(.severity == "HIGH")) | length' reports/tfsec-report.json)
      critical_vulns=$(jq '.results | map(select(.severity == "CRITICAL")) | length' reports/tfsec-report.json)
      
      if [ "$critical_vulns" -gt 0 ]; then
        log_error "Trouvé $critical_vulns vulnérabilités CRITIQUES dans Terraform"
      elif [ "$high_vulns" -gt 0 ]; then
        log_warning "Trouvé $high_vulns vulnérabilités HAUTES dans Terraform"
      else
        log_success "Aucune vulnérabilité critique dans Terraform"
      fi
    else
      log_warning "tfsec non installé, vérification Terraform ignorée"
    fi
  fi
}

# Analyser les images Docker
check_docker() {
  if [ -d "docker" ]; then
    log "Vérification des images Docker..."
    
    if command -v trivy &> /dev/null; then
      mkdir -p reports
      
      # Trouver les Dockerfiles
      dockerfiles=$(find docker -name "Dockerfile*")
      
      for dockerfile in $dockerfiles; do
        dir=$(dirname "$dockerfile")
        file=$(basename "$dockerfile")
        name=$(echo "$dir/$file" | sed 's/\//_/g')
        
        log "Analyse du Dockerfile : $dockerfile"
        trivy config --format json --output "reports/trivy-${name}.json" "$dockerfile"
      done
      
      # Analyser les images construites
      if [ -n "$(docker images -q)" ]; then
        log "Analyse des images Docker construites..."
        docker_images=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep -v "<none>")
        
        for image in $docker_images; do
          log "Analyse de l'image : $image"
          trivy image --format json --output "reports/trivy-image-$(echo "$image" | sed 's/\//_/g' | sed 's/:/_/g').json" "$image"
        done
      fi
    else
      log_warning "trivy non installé, vérification Docker ignorée"
    fi
  fi
}

# Générer un rapport récapitulatif
generate_summary() {
  log "Génération du rapport récapitulatif..."
  
  report_file="reports/security-summary.md"
  mkdir -p reports
  
  cat > "$report_file" << EOF
# Rapport de sécurité

Date: $(date +"%Y-%m-%d %H:%M:%S")

## Résumé des vulnérabilités

EOF
  
  # Résumé des vulnérabilités de dépendances
  if [ -f "reports/dependency-check-report.html" ]; then
    cat >> "$report_file" << EOF
### Vulnérabilités des dépendances

[Voir le rapport détaillé](dependency-check-report.html)

EOF
  elif [ -f "reports/npm-audit.json" ]; then
    high=$(jq '.vulnerabilities | map(select(.severity == "high")) | length' reports/npm-audit.json)
    critical=$(jq '.vulnerabilities | map(select(.severity == "critical")) | length' reports/npm-audit.json)
    
    cat >> "$report_file" << EOF
### Vulnérabilités des dépendances NPM

* Vulnérabilités critiques: $critical
* Vulnérabilités hautes: $high

[Voir le rapport détaillé](npm-audit.json)

EOF
  fi
  
  # Résumé des vulnérabilités Terraform
  if [ -f "reports/tfsec-report.json" ]; then
    high=$(jq '.results | map(select(.severity == "HIGH")) | length' reports/tfsec-report.json)
    critical=$(jq '.results | map(select(.severity == "CRITICAL")) | length' reports/tfsec-report.json)
    
    cat >> "$report_file" << EOF
### Vulnérabilités Terraform

* Vulnérabilités critiques: $critical
* Vulnérabilités hautes: $high

[Voir le rapport détaillé](tfsec-report.json)

EOF
  fi
  
  # Résumé des vulnérabilités Docker
  trivy_reports=$(find reports -name "trivy-*.json")
  if [ -n "$trivy_reports" ]; then
    cat >> "$report_file" << EOF
### Vulnérabilités Docker

| Fichier | Critiques | Hautes |
|---------|-----------|--------|
EOF
    
    for report in $trivy_reports; do
      name=$(basename "$report" .json)
      high=$(jq '.Results | map(.Vulnerabilities // []) | flatten | map(select(.Severity == "HIGH")) | length' "$report")
      critical=$(jq '.Results | map(.Vulnerabilities // []) | flatten | map(select(.Severity == "CRITICAL")) | length' "$report")
      
      cat >> "$report_file" << EOF
| $name | $critical | $high |
EOF
    done
    
    cat >> "$report_file" << EOF

EOF
  fi
  
  log_success "Rapport récapitulatif généré : $report_file"
}

# Fonction principale
main() {
  log "Démarrage des vérifications de sécurité..."
  
  check_deps
  check_dependencies
  check_source_code
  check_terraform
  check_docker
  generate_summary
  
  log_success "Vérifications de sécurité terminées !"
  log "Les rapports sont disponibles dans le répertoire 'reports/'"
}

# Exécuter la fonction principale
main "$@"