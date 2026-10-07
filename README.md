# NestJS AWS DevOps Starter

A production-style NestJS starter focused on CI/CD with GitHub Actions, Docker, Amazon ECR, and Amazon ECS.

## Overview

This project includes:

- NestJS API in TypeScript
- Health endpoint for container/service checks: `/health`
- Unit + e2e tests with Jest
- ESLint (flat config) for TS/JS
- Multi-stage `Dockerfile`
- GitHub Actions pipeline:
	- Lint + build + test
	- Docker build + smoke test
	- Push image to ECR
	- Deploy ECS service (force new deployment)
- Local one-command deploy script for ECR + Terraform ECS rollout

## Local one-command deploy

Run:

```powershell
npm run deploy
```

Optional flags:

```powershell
npm run deploy -- --tag <your-tag>
npm run deploy -- --skip-build
```

Default local assumptions:

- AWS profile: `devops-local`
- AWS region: `ap-south-1`
- ECR repository: `devops-nestjs-app`

You can override via environment variables (`AWS_PROFILE`, `AWS_REGION`, `ECR_REPOSITORY`).

## Project structure

- `src/` - app source code
- `test/` - e2e tests
- `.github/workflows/ci.yml` - CI/CD workflow
- `Dockerfile` - production image build
- `docs/README.md` - AWS setup and deployment notes



- `docs/TERRAFORM.md` - Terraform
- `docs/ci-cd.md` - CI CD





Step	Feature	Goal
1	Terraform Foundation	Install/configure Terraform and create repo structure
2	AWS Provider	Connect Terraform to AWS
3	Network	VPC/subnets/security groups
4	ECR	Container image repository
5	IAM	ECS + GitHub Actions permissions
6	Secrets Manager	Application secrets
7	CloudWatch	Logs
8	ECS/Fargate	Run NestJS
9	ALB	Public HTTP entry point
10	RDS	PostgreSQL
11	Observability	Alarms and monitoring
12	GitHub OIDC	GitHub → AWS without access keys
13	Terraform Plan CI	PR validation/planning
14	Terraform Apply CI	Controlled deployment
15	Stage/Prod promotion	GitHub Environment approvals
16	Drift Detection	Detect infrastructure changes
17	Hardening	Security, locking, cleanup