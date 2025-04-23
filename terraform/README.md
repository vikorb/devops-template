# Infrastructure as Code (Terraform)

Ce répertoire contient les configurations Terraform pour le provisionnement de l'infrastructure.

## Structure

- `modules/` - Modules réutilisables (VPC, ECS, RDS, etc.)
- `environments/` - Configurations spécifiques à chaque environnement
  - `dev/`
  - `staging/`
  - `prod/`
- `backend.tf` - Configuration pour le stockage de l'état Terraform distant