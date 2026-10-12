# Terraform Plan CI

## What are we trying to achieve?

Imagine you change Terraform:

```text
Developer
   │
   │ changes infrastructure
   ▼
GitHub Pull Request
   │
   ▼
Terraform Plan
   │
   ├── What will be created?
   ├── What will be changed?
   └── What will be destroyed?
```

We want GitHub to automatically check the proposed infrastructure **before anyone applies it**.

That's what Terraform Plan CI does.

---

# 1. What is CI?

CI means:

> **Continuous Integration**

In simple terms:

> Whenever someone creates or updates a Pull Request, automatically run checks.

For Terraform:

```text
Pull Request
     │
     ▼
GitHub Actions
     │
     ├── terraform fmt
     ├── terraform init
     ├── terraform validate
     └── terraform plan
```

---

# 2. Why `plan`?

Remember:

```powershell
terraform plan
```

does **not** change AWS.

It only asks:

> "Terraform, if I applied this configuration, what would you do?"

Example:

```text
Plan: 2 to add, 1 to change, 0 to destroy.
```

That's extremely useful during code review.

---

# 3. Example

Suppose you change:

```hcl
desired_count = 2
```

to:

```hcl
desired_count = 3
```

Your Pull Request might produce:

```text
Terraform Plan

ECS service:
desired count

2 → 3
```

A reviewer can see the impact before approving.

---

# 4. Another example

Suppose you accidentally change:

```hcl
vpc_id = ...
```

and Terraform wants to destroy something important.

The plan could show:

```text
Plan: 1 to add, 0 to change, 7 to destroy.
```

That's a huge warning.

You can stop the PR before anything reaches AWS.

---

# 5. Our workflow

Create:

```text
.github/
└── workflows/
    └── terraform-plan.yml
```

A beginner-friendly starting version:

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

jobs:
  plan:
    name: Terraform Plan - Dev
    runs-on: ubuntu-latest

    environment: dev

    defaults:
      run:
        working-directory: infra/terraform/envs/dev

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3

      - name: Terraform Format Check
        run: terraform fmt -check -recursive

      - name: Terraform Init
        run: terraform init

      - name: Terraform Validate
        run: terraform validate

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.TERRAFORM_ROLE_ARN }}
          aws-region: ap-south-1

      - name: Terraform Plan
        run: terraform plan
```

Let's understand every part.

---

# 6. Workflow name

```yaml
name: Terraform Plan
```

This is simply the name you'll see in GitHub Actions.

---

# 7. When should it run?

```yaml
on:
  pull_request:
```

This means:

```text
Developer
   │
   ▼
Pull Request
   │
   ▼
Terraform Plan
```

It doesn't wait for someone to manually run it.

---

# 8. Path filter

```yaml
paths:
  - "infra/terraform/**"
```

This means:

> Run this workflow when Terraform files change.

For example:

```text
infra/terraform/modules/network/main.tf
```

will trigger it.

But changing:

```text
README.md
```

doesn't need a Terraform plan.

---

# 9. Permissions

```yaml
permissions:
  contents: read
  id-token: write
```

Remember our OIDC discussion?

```text
id-token: write
```

allows GitHub Actions to request an OIDC token.

Then:

```text
GitHub
   │
   ▼
OIDC
   │
   ▼
AWS IAM Role
```

---

# 10. Working directory

```yaml
defaults:
  run:
    working-directory: infra/terraform/envs/dev
```

This is important because our Terraform root is:

```text
infra/terraform/envs/dev
```

Therefore:

```yaml
terraform init
```

actually runs inside:

```text
infra/terraform/envs/dev
```

---

# 11. Checkout

```yaml
- name: Checkout
  uses: actions/checkout@v4
```

GitHub Actions starts with a fresh runner.

It doesn't automatically have your repository files.

Checkout means:

> Download the repository code into the runner.

---

# 12. Setup Terraform

```yaml
- name: Setup Terraform
  uses: hashicorp/setup-terraform@v3
```

This installs/configures Terraform on the GitHub Actions runner.

Then the runner can execute:

```text
terraform
```

commands.

---

# 13. Format check

```yaml
terraform fmt -check -recursive
```

This checks whether Terraform files follow Terraform formatting rules.

For example:

```hcl
resource "aws_s3_bucket" "example" {
name = "test"
}
```

would be formatted properly by:

```powershell
terraform fmt
```

CI doesn't modify the code.

It checks it.

That's why we use:

```text
-check
```

---

# 14. Terraform init

```yaml
terraform init
```

This prepares Terraform.

It downloads:

```text
Providers
Modules
Backend configuration
```

For example:

```text
Terraform
   │
   ├── AWS provider
   ├── Random provider
   └── modules
```

---

# 15. Terraform validate

```yaml
terraform validate
```

This checks whether the Terraform configuration is structurally valid.

For example:

```text
Variable doesn't exist
        ↓
validate ❌
```

It can catch configuration mistakes before plan.

---

# 16. Configure AWS

Now:

```yaml
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v4
```

This is where our previous **GitHub OIDC** lesson becomes useful.

We're not doing:

```text
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
```

Instead:

```text
GitHub
   │
   │ OIDC
   ▼
AWS IAM
   │
   ▼
Terraform role
```

---

# 17. Terraform plan

Finally:

```yaml
terraform plan
```

Terraform compares:

```text
Terraform configuration
        +
Terraform state
        +
AWS
        ↓
Proposed changes
```

Example:

```text
Plan: 1 to add, 1 to change, 0 to destroy.
```

---

# 18. Important point: Plan doesn't deploy

This is one of the most important concepts.

```text
terraform plan
```

means:

> Show me what would happen.

It does **not** mean:

> Do it.

So:

```text
PR
 │
 ▼
Plan
 │
 ▼
Review
```

No infrastructure deployment happens just because someone opens a PR.

---
