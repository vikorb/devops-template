# Utiliser une image officielle avec une version spécifique pour garantir la reproductibilité
FROM node:18-alpine AS build

# Définir le répertoire de travail
WORKDIR /app

# Copier les fichiers de dépendances pour optimiser la mise en cache des couches Docker
COPY package*.json ./

# Installer les dépendances avec une version verrouillée et en mode production
# Utiliser npm ci au lieu de npm install pour une installation plus fiable et reproductible
RUN npm ci --only=production

# Copier le reste des fichiers de l'application
COPY . .

# Construire l'application si nécessaire (par exemple avec webpack, babel, etc.)
RUN npm run build

# Utiliser une image multi-stage pour réduire la taille finale de l'image
FROM node:18-alpine

# Définir les variables d'environnement
ENV NODE_ENV=production
ENV PORT=3000

# Créer un utilisateur non-root pour des raisons de sécurité
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Définir le répertoire de travail
WORKDIR /app

# Copier seulement les fichiers nécessaires depuis l'étape de build
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
COPY --from=build /app/package.json ./

# Changer la propriété des fichiers
RUN chown -R appuser:appgroup /app

# Utiliser l'utilisateur non-root
USER appuser

# Exposer le port sur lequel l'application s'exécute
EXPOSE $PORT

# Utiliser la commande de démarrage optimisée pour Node.js en production
CMD ["node", "--max-old-space-size=2048", "dist/server.js"]

# Ajouter des métadonnées utiles en utilisant des labels
LABEL maintainer="DevOps Team <devops@example.com>"
LABEL version="1.0"
LABEL description="Node.js application image for DevOps Template"