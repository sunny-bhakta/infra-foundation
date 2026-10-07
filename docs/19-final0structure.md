# 18. Final directory structure

```text
.github/
└── workflows/
    │
    ├── CI — application code
    │
    ├── CD — application deployment
    │
    └── Terraform — infrastructure
```

For your project, I recommend these files:

```text
.github/workflows/
│
├── ci.yml
├── cd.yml
│
├── terraform-validate.yml
├── terraform-plan.yml
├── terraform-apply.yml
├── terraform-drift.yml
└── terraform-state-migrate.yml
```

So:

* `ci.yml` → NestJS/TypeScript application checks
* `cd.yml` → Build Docker image → ECR → ECS
* `terraform-*.yml` → Infrastructure only

This keeps **application deployment completely separate from infrastructure deployment**.

---

# 1. Final GitHub Actions architecture

Think of the repository as having two pipelines.

### Infrastructure pipeline

```text
Terraform code
     │
     ▼
terraform-validate
     │
     ▼
terraform-plan
     │
     ▼
Pull Request
     │
     ▼
Review / Merge
     │
     ▼
terraform-apply
     │
     ├── dev
     ├── stage
     └── prod
```

### Application pipeline

```text
NestJS code
     │
     ▼
CI
     │
     ├── install
     ├── lint
     ├── test
     └── build
     │
     ▼
CD
     │
     ├── Docker build
     ├── ECR push
     └── ECS deployment
```

---

# 2. `ci.yml`

This is **application CI**, not Terraform.

### Path

```text
.github/workflows/ci.yml
```

```yaml
name: CI

on:
  pull_request:
    branches:
      - main
    paths-ignore:
      - "infra/terraform/**"

  push:
    branches:
      - main
    paths-ignore:
      - "infra/terraform/**"

permissions:
  contents: read

concurrency:
  group: ci-${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  test:
    name: Application CI
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: 24
          cache: npm

      - name: Install dependencies
        run: npm ci

      - name: Lint
        run: npm run lint

      - name: Test
        run: npm test

      - name: Build
        run: npm run build
```

The purpose is simple:

```text
Code
 ↓
npm ci
 ↓
lint
 ↓
test
 ↓
build
```

If this fails, the application should not proceed to deployment.

---

# 3. `cd.yml`

Now application deployment.

### Path

```text
.github/workflows/cd.yml
```

This workflow will eventually do:

```text
NestJS
   ↓
Docker build
   ↓
ECR
   ↓
ECS
```

Here's the initial production-oriented structure:

```yaml
name: CD

on:
  workflow_dispatch:
    inputs:
      environment:
        description: "Environment to deploy"
        required: true
        type: choice
        options:
          - dev
          - stage
          - prod

      image_tag:
        description: "Docker image tag"
        required: true
        type: string

permissions:
  contents: read
  id-token: write

concurrency:
  group: cd-${{ inputs.environment }}
  cancel-in-progress: false

jobs:
  deploy:
    name: Deploy Application
    runs-on: ubuntu-latest

    environment: ${{ inputs.environment }}

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ vars.AWS_DEPLOY_ROLE_ARN }}
          aws-region: ${{ vars.AWS_REGION }}

      - name: Login to Amazon ECR
        id: ecr
        uses: aws-actions/amazon-ecr-login@v2

      - name: Build Docker image
        env:
          ECR_REGISTRY: ${{ steps.ecr.outputs.registry }}
          ECR_REPOSITORY: ${{ vars.ECR_REPOSITORY }}
          IMAGE_TAG: ${{ inputs.image_tag }}
        run: |
          docker build \
            -t $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG \
            .

      - name: Push Docker image
        env:
          ECR_REGISTRY: ${{ steps.ecr.outputs.registry }}
          ECR_REPOSITORY: ${{ vars.ECR_REPOSITORY }}
          IMAGE_TAG: ${{ inputs.image_tag }}
        run: |
          docker push \
            $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG

      - name: Deploy to ECS
        env:
          ECS_CLUSTER: ${{ vars.ECS_CLUSTER }}
          ECS_SERVICE: ${{ vars.ECS_SERVICE }}
          IMAGE_TAG: ${{ inputs.image_tag }}
        run: |
          aws ecs update-service \
            --cluster "$ECS_CLUSTER" \
            --service "$ECS_SERVICE" \
            --force-new-deployment

      - name: Wait for ECS deployment
        env:
          ECS_CLUSTER: ${{ vars.ECS_CLUSTER }}
          ECS_SERVICE: ${{ vars.ECS_SERVICE }}
        run: |
          aws ecs wait services-stable \
            --cluster "$ECS_CLUSTER" \
            --services "$ECS_SERVICE"
```

