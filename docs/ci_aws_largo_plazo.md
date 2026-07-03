# CI con AWS para largo plazo

Este documento define la estrategia de Integracion Continua para UleamMed usando GitHub Actions + AWS.

## Objetivos

- Validar cada Pull Request antes de merge.
- Publicar imagen Docker del backend al hacer merge a `main`.
- Evitar llaves fijas en CI usando OIDC (GitHub -> AWS).
- Mantener una base simple hoy, pero preparada para escalar.

## Workflows implementados

- `.github/workflows/ci-validacion-pr.yml`
  - Trigger: `pull_request` hacia `main` o `develop`.
  - Ejecuta validacion reutilizable del backend.
- `.github/workflows/ci-aws-ecr-main.yml`
  - Trigger: `push` a `main`.
  - Corre validacion y luego publica imagen a ECR.
- `.github/workflows/reutilizable-validacion-backend.yml`
  - Reutilizable para no duplicar logica de calidad/pruebas.

## Pasos de configuracion en GitHub

En el repositorio (Settings -> Secrets and variables -> Actions):

Variables:

- `AWS_REGION`: por ejemplo `us-east-1`
- `AWS_ECR_REPOSITORY`: por ejemplo `uleammed/backend`

Secretos:

- `AWS_ROLE_ARN`: ARN del rol IAM asumido por OIDC.

## Configuracion OIDC en AWS

### 1) Crear proveedor OIDC

Proveedor:

- URL: `https://token.actions.githubusercontent.com`
- Audience: `sts.amazonaws.com`

### 2) Crear rol IAM para GitHub Actions

La politica de confianza debe restringir por repositorio y ramas permitidas.

Ejemplo (ajustar `ORG` y `REPO`):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": [
            "repo:ORG/REPO:ref:refs/heads/main",
            "repo:ORG/REPO:ref:refs/heads/develop"
          ]
        }
      }
    }
  ]
}
```

### 3) Politica minima de permisos para ECR

Adjuntar al rol:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PermisosECRPush",
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchGetImage",
        "ecr:BatchCheckLayerAvailability",
        "ecr:CompleteLayerUpload",
        "ecr:GetDownloadUrlForLayer",
        "ecr:InitiateLayerUpload",
        "ecr:PutImage",
        "ecr:UploadLayerPart",
        "ecr:DescribeRepositories",
        "ecr:CreateRepository"
      ],
      "Resource": "*"
    }
  ]
}
```

## Reglas de rama recomendadas

En `main` y `develop`:

- Exigir Pull Request para merge.
- Exigir checks de estado aprobados antes de merge.
- Bloquear push directo.
- Exigir rama actualizada antes de merge (opcional pero recomendado).

Checks que deben quedar como requeridos:

- `Validacion continua en pull request / Validar backend (Python 3.12)`

## Roadmap sugerido (largo plazo)

1. Agregar cobertura minima (ejemplo: 70%) como gate obligatorio.
2. Agregar analisis SAST y Dependabot.
3. Firmar imagenes (cosign) y usar tags versionados semanticos.
4. Separar cuentas AWS por entorno (`dev`, `stg`, `prod`).
5. Agregar CD con aprobacion manual para `prod`.

## Observaciones para este proyecto

- El repo esta en etapa inicial, por eso el pipeline parte simple.
- Se prioriza backend Python/FastAPI que es el componente activo hoy.
- El flujo reutilizable permitira sumar `mobile` o `infra` sin rehacer CI.
