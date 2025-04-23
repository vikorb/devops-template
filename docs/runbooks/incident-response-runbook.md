# Runbook : Gestion des incidents

Ce runbook définit les procédures à suivre lors d'incidents affectant l'application et l'infrastructure. Il fournit des directives claires pour répondre efficacement aux problèmes opérationnels.

## Classification des incidents

| Niveau | Description | Temps de réponse | Escalade |
|--------|-------------|------------------|----------|
| P1 | Critique - Service indisponible | Immédiat (< 15 min) | Équipe complète + Direction |
| P2 | Majeur - Fonctionnalité principale dégradée | < 30 min | Équipe DevOps + Lead Dev |
| P3 | Mineur - Problème non critique | < 2 heures | Ingénieur de garde |
| P4 | Faible - Anomalie sans impact utilisateur | 1 jour ouvré | Ticketing normal |

## Procédure de réponse aux incidents

### 1. Détection et alerte

**Sources d'alerte potentielles :**
- Alertes Prometheus/Grafana
- Notifications CloudWatch
- Rapports utilisateurs via le support

**Actions immédiates :**
- Noter l'heure exacte de détection
- Vérifier les tableaux de bord de surveillance pour confirmer l'incident
- Créer un ticket d'incident dans le système de suivi

### 2. Triage initial

**Responsable :** Ingénieur de garde

**Actions :**
- Évaluer la gravité (P1-P4) selon les critères de classification
- Pour les incidents P1/P2, créer un canal de communication dédié (Slack)
- Désigner un Incident Manager si différent de l'ingénieur de garde
- Alerter les parties prenantes appropriées selon le niveau de gravité

### 3. Investigation

**Responsable :** Équipe d'intervention

