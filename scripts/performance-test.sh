#!/bin/bash
#
# Script de test de performance
# Ce script utilise Apache Benchmark (ab) et/ou JMeter pour exécuter des tests de performance sur une application
#
# Usage:
#   ./performance-test.sh <application_url> [options]
#
# Exemple:
#   ./performance-test.sh https://example.com --concurrency=10 --requests=1000

set -e  # Sortir immédiatement en cas d'erreur

# Couleurs pour l'affichage
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Variables par défaut
URL=""
TEST_TYPE="ab"  # ab ou jmeter
CONCURRENCY=10
REQUESTS=1000
TIMEOUT=30
SKIP_SSL=false
VERBOSE=false
OUTPUT_DIR="./performance-results"
JMETER_TEST_PLAN=""

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
  echo "Script de test de performance"
  echo
  echo "Usage:"
  echo "  $0 <application_url> [options]"
  echo
  echo "Arguments:"
  echo "  application_url     URL de l'application à tester"
  echo
  echo "Options:"
  echo "  --type=TYPE         Type de test: 'ab' pour Apache Benchmark ou 'jmeter' pour JMeter (défaut: ab)"
  echo "  --concurrency=N     Nombre de requêtes simultanées (défaut: 10)"
  echo "  --requests=N        Nombre total de requêtes (défaut: 1000)"
  echo "  --timeout=SEC       Timeout en secondes (défaut: 30)"
  echo "  --skip-ssl          Ignorer la vérification SSL"
  echo "  --verbose           Mode verbeux (affiche plus de détails)"
  echo "  --output-dir=DIR    Répertoire de sortie pour les résultats (défaut: ./performance-results)"
  echo "  --jmeter-plan=FILE  Fichier de plan de test JMeter (requis si --type=jmeter)"
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
      --type=*)
        TEST_TYPE="${1#*=}"
        if [ "$TEST_TYPE" != "ab" ] && [ "$TEST_TYPE" != "jmeter" ]; then
          log_error "Type de test invalide: $TEST_TYPE. Utilisez 'ab' ou 'jmeter'."
          exit 1
        fi
        ;;
      --concurrency=*)
        CONCURRENCY="${1#*=}"
        ;;
      --requests=*)
        REQUESTS="${1#*=}"
        ;;
      --timeout=*)
        TIMEOUT="${1#*=}"
        ;;
      --output-dir=*)
        OUTPUT_DIR="${1#*=}"
        ;;
      --jmeter-plan=*)
        JMETER_TEST_PLAN="${1#*=}"
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
  
  # Vérifier les dépendances
  if [ "$TEST_TYPE" = "ab" ] && ! command -v ab &> /dev/null; then
    log_error "Apache Benchmark (ab) n'est pas installé. Installez-le avec 'apt-get install apache2-utils' sur Debian/Ubuntu."
    exit 1
  fi
  
  if [ "$TEST_TYPE" = "jmeter" ] && [ -z "$JMETER_TEST_PLAN" ]; then
    log_error "Plan de test JMeter requis avec l'option --jmeter-plan"
    exit 1
  fi
  
  # Créer le répertoire de sortie s'il n'existe pas
  mkdir -p "$OUTPUT_DIR"
}

# Exécuter un test avec Apache Benchmark
run_ab_test() {
  local timestamp=$(date +"%Y%m%d-%H%M%S")
  local output_file="$OUTPUT_DIR/ab-test-$timestamp.txt"
  local gnuplot_file="$OUTPUT_DIR/ab-test-$timestamp.png"
  
  log "Démarrage du test Apache Benchmark avec $CONCURRENCY connexions simultanées et $REQUESTS requêtes..."
  
  local ab_args="-c $CONCURRENCY -n $REQUESTS -t $TIMEOUT"
  
  if [ "$SKIP_SSL" = true ]; then
    ab_args="$ab_args -k"
  fi
  
  if [ "$VERBOSE" = true ]; then
    ab_args="$ab_args -v 2"
  else
    ab_args="$ab_args -v 0"
  fi
  
  # Ajouter l'option pour générer un graphique
  ab_args="$ab_args -g $output_file.tsv"
  
  # Exécuter le test
  ab $ab_args "$URL" > "$output_file" 2>&1
  
  if [ $? -eq 0 ]; then
    log_success "Test Apache Benchmark terminé avec succès"
    
    # Extraire et afficher les résultats clés
    local rps=$(grep "Requests per second" "$output_file" | awk '{print $4}')
    local mean_time=$(grep "Time per request" "$output_file" | head -1 | awk '{print $4}')
    local percentile_90=$(grep "90%" "$output_file" | awk '{print $2}')
    local percentile_99=$(grep "99%" "$output_file" | awk '{print $2}')
    local failed=$(grep "Failed requests" "$output_file" | awk '{print $3}')
    
    echo "==================================================================="
    echo "RÉSULTATS DU TEST DE PERFORMANCE:"
    echo "-------------------------------------------------------------------"
    echo "URL testée:                 $URL"
    echo "Requêtes par seconde:       $rps"
    echo "Temps moyen par requête:    $mean_time ms"
    echo "Temps de réponse à 90%:     $percentile_90 ms"
    echo "Temps de réponse à 99%:     $percentile_99 ms"
    echo "Requêtes échouées:          $failed"
    echo "-------------------------------------------------------------------"
    echo "Rapport complet disponible: $output_file"
    echo "==================================================================="
    
    # Générer un graphique avec gnuplot si disponible
    if command -v gnuplot &> /dev/null; then
      generate_gnuplot "$output_file.tsv" "$gnuplot_file"
      echo "Graphique disponible:         $gnuplot_file"
      echo "==================================================================="
    fi
    
    return 0
  else
    log_error "Test Apache Benchmark échoué"
    cat "$output_file"
    return 1
  fi
}

