# Activacion final de CI (pendiente de acceso a cuentas)

Este proyecto ya tiene el CI implementado en codigo. Solo faltan pasos de activacion en cuentas GitHub y AWS.

## 1) Crear Pull Request del cambio ya subido

Rama:

- `feature/ci-aws`

URL directa:

- <https://github.com/proyecto-uleammed/UleamMed/pull/new/feature/ci-aws>

Titulo sugerido:

- `Implementar CI continuo con AWS y ECR`

## 2) Configurar secrets y variables en GitHub Actions

Ruta:

- `Settings -> Secrets and variables -> Actions`

Variables:

- `AWS_REGION` (ejemplo: `us-east-1`)
- `AWS_ECR_REPOSITORY` (ejemplo: `uleammed/backend`)

Secreto:

- `AWS_ROLE_ARN` (ARN del rol IAM OIDC para GitHub)

## 3) Configurar OIDC + rol IAM en AWS

Usar plantillas del repositorio:

- `infra/aws/politica-confianza-oidc-github.json`
- `infra/aws/politica-permisos-ci-ecr.json`

Guia completa:

- `docs/ci_aws_largo_plazo.md`

## 4) Activar reglas de rama en GitHub

En `main` y `develop`:

- Requerir Pull Request para merge.
- Bloquear push directo.
- Requerir checks aprobados.

Check requerido sugerido:

- `Validacion continua en pull request / Validar backend (Python 3.12)`

## 5) Prueba de punta a punta

1. Abrir PR desde `feature/ci-aws` a `main`.
2. Confirmar que corre `CI Validacion PR`.
3. Hacer merge.
4. Confirmar que corre `CI AWS ECR Main` y publica imagen en ECR.
