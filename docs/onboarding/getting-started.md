# Guide d'intégration pour les nouveaux membres de l'équipe

Ce document vous aidera à configurer votre environnement de développement et à comprendre notre workflow DevOps.

## Prérequis

Avant de commencer, assurez-vous d'avoir installé les outils suivants :

- **Git** - Système de contrôle de version
- **Docker & Docker Compose** - Pour la conteneurisation des applications
- **Terraform** (v1.0.0+) - Pour l'infrastructure as code
- **AWS CLI** - Pour interagir avec AWS
- **Node.js** (v16+) ou **Python** (v3.9+) selon le projet

## Configuration initiale

1. **Cloner le dépôt**

```bash
git clone https://github.com/votre-organisation/votre-projet.git
cd votre-projet
```

2. **Exécuter le script d'initialisation**

```bash
./scripts/setup.sh
```

Ce script vérifiera les prérequis, configurera votre environnement de développement local et initialisera les outils nécessaires.

3. **Configurer les accès AWS**

```bash
aws configure
```

Utilisez les identifiants fournis par l'administrateur AWS de l'équipe.

## Structure du projet

Notre projet suit une structure standardisée :

- `.github/workflows/` - Pipelines CI/CD avec GitHub Actions
- `docker/` - Configurations Docker pour différents environnements
- `terraform/` - Infrastructure as Code avec Terraform
- `scripts/` - Scripts utilitaires pour les opérations courantes
- `monitoring/` - Configurations pour la surveillance et l'observabilité
- `docs/` - Documentation du projet

## Workflow de développement

### Branches Git

Nous utilisons le modèle GitFlow pour la gestion des branches :

- `main` - Code de production, toujours déployable
- `develop` - Branche d'intégration principale
- `feature/*` - Fonctionnalités en cours de développement
- `bugfix/*` - Corrections de bugs
- `release/*` - Préparation des versions pour la production
- `hotfix/*` - Corrections urgentes en production

### Cycle de développement

1. **Créer une branche de fonctionnalité**
   ```bash
   git checkout develop
   git pull
   git checkout -b feature/ma-fonctionnalite
   ```

2. **Développer et tester localement**
   ```bash
   docker-compose -f docker/docker-compose.yml up -d
   ```

3. **Valider et pousser vos modifications**
   ```bash
   git add .
   git commit -m "Description détaillée des changements"
   git push origin feature/ma-fonctionnalite
   ```

4. **Créer une Pull Request (PR) sur GitHub**
   - Créez une PR de votre branche vers `develop`
   - Les pipelines CI s'exécuteront automatiquement
   - Un revieweur validera vos changements

5. **Fusion et déploiement**
   - Une fois approuvée, la PR est fusionnée dans `develop`
   - Le déploiement vers l'environnement de staging est automatique
   - Les fusions vers `main` déclenchent un déploiement en production (après approbation)

## Outils et ressources

### Environnements

- **Développement** : https://dev.example.com
- **Staging** : https://staging.example.com
- **Production** : https://example.com

### Monitoring

- **Grafana** : https://grafana.example.com (demandez les identifiants)
- **Prometheus** : https://prometheus.example.com (accès interne uniquement)

### Logs

- **CloudWatch Logs** : Accessible via la console AWS
- **Kibana** : https://kibana.example.com (pour la recherche et l'analyse des logs)

## Résolution des problèmes courants

### Docker ne démarre pas

```bash
# Vérifier l'état des conteneurs
docker-compose -f docker/docker-compose.yml ps

# Voir les logs
docker-compose -f docker/docker-compose.yml logs -f
```

### Problèmes de déploiement

Si un déploiement échoue :

1. Vérifiez les logs dans GitHub Actions
2. Examinez les logs CloudWatch
3. Utilisez le script de vérification du déploiement pour diagnostiquer
   ```bash
   ./scripts/deploy-verify.sh https://dev.example.com
   ```

## Support et communication

- **Slack** : Canal #devops-support pour l'assistance
- **JIRA** : Pour le suivi des tickets et des projets
- **Wiki** : Documentation détaillée sur Confluence
- **Réunions** : Stand-up quotidien à 10h, revue de sprint tous les vendredis à 14h

## Sécurité

- Ne partagez jamais vos identifiants AWS
- N'exposez pas de secrets dans le code ou les commits
- Utilisez Secrets Manager ou Parameter Store pour les secrets
- Signalez immédiatement toute faille de sécurité potentielle à l'équipe de sécurité

---

Pour toute question ou préoccupation, n'hésitez pas à contacter le responsable DevOps ou votre mentor désigné.