**Actions :**
1. Vérifier les changements récents (déploiements, modifications d'infrastructure)
   ```bash
   git log --since="24 hours ago" --pretty=format:"%h - %an, %ar : %s"
   aws cloudtrail lookup-events --lookup-attributes AttributeKey=EventName,AttributeValue=UpdateService
   ```

2. Analyser les métriques système
   ```bash
   # Vérifier les métriques CPU/mémoire
   aws cloudwatch get-metric-statistics --namespace AWS/ECS --metric-name CPUUtilization --dimensions Name=ServiceName,Value=app-service Name=ClusterName,Value=app-cluster --start-time `date -u -v-1H +%Y-%m-%dT%H:%M:%SZ` --end-time `date -u +%Y-%m-%dT%H:%M:%SZ` --period 60 --statistics Average
   ```

3. Examiner les logs d'application
   ```bash
   # Récupérer les derniers logs d'erreur
   aws logs filter-log-events --log-group-name /ecs/app-service --filter-pattern "ERROR"
   ```

4. Vérifier les problèmes d'infrastructure
   ```bash
   # Vérifier l'état des instances EC2
   aws ec2 describe-instance-status

   # Vérifier l'état des services ECS
   aws ecs describe-services --cluster app-cluster --services app-service
   ```

5. Documenter en temps réel les observations dans le ticket d'incident

### 4. Mitigation

**Responsable :** Équipe d'intervention

**Actions selon le type d'incident :**

#### Problèmes d'application

- **Redémarrage de service**
  ```bash
  aws ecs update-service --cluster app-cluster --service app-service --force-new-deployment
  ```

- **Rollback de version**
  ```bash
  # Identifier la version précédente stable
  aws ecs describe-task-definition --task-definition app-service:ACTIVE
  
  # Déployer la version précédente
  aws ecs update-service --cluster app-cluster --service app-service --task-definition app-service:<previous-version>
  ```

- **Scaling temporaire**
  ```bash
  # Augmenter le nombre de tâches ECS
  aws ecs update-service --cluster app-cluster --service app-service --desired-count <increased-count>
  ```

#### Problèmes de base de données

- **Redirection vers un replica**
  ```bash
  # Promouvoir un replica RDS
  aws rds promote-read-replica --db-instance-identifier <replica-identifier>
  
  # Mettre à jour le paramètre d'environnement
  aws ssm put-parameter --name /app/DB_HOST --value <new-endpoint> --overwrite
  ```

- **Restauration de sauvegarde**
  ```bash
  # Pour une restauration complète, voir le script
  ./scripts/db-backup.sh restore <backup-file> prod
  ```

#### Problèmes d'infrastructure

- **Basculement vers une autre zone/région**
  ```bash
  # Basculer le trafic via Route 53
  aws route53 change-resource-record-sets --hosted-zone-id <zone-id> --change-batch file://route53-failover.json
  ```

- **Restauration des ressources Terraform**
  ```bash
  cd terraform/environments/prod
  terraform apply -var-file=dr.tfvars
  ```

### 5. Communication

**Responsable :** Incident Manager

**Actions :**
- Mettre à jour régulièrement le canal de communication (toutes les 30 minutes pour P1/P2)
- Pour les incidents publics, coordonner avec l'équipe Communication pour les annonces externes
- Informer les utilisateurs via la page de statut (status.example.com)

**Template de mise à jour :**
```
Heure: [TIMESTAMP]
État: [EN COURS/RÉSOLU]
Impact: [DESCRIPTION DE L'IMPACT]
Actions en cours: [DESCRIPTION DES ACTIONS]
Prochaine mise à jour: [TIMESTAMP]
```

### 6. Résolution et clôture

**Responsable :** Incident Manager

**Actions :**
- Confirmer que tous les systèmes fonctionnent normalement
- Valider avec les tests automatisés et manuels
- Annoncer la résolution sur tous les canaux de communication
- Mettre à jour le ticket d'incident avec les détails de la résolution
- Planifier la réunion post-mortem

## Post-mortem

Une réunion post-mortem doit être organisée dans les 48 heures suivant la résolution de tout incident P1 ou P2.

**Format du document post-mortem :**

```
# Post-Mortem: [TITRE DE L'INCIDENT]

## Résumé
[Description concise de l'incident]

## Chronologie
[Liste chronologique des événements]

## Impact
[Description détaillée de l'impact]

## Cause première
[Analyse de la cause première]

## Ce qui a bien fonctionné
[Points positifs de la gestion d'incident]

## Ce qui pourrait être amélioré
[Points d'amélioration]

## Actions correctives
[Liste des actions à entreprendre pour prévenir la récurrence]
```

## Contacts d'escalade

| Rôle | Nom | Contact Principal | Contact Secondaire |
|------|-----|-------------------|-------------------|
| Premier répondant | [NOM] | [TÉLÉPHONE] | [EMAIL] |
| DevOps Lead | [NOM] | [TÉLÉPHONE] | [EMAIL] |
| DBA | [NOM] | [TÉLÉPHONE] | [EMAIL] |
| CTO | [NOM] | [TÉLÉPHONE] | [EMAIL] |

## Liste de contrôle de préparation aux incidents

- [ ] Tous les ingénieurs d'astreinte ont accès aux outils de surveillance
- [ ] Les identifiants de tous les comptes de service sont accessibles via Secrets Manager
- [ ] Les sauvegardes sont testées régulièrement
- [ ] Les tests de basculement DR sont effectués trimestriellement
- [ ] La documentation des procédures est à jour

## Annexes

### Commandes utiles

```bash
# Vérifier les logs des conteneurs
aws logs get-log-events --log-group-name /ecs/app-service --log-stream-name <stream-id>

# Vérifier l'état de santé de l'ALB
aws elbv2 describe-target-health --target-group-arn <tg-arn>

# Obtenir des métriques CloudWatch
aws cloudwatch get-metric-data --metric-data-queries file://metric-query.json --start-time `date -u -v-1H +%Y-%m-%dT%H:%M:%SZ` --end-time `date -u +%Y-%m-%dT%H:%M:%SZ`
```

### Scripts de diagnostic

```bash
# Exécuter une vérification complète
./scripts/deploy-verify.sh https://example.com --verbose

# Tester la performance sous charge
./scripts/performance-test.sh https://example.com --concurrency=50 --requests=1000
```