# Générer un graphique avec gnuplot
generate_gnuplot() {
  local data_file=$1
  local output_file=$2
  
  # Créer un script gnuplot temporaire
  local gnuplot_script=$(mktemp)
  
  cat > "$gnuplot_script" << EOF
set terminal png size 1000,600
set output "$output_file"
set title "Performance Test Results"
set grid
set xlabel "Request Number"
set ylabel "Response Time (ms)"
plot "$data_file" using 5 with lines title "Response Time", \
     "$data_file" using 5 smooth bezier with lines title "Trend" lw 2
EOF
  
  # Exécuter gnuplot
  gnuplot "$gnuplot_script"
  
  # Supprimer le script temporaire
  rm "$gnuplot_script"
}

# Exécuter un test avec JMeter
run_jmeter_test() {
  local timestamp=$(date +"%Y%m%d-%H%M%S")
  local output_file="$OUTPUT_DIR/jmeter-test-$timestamp"
  
  log "Démarrage du test JMeter avec le plan $JMETER_TEST_PLAN..."
  
  local jmeter_args="-n -t $JMETER_TEST_PLAN -l $output_file.jtl -e -o $output_file-report"
  
  # Ajouter des propriétés JMeter
  jmeter_args="$jmeter_args -Jhost=$(echo $URL | sed -e 's|^[^/]*//||' -e 's|/.*$||')"
  jmeter_args="$jmeter_args -Jprotocol=$(echo $URL | cut -d: -f1)"
  jmeter_args="$jmeter_args -Jthreads=$CONCURRENCY"
  jmeter_args="$jmeter_args -Jloops=$((REQUESTS / CONCURRENCY))"
  
  if [ "$SKIP_SSL" = true ]; then
    jmeter_args="$jmeter_args -Jssl.disable=true"
  fi
  
  # Exécuter le test
  jmeter $jmeter_args > "$output_file.log" 2>&1
  
  if [ $? -eq 0 ]; then
    log_success "Test JMeter terminé avec succès"
    echo "==================================================================="
    echo "RÉSULTATS DU TEST DE PERFORMANCE JMETER:"
    echo "-------------------------------------------------------------------"
    echo "URL testée:                 $URL"
    echo "Plan de test:               $JMETER_TEST_PLAN"
    echo "Nombre de threads:          $CONCURRENCY"
    echo "Nombre de boucles:          $((REQUESTS / CONCURRENCY))"
    echo "-------------------------------------------------------------------"
    echo "Rapport HTML disponible:    $output_file-report/index.html"
    echo "Fichier de résultats:       $output_file.jtl"
    echo "==================================================================="
    return 0
  else
    log_error "Test JMeter échoué"
    cat "$output_file.log"
    return 1
  fi
}

# Fonction principale
main() {
  parse_args "$@"
  
  log "Configuration du test de performance:"
  log "  URL:         $URL"
  log "  Type:        $TEST_TYPE"
  log "  Concurrence: $CONCURRENCY"
  log "  Requêtes:    $REQUESTS"
  
  if [ "$TEST_TYPE" = "ab" ]; then
    run_ab_test
  elif [ "$TEST_TYPE" = "jmeter" ]; then
    run_jmeter_test
  fi
}

main "$@"