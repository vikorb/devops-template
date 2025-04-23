#!/bin/bash
#
# Script de sauvegarde et restauration de base de données
# Supporte PostgreSQL et MySQL/MariaDB
#
# Usage:
#   ./db-backup.sh backup <env> [options]
#   ./db-backup.sh restore <backup_file> <env> [options]
#
# Exemple:
#   ./db-backup.sh backup prod
#   ./db-backup.sh restore backup-prod-2023-04-23.sql.gz dev

set -e  # Sortir immédiatement en cas d'erreur

# Couleurs pour l'affichage
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Chemin pour les sauvegardes
BACKUP_DIR="./backups"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")

# Charger les configurations d'environnement
load_env() {
  local env=$1
  ENV_FILE=".env.$env"
  
  if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}[ERROR]${NC} Fichier d'environnement $ENV_FILE introuvable"
    exit 1
  fi
  
  source "$ENV_FILE"
  
  # Valider que les variables nécessaires existent
  if [ -z "$DB_TYPE" ] || [ -z "$DB_HOST" ] || [ -z "$DB_PORT" ] || [ -z "$DB_NAME" ] || [ -z "$DB_USER" ] || [ -z "$DB_PASSWORD" ]; then
    echo -e "${RED}[ERROR]${NC} Configuration de base de données incomplète dans $ENV_FILE"
    echo "Assurez-vous que DB_TYPE, DB_HOST, DB_PORT, DB_NAME, DB_USER et DB_PASSWORD sont définis"
    exit 1
  fi
}

# Créer le répertoire de sauvegarde s'il n'existe pas
check_backup_dir() {
  if [ ! -d "$BACKUP_DIR" ]; then
    mkdir -p "$BACKUP_DIR"
    echo -e "${BLUE}[INFO]${NC} Répertoire de sauvegarde créé: $BACKUP_DIR"
  fi
}

# Fonction de sauvegarde
backup_database() {
  local env=$1
  load_env "$env"
  check_backup_dir
  
  BACKUP_FILE="${BACKUP_DIR}/backup-${env}-${DB_NAME}-${TIMESTAMP}.sql.gz"
  
  echo -e "${BLUE}[INFO]${NC} Sauvegarde de la base de données $DB_NAME ($env) en cours..."
  
  if [ "$DB_TYPE" = "postgres" ] || [ "$DB_TYPE" = "postgresql" ]; then
    PGPASSWORD="$DB_PASSWORD" pg_dump -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -F p | gzip > "$BACKUP_FILE"
  elif [ "$DB_TYPE" = "mysql" ] || [ "$DB_TYPE" = "mariadb" ]; then
    mysqldump -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" | gzip > "$BACKUP_FILE"
  else
    echo -e "${RED}[ERROR]${NC} Type de base de données non supporté: $DB_TYPE"
    echo "Types supportés: postgres, postgresql, mysql, mariadb"
    exit 1
  fi
  
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}[SUCCESS]${NC} Sauvegarde terminée: $BACKUP_FILE"
  else
    echo -e "${RED}[ERROR]${NC} Échec de la sauvegarde"
    exit 1
  fi
}

# Fonction de restauration
restore_database() {
  local backup_file=$1
  local env=$2
  
  if [ ! -f "$backup_file" ]; then
    echo -e "${RED}[ERROR]${NC} Fichier de sauvegarde introuvable: $backup_file"
    exit 1
  fi
  
  load_env "$env"
  
  echo -e "${BLUE}[INFO]${NC} Restauration de la base de données $DB_NAME ($env) en cours..."
  
  # Demander confirmation avant de restaurer
  read -p "Cela va écraser la base de données existante. Êtes-vous sûr? (y/n) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}[WARNING]${NC} Restauration annulée par l'utilisateur"
    exit 0
  fi
  
  if [ "$DB_TYPE" = "postgres" ] || [ "$DB_TYPE" = "postgresql" ]; then
    # Recréer la base de données
    PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -c "DROP DATABASE IF EXISTS $DB_NAME;"
    PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -c "CREATE DATABASE $DB_NAME;"
    
    # Restaurer les données
    gunzip -c "$backup_file" | PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME"
  elif [ "$DB_TYPE" = "mysql" ] || [ "$DB_TYPE" = "mariadb" ]; then
    # Recréer la base de données
    mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASSWORD" -e "DROP DATABASE IF EXISTS $DB_NAME; CREATE DATABASE $DB_NAME;"
    
    # Restaurer les données
    gunzip -c "$backup_file" | mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME"
  else
    echo -e "${RED}[ERROR]${NC} Type de base de données non supporté: $DB_TYPE"
    exit 1
  fi
  
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}[SUCCESS]${NC} Restauration terminée"
  else
    echo -e "${RED}[ERROR]${NC} Échec de la restauration"
    exit 1
  fi
}

# Fonction d'aide
show_help() {
  echo "Script de sauvegarde et restauration de base de données"
  echo
  echo "Usage:"
  echo "  $0 backup <env> [options]"
  echo "  $0 restore <backup_file> <env> [options]"
  echo
  echo "Commands:"
  echo "  backup   Sauvegarde la base de données de l'environnement spécifié"
  echo "  restore  Restaure la base de données à partir d'un fichier de sauvegarde"
  echo
  echo "Arguments:"
  echo "  env           Environnement (dev, staging, prod)"
  echo "  backup_file   Chemin vers le fichier de sauvegarde pour la restauration"
  echo
  echo "Options:"
  echo "  -h, --help    Affiche ce message d'aide"
}

# Script principal
main() {
  if [ "$1" = "backup" ] && [ -n "$2" ]; then
    backup_database "$2"
  elif [ "$1" = "restore" ] && [ -n "$2" ] && [ -n "$3" ]; then
    restore_database "$2" "$3"
  elif [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_help
  else
    echo -e "${RED}[ERROR]${NC} Arguments invalides"
    show_help
    exit 1
  fi
}

main "$@"