### Important

We are intentionally using:

```yaml
vars.AWS_DEPLOY_ROLE_ARN
```

rather than:

```text
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
```

because we already designed the system around **GitHub OIDC**.

---

# 4. Terraform validation

Now infrastructure.

### Path

```text
.github/workflows/terraform-validate.yml
```

```yaml
name: Terraform Validate

on:
  pull_request:
    paths:
      - "infra/terraform/**"
      - ".github/workflows/terraform-validate.yml"

permissions:
  contents: read

concurrency:
  group: terraform-validate-${{ github.event.pull_request.number }}
  cancel-in-progress: true

jobs:
  validate:
    name: Validate Terraform
    runs-on: ubuntu-latest

    strategy:
      matrix:
        environment:
          - dev
          - stage
          - prod

    defaults:
      run:
        working-directory: infra/terraform/envs/${{ matrix.environment }}

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3

      - name: Terraform Format Check
        run: terraform fmt -check -recursive ../../..

      - name: Terraform Init
        run: terraform init -backend=false

      - name: Terraform Validate
        run: terraform validate
```

Notice:

```yaml
terraform init -backend=false
```

For validation we don't need to connect to the remote state backend.

This makes validation cheaper and safer.

---

# 5. Terraform Plan

### Path

```text
.github/workflows/terraform-plan.yml
```

```yaml
name: Terraform Plan

on:
  pull_request:
    paths:
      - "infra/terraform/**"
      - ".github/workflows/terraform-plan.yml"

permissions:
  contents: read
  id-token: write

concurrency:
  group: terraform-plan-${{ github.event.pull_request.number }}
  cancel-in-progress: true

jobs:
  plan:
    name: Terraform Plan
    runs-on: ubuntu-latest

    strategy:
      matrix:
        environment:
          - dev
          - stage
          - prod

    environment: ${{ matrix.environment }}

    defaults:
      run:
        working-directory: infra/terraform/envs/${{ matrix.environment }}

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3

      - name: Terraform Init
        run: terraform init

      - name: Terraform Validate
        run: terraform validate

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ vars.TERRAFORM_ROLE_ARN }}
          aws-region: ${{ vars.AWS_REGION }}

      - name: Terraform Plan
        run: terraform plan -no-color
```

---

# 6. Important: why Plan uses AWS

You may wonder:

> Why does `terraform plan` need AWS credentials?

Because Terraform needs to compare:

```text
Terraform configuration
        +
Terraform state
        +
Actual AWS infrastructure
```

So:

```text
GitHub
   ↓
OIDC
   ↓
AWS IAM
   ↓
Terraform role
   ↓
AWS
```

Then Terraform can calculate the plan.

---

# 7. Terraform Apply

### Path

```text
.github/workflows/terraform-apply.yml
```

```yaml
name: Terraform Apply

on:
  workflow_dispatch:
    inputs:
      environment:
        description: "Environment to deploy"
        required: true
        type: choice
        options:
          - dev
          - stage
          - prod

permissions:
  contents: read
  id-token: write

concurrency:
  group: terraform-apply-${{ inputs.environment }}
  cancel-in-progress: false

jobs:
  apply:
    name: Terraform Apply
    runs-on: ubuntu-latest

    environment: ${{ inputs.environment }}

    defaults:
      run:
        working-directory: infra/terraform/envs/${{ inputs.environment }}

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3

      - name: Terraform Init
        run: terraform init

      - name: Terraform Validate
        run: terraform validate

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ vars.TERRAFORM_ROLE_ARN }}
          aws-region: ${{ vars.AWS_REGION }}

      - name: Terraform Plan
        run: terraform plan -out=tfplan

      - name: Terraform Apply
        run: terraform apply -auto-approve tfplan
```

---

# 8. Why Apply creates a fresh plan

We deliberately do:

```text
terraform plan
      ↓
tfplan
      ↓
terraform apply tfplan
```

rather than:

```text
terraform apply
```

Because the infrastructure may have changed between the PR and deployment.

So Apply always creates a fresh plan.

---

# 9. Stage and Prod approvals

The important line is:

```yaml
environment: ${{ inputs.environment }}
```

If:

```text
environment = dev
```

GitHub uses:

```text
dev
```

If:

```text
environment = stage
```

GitHub uses:

```text
stage
```

If:

```text
environment = prod
```

GitHub uses:

```text
prod
```

