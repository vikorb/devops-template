# Guide de dépannage

Ce guide fournit des solutions aux problèmes les plus courants que vous pourriez rencontrer lors du développement, du déploiement ou de l'exploitation de l'application.

## Table des matières

- [Problèmes de développement local](#problèmes-de-développement-local)
- [Problèmes de CI/CD](#problèmes-de-cicd)
- [Problèmes d'infrastructure](#problèmes-dinfrastructure)
- [Problèmes d'application](#problèmes-dapplication)
- [Problèmes de monitoring](#problèmes-de-monitoring)
- [Procédures de récupération](#procédures-de-récupération)

## Problèmes de développement local

### Docker Compose ne démarre pas

**Symptômes :**
- Erreur lors du démarrage des conteneurs avec `docker-compose up`
- Message "port is already allocated"

**Solutions :**
1. Vérifiez si les ports requis sont déjà utilisés :
   ```bash
   sudo lsof -i :<port>
   ```

2. Arrêtez tous les conteneurs et nettoyez les ressources :
   ```bash
   docker-compose down -v
   docker system prune
   ```

3. Vérifiez les logs pour plus de détails :
   ```bash
   docker-compose logs
   ```

### Problèmes de dépendances

**Symptômes :**
- Erreurs de type "module not found" ou "cannot resolve dependency"
- Build échoue avec des erreurs de package

**Solutions :**
1. Nettoyez les caches de dépendances :
   ```bash
   # Pour Node.js
   rm -rf node_modules
   npm cache clean --force
   npm install

   # Pour Python
   rm -rf venv
   python -m venv venv
   source venv/bin/activate
   pip install -r requirements.txt
   ```

2. Vérifiez les versions dans package.json ou requirements.txt
3. Utilisez les volumes Docker pour isoler les dépendances

## Problèmes de CI/CD

### Échec de la pipeline CI

**Symptômes :**
- Les tests échouent dans GitHub Actions
- Le build ne se termine pas correctement

**Solutions :**
1. Examinez les logs d'erreur dans GitHub Actions
2. Vérifiez que tous les tests passent localement :
   ```bash
   npm test
   # ou
   pytest
   ```
3. Vérifiez les dépendances de build et les variables d'environnement
4. Assurez-vous que les secrets nécessaires sont configurés dans GitHub

### Échec du déploiement

**Symptômes :**
- La pipeline CD échoue lors du déploiement
- L'application n'est pas accessible après le déploiement

**Solutions :**
1. Vérifiez les logs de déploiement dans GitHub Actions
2. Utilisez le script de vérification pour diagnostiquer :
   ```bash
   ./scripts/deploy-verify.sh https://app-url.com
   ```
3. Vérifiez les logs CloudWatch ou Kubernetes
4. Examinez l'état des services ECS ou Kubernetes :
   ```bash
   aws ecs describe-services --cluster <cluster-name> --services <service-name>
   # ou
   kubectl get pods
   kubectl describe pod <pod-name>
   ```

## Problèmes d'infrastructure

### Problèmes de provisionnement Terraform

**Symptômes :**
- Erreurs lors de l'exécution de `terraform apply`
- Ressources incomplètes ou en échec

**Solutions :**
1. Vérifiez l'état Terraform actuel :
   ```bash
   terraform state list
   terraform state show <resource>
   ```

2. Examinez les logs Terraform pour les erreurs détaillées

3. Tentez d'import manuel pour les ressources existantes :
   ```bash
   terraform import <resource_address> <resource_id>
   ```

4. En dernier recours, corrigez manuellement la ressource dans la console AWS puis exécutez :
   ```bash
   terraform refresh
   ```

### Problèmes de connectivité

**Symptômes :**
- L'application ne peut pas se connecter à la base de données
- Les services ne peuvent pas communiquer entre eux

**Solutions :**
1. Vérifiez les groupes de sécurité et les règles ACL :
   ```bash
   aws ec2 describe-security-groups --group-ids <sg-id>
   ```

2. Testez la connectivité depuis différents points :
   ```bash
   # Depuis un bastion host
   nc -zv <host> <port>
   
   # Depuis un conteneur
   docker exec -it <container> ping <host>
   ```

3. Vérifiez les tables de routage et les points de terminaison VPC

## Problèmes d'application

### Erreurs 5xx

**Symptômes :**
- Les utilisateurs reçoivent des erreurs 500, 502, 503, 504
- Les metrics Prometheus montrent des taux d'erreur élevés

**Solutions :**
1. Vérifiez les logs d'application :
   ```bash
   # CloudWatch
   aws logs get-log-events --log-group-name <log-group> --log-stream-name <log-stream>
   
   # Kubernetes
   kubectl logs <pod-name>
   ```

2. Recherchez des pics d'utilisation des ressources dans Grafana
3. Vérifiez la configuration du load balancer et les health checks
4. Examinez les traces dans X-Ray ou Jaeger pour identifier les goulots d'étranglement

### Problèmes de performance

**Symptômes :**
- Temps de réponse lents
- Utilisation élevée du CPU ou de la mémoire

**Solutions :**
1. Exécutez des tests de performance pour identifier les problèmes :
   ```bash
   ./scripts/performance-test.sh https://app-url.com
   ```

2. Vérifiez les index de base de données et les requêtes lentes
3. Examinez les métriques de scaling automatique
4. Vérifiez la consommation de ressources au niveau des conteneurs :
   ```bash
   docker stats
   # ou
   kubectl top pods
   ```

## Problèmes de monitoring

### Alertes manquantes ou excessives

**Symptômes :**
- Absence d'alertes pour des incidents réels
- Trop de fausses alertes

**Solutions :**
1. Vérifiez la configuration des règles d'alerte dans Prometheus :
   ```bash
   cat monitoring/prometheus/rules/alert_rules.yml
   ```
   
2. Ajustez les seuils et les intervalles d'évaluation
3. Améliorez les annotations et les descriptions pour faciliter le diagnostic
4. Mettez en place un système de déduplication pour les alertes similaires

### Dashboards incomplets

**Symptômes :**
- Dashboards Grafana montrant "No Data" ou données partielles
- Métriques manquantes

**Solutions :**
1. Vérifiez que les exportateurs de métriques fonctionnent correctement
2. Assurez-vous que Prometheus peut scraper tous les targets :
   ```bash
   curl http://prometheus:9090/api/v1/targets
   ```
3. Vérifiez les configurations de rétention et la capacité de stockage
4. Validez la syntaxe des requêtes PromQL dans les dashboards

## Procédures de récupération

### Rollback de déploiement

En cas d'incident critique en production :

1. Identifiez la dernière version stable :
   ```bash
   aws ecs describe-task-definition --task-definition <task-family>
   # ou
   kubectl rollout history deployment/<deployment-name>
   ```

2. Effectuez un rollback :
   ```bash
   # ECS
   aws ecs update-service --cluster <cluster-name> --service <service-name> --task-definition <previous-task-def>
   
   # Kubernetes
   kubectl rollout undo deployment/<deployment-name> --to-revision=<revision>
   ```

3. Vérifiez que le rollback a réussi :
   ```bash
   ./scripts/deploy-verify.sh https://app-url.com
   ```

4. Documentez l'incident et organisez une réunion post-mortem

### Récupération de la base de données

En cas de corruption ou de perte de données :

1. Arrêtez l'application pour éviter d'autres écritures :
   ```bash
   aws ecs update-service --cluster <cluster-name> --service <service-name> --desired-count 0
   # ou
   kubectl scale deployment/<deployment-name> --replicas=0
   ```

2. Identifiez le snapshot ou la sauvegarde la plus récente :
   ```bash
   aws rds describe-db-snapshots --db-instance-identifier <db-id>
   ```

3. Restaurez à partir de la sauvegarde :
   ```bash
   # RDS
   aws rds restore-db-instance-from-db-snapshot --db-instance-identifier <new-db-id> --db-snapshot-identifier <snapshot-id>
   
   # Ou utilisez le script de restauration pour une base de données locale
   ./scripts/db-backup.sh restore <backup-file> <env>
   ```

4. Mettez à jour les connexions de l'application si nécessaire
5. Redémarrez l'application :
   ```bash
   aws ecs update-service --cluster <cluster-name> --service <service-name> --desired-count <count>
   # ou
   kubectl scale deployment/<deployment-name> --replicas=<count>
   ```

### Récupération après défaillance d'infrastructure

En cas de défaillance majeure d'une zone AWS :

1. Vérifiez le statut AWS :
   ```bash
   aws health describe-events
   ```

2. Si nécessaire, redéployez manuellement vers une autre région :
   ```bash
   cd terraform/environments/dr
   terraform init
   terraform apply
   ```

3. Mettez à jour les entrées DNS pour pointer vers la nouvelle infrastructure
4. Suivez le playbook de DR (Disaster Recovery) pour les étapes détaillées

---

Pour toute assistance supplémentaire, contactez l'équipe DevOps sur le canal Slack #devops-support.