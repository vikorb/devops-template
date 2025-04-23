# Utiliser une image Python officielle avec une version spécifique
FROM python:3.11-slim AS build

# Définir des variables d'environnement pour optimiser Python
ENV PYTHONDONTWRITEBYTECODE=1 \
  PYTHONUNBUFFERED=1 \
  PIP_NO_CACHE_DIR=off \
  PIP_DISABLE_PIP_VERSION_CHECK=on

# Installer les dépendances système nécessaires
RUN apt-get update && apt-get install -y --no-install-recommends \
  build-essential \
  && rm -rf /var/lib/apt/lists/*

# Créer et définir le répertoire de travail
WORKDIR /app

# Installer le gestionnaire de dépendances poetry
RUN pip install --no-cache-dir poetry==1.5.1

# Copier uniquement les fichiers nécessaires à l'installation des dépendances
COPY pyproject.toml poetry.lock* ./

# Configurer poetry pour ne pas créer d'environnement virtuel dans le conteneur
RUN poetry config virtualenvs.create false

# Installer les dépendances
RUN poetry install --no-dev --no-interaction --no-ansi

# Deuxième étape pour une image finale plus légère
FROM python:3.11-slim

# Définir les variables d'environnement
ENV PYTHONDONTWRITEBYTECODE=1 \
  PYTHONUNBUFFERED=1 \
  PYTHONPATH=/app

# Créer un utilisateur non-root pour des raisons de sécurité
RUN addgroup --system app && adduser --system --group app

# Créer et définir le répertoire de travail
WORKDIR /app

# Copier les dépendances installées dans l'étape précédente
COPY --from=build /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages
COPY --from=build /usr/local/bin /usr/local/bin

# Copier le code de l'application
COPY . .

# Changer la propriété des fichiers de l'application
RUN chown -R app:app /app

# Utiliser l'utilisateur non-root
USER app

# Exposer le port sur lequel l'application s'exécute
EXPOSE 8000

# Commande par défaut pour démarrer l'application
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "app.wsgi:application"]

# Ajouter des métadonnées utiles en utilisant des labels
LABEL maintainer="DevOps Team <devops@example.com>"
LABEL version="1.0"
LABEL description="Python application image for DevOps Template"