Therefore GitHub Environment rules control approval.

---

# 10. Terraform Drift Detection

### Path

```text
.github/workflows/terraform-drift.yml
```

```yaml
name: Terraform Drift Detection

on:
  schedule:
    - cron: "0 2 * * *"

  workflow_dispatch:

permissions:
  contents: read
  id-token: write

jobs:
  drift:
    name: Detect Drift
    runs-on: ubuntu-latest

    strategy:
      matrix:
        environment:
          - dev
          - stage
          - prod

    environment: ${{ matrix.environment }}

    defaults:
      run:
        working-directory: infra/terraform/envs/${{ matrix.environment }}

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3

      - name: Terraform Init
        run: terraform init

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ vars.TERRAFORM_ROLE_ARN }}
          aws-region: ${{ vars.AWS_REGION }}

      - name: Terraform Drift Check
        id: drift
        run: terraform plan -detailed-exitcode -no-color
        continue-on-error: true

      - name: Report Result
        env:
          EXIT_CODE: ${{ steps.drift.outcome }}
        run: |
          echo "Terraform drift check completed."
          echo "Review the Terraform plan output for infrastructure differences."
```

However, there's an important improvement I'd make here.

We don't want a drift workflow to simply hide failures with `continue-on-error` and then always succeed.

A better implementation will explicitly distinguish:

```text
0 = no changes
2 = drift
1 = Terraform error
```

We'll harden this when we wire notifications/issues.

For now, the conceptual workflow is:

```text
Nightly
   ↓
terraform plan
   ↓
No changes → healthy
Changes → drift detected
Error → workflow failure
```

---

# 11. Terraform State Migration

This is the **dangerous one**.

### Path

```text
.github/workflows/terraform-state-migrate.yml
```

This should **not** run automatically.

It should only run manually.

```yaml
name: Terraform State Migration

on:
  workflow_dispatch:
    inputs:
      environment:
        description: "Environment to migrate"
        required: true
        type: choice
        options:
          - dev
          - stage
          - prod

      confirm:
        description: "Type MIGRATE to continue"
        required: true
        type: string

permissions:
  contents: read
  id-token: write

concurrency:
  group: terraform-state-migration-${{ inputs.environment }}
  cancel-in-progress: false

jobs:
  migrate:
    name: State Migration
    runs-on: ubuntu-latest

    environment: ${{ inputs.environment }}

    defaults:
      run:
        working-directory: infra/terraform/envs/${{ inputs.environment }}

    steps:
      - name: Verify confirmation
        if: ${{ inputs.confirm != 'MIGRATE' }}
        run: |
          echo "Migration was not confirmed."
          exit 1

      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3

      - name: Terraform Init
        run: terraform init

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ vars.TERRAFORM_ROLE_ARN }}
          aws-region: ${{ vars.AWS_REGION }}

      - name: Show Terraform State
        run: terraform state list

      - name: Show Terraform Version
        run: terraform version

      - name: Migration Reminder
        run: |
          echo "State migration workflow initialized."
          echo ""
          echo "IMPORTANT:"
          echo "Actual terraform state mv/import commands must be added"
          echo "after the old and new resource addresses are verified."
```

---

# 12. Why I intentionally didn't put `terraform state mv` yet

This is important.

We previously discussed migrating resources such as:

```text
aws_ecs_cluster.app
```

to something like:

```text
module.compute.aws_ecs_cluster.app
```

That's a **state address change**.

For example:

```text
OLD

aws_ecs_cluster.app
```

becomes:

```text
NEW

module.compute.aws_ecs_cluster.app
```

If we tell Terraform the wrong address, we could cause a resource recreation.

So we should **not blindly create generic migration commands**.

The migration workflow should first show:

```powershell
terraform state list
```

Then we map:

```text
old address
      ↓
new address
```

and only then execute:

```powershell
terraform state mv OLD NEW
```

This is why this workflow is manual and protected.

---

# 13. Your complete `.github/workflows`

You now have:

```text
.github/
└── workflows/
    │
    ├── ci.yml
    │
    ├── cd.yml
    │
    ├── terraform-validate.yml
    ├── terraform-plan.yml
    ├── terraform-apply.yml
    ├── terraform-drift.yml
    └── terraform-state-migrate.yml
```

And their responsibilities are:

| File                          | Responsibility                     |
| ----------------------------- | ---------------------------------- |
| `ci.yml`                      | Application CI                     |
| `cd.yml`                      | Application deployment             |
| `terraform-validate.yml`      | Terraform syntax/config validation |
| `terraform-plan.yml`          | Terraform PR plans                 |
| `terraform-apply.yml`         | Controlled Terraform deployment    |
| `terraform-drift.yml`         | Detect infrastructure drift        |
| `terraform-state-migrate.yml` | One-time state migration           |

---

# 14. CI and CD are now clearly separated

This is the part I especially want you to understand.

## Application CI

```text
.github/workflows/ci.yml
```

```text
NestJS
  ↓
npm ci
  ↓
lint
  ↓
test
  ↓
build
```

No AWS infrastructure changes.

---

## Application CD

```text
.github/workflows/cd.yml
```

```text
Docker
   ↓
ECR
   ↓
ECS
   ↓
NestJS running
```

This deploys the application.

---

## Infrastructure CI

```text
terraform-validate.yml
terraform-plan.yml
```

```text
Terraform
   ↓
validate
   ↓
plan
```

No infrastructure modification.

---

## Infrastructure CD

```text
terraform-apply.yml
```

```text
Terraform
   ↓
AWS infrastructure
```

This modifies:

```text
VPC
ECR
IAM
ECS
ALB
RDS
CloudWatch
etc.
```

---

# 15. The complete architecture

```text
                         GitHub
                            │
              ┌─────────────┴─────────────┐
              │                           │
              ▼                           ▼
       APPLICATION                    TERRAFORM
          CODE                           CODE
              │                           │
              ▼                           ▼
           ci.yml              terraform-validate.yml
              │                           │
              ▼                           ▼
          Tests/Build                Validation
              │                           │
              ▼                           ▼
           cd.yml                terraform-plan.yml
              │                           │
              ▼                           ▼
             ECR                         Plan
              │                           │
              ▼                           ▼
             ECS                     Code Review
              │                           │
              │                           ▼
              │                  terraform-apply.yml
              │                           │
              │                           ▼
              │                         AWS
              │
              ▼
        NestJS Application
```

---

# 16. One important correction to our earlier CD workflow

The first CD example I gave has:

```bash
aws ecs update-service \
  --cluster "$ECS_CLUSTER" \
  --service "$ECS_SERVICE" \
  --force-new-deployment
```

That **does not actually change the image tag by itself**.

It only tells ECS:

> Start a new deployment using the task definition currently configured.

For a proper ECR → ECS deployment, the CD pipeline should eventually:

```text
Build image
    ↓
Push image to ECR
    ↓
Get current ECS task definition
    ↓
Replace image
    ↓
Register new task definition
    ↓
Update ECS service
    ↓
Wait for deployment
```

We'll implement that properly when we build the application CD pipeline.

---

# 17. GitHub Environment variables

For each GitHub Environment, we'll eventually configure variables such as:

### `dev`

```text
AWS_REGION
TERRAFORM_ROLE_ARN
AWS_DEPLOY_ROLE_ARN
ECR_REPOSITORY
ECS_CLUSTER
ECS_SERVICE
```

### `stage`

Same names, but stage values.

### `prod`

Same names, but production values.

So your workflow doesn't contain:

```text
123456789012
specific production role ARN
specific production service
```

Instead:

```yaml
${{ vars.TERRAFORM_ROLE_ARN }}
${{ vars.AWS_REGION }}
${{ vars.ECS_CLUSTER }}
```

The GitHub Environment supplies the correct values.

---

# 18. Final directory structure

Your infrastructure repository should now look roughly like:

```text
ai-engineering-platform/
│
├── .github/
│   └── workflows/
│       │
│       ├── ci.yml
│       ├── cd.yml
│       │
│       ├── terraform-validate.yml
│       ├── terraform-plan.yml
│       ├── terraform-apply.yml
│       ├── terraform-drift.yml
│       └── terraform-state-migrate.yml
│
├── apps/
│   └── api/
│
├── packages/
│
└── infra/
    └── terraform/
        │
        ├── modules/
        │   ├── network/
        │   ├── compute/
        │   ├── iam/
        │   └── data/
        │
        └── envs/
            ├── dev/
            ├── stage/
            └── prod/
```

This gives us a clean separation:

```text
CI/CD
│
├── Application
│   ├── ci.yml
│   └── cd.yml
│
└── Infrastructure
    ├── validate
    ├── plan
    ├── apply
    ├── drift
    └── migration
```

**One thing I would do before actually enabling these workflows:** make sure the remote Terraform backend and the environment-specific OIDC IAM roles are finalized. Otherwise `terraform plan`/`apply` can authenticate but still point at the wrong state or AWS environment.
