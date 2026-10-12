## Starting point

```text
ai-engineering-platform/
│
├── apps/
│   └── api/
│
├── packages/
│   └── ...
│
├── infra/
│   └── terraform/
│       │
│       ├── modules/
│       │   ├── network/
│       │   ├── compute/
│       │   ├── iam/
│       │   ├── data/
│       │   └── observability/
│       │
│       └── envs/
│           ├── dev/
│           ├── stage/
│           └── prod/
│
└── .github/
    └── workflows/
        ├── terraform-validate.yml
        ├── terraform-plan.yml
        ├── terraform-apply.yml
        └── terraform-drift.yml
```


### The AWS architecture will eventually be:

```text
                    GitHub Actions
                          │
                          │ OIDC
                          ▼
                   AWS IAM Role
                          │
                          ▼
              ┌─────────────────────┐
              │       AWS ECS       │
              │      Fargate        │
              │                     │
              │   NestJS API        │
              └──────────┬──────────┘
                         │
                         ▼
                    Application
                    Load Balancer
                         │
              ┌──────────┴──────────┐
              │                     │
           PostgreSQL          CloudWatch
              │                     │
              ▼                     ▼
         RDS / data            Logs/Alarms

ECR ───────────────► ECS
Secrets Manager ───► ECS
```

And we'll have three environments:

```text
dev
 │
 ├── AWS resources
 └── GitHub Environment: dev

stage
 │
 ├── AWS resources
 └── GitHub Environment: stage

prod
 │
 ├── AWS resources
 └── GitHub Environment: prod
```

## Recommend order:

| Step | Feature              | Goal                                                  |
| ---- | -------------------- | ----------------------------------------------------- |
| 1    | Terraform Foundation | Install/configure Terraform and create repo structure |
| 2    | AWS Provider         | Connect Terraform to AWS                              |
| 3    | Remote tf State      | S3 backend and state locking                          |
| 4    | Network              | VPC/subnets/security groups                           |
| 5    | ECR                  | Container image repository                            |
| 6    | IAM                  | ECS task/execution roles and least privilege          |
| 7    | ECS/Fargate          | Run NestJS                                            |
| 8    | ALB                  | Public HTTP entry point                               |
| 9    | RDS                  | PostgreSQL                                            |
| 10   | Secrets Manager      | Application secrets                                   |
| 11   | CloudWatch           | Logs                                                  |
| 12   | Observability        | Alarms and monitoring                                 |
| 13   | GitHub OIDC          | GitHub → AWS without access keys                      |
| 14   | Terraform Plan CI    | PR validation/planning                                |
| 15   | Terraform Apply CI   | Controlled deployment                                 |
| 16   | Stage/Prod promotion | GitHub Environment approvals                          |
| 17   | Drift Detection      | Detect infrastructure changes                         |
| 18   | Hardening            | Security, locking, cleanup                            |

## Learning mode (lighter path, same outcome)

If this feels heavy, use this 2-pass approach:

- **Pass 1 (Build):** make each step work with minimum moving parts.
- **Pass 2 (Harden):** add security, reliability, and automation depth.

### Pass 1 — Build fast

1. Terraform foundation + provider + remote state
2. Network + IAM + ECR
3. ECS/Fargate + ALB (app reachable)
4. RDS + Secrets Manager (secure DB connection)
5. CloudWatch + basic alarms
6. GitHub OIDC + plan/apply workflows

### Pass 2 — Harden

1. Immutable image tagging + rollback strategy
2. Least-privilege IAM refinement
3. Stage/prod promotion with approvals
4. Drift detection + security checks
5. Cost and reliability tuning

### Weekly milestone template (recommended)

- **Week 1:** Steps 1–2 from Pass 1
- **Week 2:** Step 3 from Pass 1
- **Week 3:** Steps 4–5 from Pass 1
- **Week 4:** Step 6 from Pass 1
- **Week 5+:** Pass 2 hardening

### Definition of done per step

Before moving to next step, confirm all four:

1. You can explain the step in 3-5 lines.
2. `terraform plan` shows expected resources only.
3. You captured one proof (output/screenshot).
4. You updated this docs folder with what changed.

This keeps learning practical and prevents overload while still reaching production-grade understanding.

### workflow

```text
Developer
   │
   │ git push / PR
   ▼
GitHub
   │
   ├── terraform fmt
   ├── terraform validate
   ├── terraform plan
   │
   ▼
Approval
   │
   ▼
GitHub Actions
   │
   │ OIDC
   ▼
AWS
```

No long-lived AWS access keys in GitHub.

---

# STEP 1 — Terraform Foundation

For the first step, **do not create any AWS resources yet**.

Create this:

```text
ai-engineering-platform/
└── infra/
    └── terraform/
        ├── modules/
        └── envs/
            ├── dev/
            ├── stage/
            └── prod/
```

On Windows PowerShell:

```powershell
mkdir infra\terraform\modules
mkdir infra\terraform\envs
mkdir infra\terraform\envs\dev
mkdir infra\terraform\envs\stage
mkdir infra\terraform\envs\prod
```

You should now have:

```text
infra/
└── terraform/
    ├── modules/
    └── envs/
        ├── dev/
        ├── stage/
        └── prod/
```

## Why this structure?

`modules/` contains reusable infrastructure.

For example:

```text
modules/compute/
```

will eventually know **how to create ECS**.

But it won't know whether we're creating:

```text
dev
stage
prod
```

The environment folders decide that.

For example:

```text
envs/dev/
```

might say:

```text
CPU       = 256
Memory    = 512
Instances = 1
```

while:

```text
envs/prod/
```

might say:

```text
CPU       = 1024
Memory    = 2048
Instances = 2
```

Same module, different configuration.

---

## Our first milestone

Before writing any AWS resources, we'll get this working:

```text
Terraform
   │
   ▼
envs/dev
   │
   ▼
AWS provider
   │
   ▼
AWS account
```

## Optional: ECS vs EKS learning note

If you want to compare the ECS path with a Kubernetes/EKS path, see:

- `docs/k8s-vs-ecs-learning-note.md`