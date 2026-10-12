
# Drift Detection

## What is drift?

Terraform thinks infrastructure looks like:

```text
Terraform
   ↓
VPC
ECS
RDS
ALB
```

But someone manually changes AWS:

```text
AWS Console
   ↓
Change ECS desired count
```

Now:

```text
Terraform state/config
        ≠
AWS
```

That difference is called:

> **Drift**

---

# 21. Simple example

Terraform says:

```hcl
desired_count = 2
```

AWS currently has:

```text
desired count = 2
```

Everything is good:

```text
Terraform = AWS
```

Then somebody manually changes ECS:

```text
AWS desired count = 5
```

Now:

```text
Terraform = 2
AWS       = 5
```

We have drift.

---

# 22. Why is drift dangerous?

Imagine nobody notices.

Terraform believes:

```text
ECS = 2
```

AWS actually has:

```text
ECS = 5
```

Later someone runs Terraform.

Terraform might say:

```text
~ desired_count: 5 → 2
```

and change AWS back.

Or the opposite can happen depending on what is managed and how the configuration/state changed.

The important point:

> Your infrastructure no longer matches what your Terraform code says it should be.

---

# 23. How do we detect drift?

We can run:

```text
terraform plan
```

periodically.

For example:

```text
Every night
      ↓
GitHub Actions
      ↓
Terraform Plan
      ↓
Compare Terraform with AWS
```

If Terraform reports changes, we know something may have drifted.

---

# 24. Drift workflow

Create:

```text
.github/workflows/terraform-drift.yml
```

A beginner-friendly version:

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
    name: Detect Drift - Dev
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

      - name: Terraform Init
        run: terraform init

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.TERRAFORM_ROLE_ARN }}
          aws-region: ap-south-1

      - name: Terraform Plan
        run: terraform plan -detailed-exitcode
```

---

# 25. What is the schedule?

This:

```yaml
schedule:
  - cron: "0 2 * * *"
```

means GitHub periodically starts the workflow.

Cron uses:

```text
minute hour day month weekday
```

So:

```text
0 2 * * *
```

means approximately:

```text
02:00 UTC
```

GitHub Actions schedules use UTC.

You don't need to memorize cron yet.

---

# 26. Why `workflow_dispatch` too?

We also have:

```yaml
workflow_dispatch:
```

This means:

> I can manually run drift detection whenever I want.

So we have:

```text
Nightly
   ↓
automatic drift check
```

and:

```text
Manual
   ↓
drift check
```

Both are useful.

---

# 27. The important command

We're using:

```powershell
terraform plan -detailed-exitcode
```

This gives Terraform different exit codes.

### Exit code 0

```text
No changes
```

Meaning:

```text
Terraform ≈ AWS
```

Good.

---

### Exit code 2

```text
Changes detected
```

Potential drift.

For example:

```text
Terraform wants:
desired_count = 2

AWS currently:
desired_count = 5
```

Terraform returns:

```text
2
```

---

### Exit code 1

```text
Error
```

For example:

```text
AWS credentials invalid
```

or:

```text
Terraform configuration error
```

---

# 28. Why this matters in CI

We can tell GitHub:

```text
0 = no drift
2 = drift
1 = failure
```

Then GitHub can alert us.

---

# 29. We should not automatically fix drift

This is very important.

Don't do:

```text
Drift detected
      ↓
terraform apply
```

automatically.

That can be dangerous.

Imagine someone manually changed:

```text
RDS
```

and our automation immediately changes it back.

We want:

```text
Drift detected
      ↓
Alert
      ↓
Human investigates
      ↓
Decision
```

Then decide:

```text
Option A
Update Terraform

OR

Option B
Apply Terraform intentionally
```

---

# 30. Example drift situation

Terraform:

```hcl
instance_class = "db.t3.micro"
```

Someone manually changes AWS to:

```text
db.t3.small
```

Nightly workflow:

```text
terraform plan
```

reports:

```text
~ instance_class:
    "db.t3.small" → "db.t3.micro"
```

We now know:

```text
AWS ≠ Terraform
```

We investigate.

Maybe the manual change was intentional.

Then we update Terraform:

```hcl
instance_class = "db.t3.small"
```

and commit it.

That's the correct Infrastructure-as-Code workflow.

---

# 31. Drift detection and state

There's an important concept here.

Terraform uses:

```text
Terraform configuration
        +
Terraform state
        +
AWS APIs
```

to determine what should happen.

So we want our state stored safely.

That's one reason the next-level architecture uses remote state:

```text
Terraform
   ↓
S3 backend
   ↓
Terraform state
```

rather than relying on:

```text
terraform.tfstate
```

on someone's laptop.

---

# 32. Why remote state matters even more now

Imagine:

```text
Developer A
     │
     ▼
Laptop
     │
     └── terraform.tfstate
```

Then GitHub Actions runs:

```text
GitHub
   │
   ▼
Terraform
```

Which state does GitHub use?

If the state is only on your laptop:

```text
GitHub ❌
```

Therefore, for GitHub Actions-only Terraform:

```text
Terraform
   │
   ▼
Remote Backend
   │
   ▼
Shared State
```

is essential.

---

# 33. State locking

Another important concept.

Suppose two Terraform jobs run simultaneously:

```text
Job A
  ↓
terraform apply

Job B
  ↓
terraform apply
```

They could interfere with each other.

Remote state + locking helps prevent concurrent state modifications.

We also added GitHub concurrency:

```yaml
concurrency:
  group: terraform-${{ inputs.environment }}
```

So we have protection at two levels:

```text
GitHub concurrency
        +
Terraform backend/state locking
```

That's much safer.

---

# 34. Promotion + drift together

Now let's combine Step 16 and Step 17.

```text
                 GitHub
                    │
          ┌─────────┴─────────┐
          │                   │
          ▼                   ▼
      Pull Request        Scheduled
          │                   │
          ▼                   ▼
   Terraform Plan       Drift Detection
          │                   │
          ▼                   ▼
       Review             Drift?
          │                   │
          ▼                   ▼
         Dev              Alert
          │
          ▼
       Stage
          │
      Approval
          │
          ▼
        Prod
          │
      Approval
          │
          ▼
        AWS
```

---

# 35. Recommended workflow structure

At this point your GitHub Actions directory should eventually look like:

```text
.github/
└── workflows/
    │
    ├── terraform-validate.yml
    │
    ├── terraform-plan.yml
    │
    ├── terraform-apply.yml
    │
    ├── terraform-drift.yml
    │
    └── terraform-state-migrate.yml
```

Their responsibilities are different.

| Workflow                      | Purpose                              |
| ----------------------------- | ------------------------------------ |
| `terraform-validate.yml`      | Check Terraform syntax/configuration |
| `terraform-plan.yml`          | Show proposed changes on PR          |
| `terraform-apply.yml`         | Actually change AWS                  |
| `terraform-drift.yml`         | Detect changes outside Terraform     |
| `terraform-state-migrate.yml` | One-time state migration             |

---

# 36. The complete lifecycle

Now imagine you add a new AWS resource.

### Step 1

You modify Terraform:

```text
modules/compute/main.tf
```

### Step 2

Open PR:

```text
feature/new-resource
        ↓
PR
```

### Step 3

Plan runs:

```text
terraform plan
```

### Step 4

Reviewer sees:

```text
2 to add
0 to change
0 to destroy
```

### Step 5

PR is merged.

### Step 6

Deploy to dev:

```text
dev
 ↓
apply
```

### Step 7

Test.

### Step 8

Promote to stage:

```text
stage
 ↓
approval
 ↓
apply
```

### Step 9

Test again.

### Step 10

Promote to production:

```text
prod
 ↓
approval
 ↓
apply
```

### Step 11

Every night:

```text
drift detection
```

checks:

```text
Terraform ↔ AWS
```

---

# 37. The golden rule

For our project, I want you to remember this:

```text
Terraform code
      ↓
Pull Request
      ↓
Plan
      ↓
Review
      ↓
Dev
      ↓
Stage
      ↓
Approval
      ↓
Prod
```

And separately:

```text
AWS
 │
 └── someone manually changes something
             ↓
         Drift Detection
             ↓
           Alert
             ↓
       Human investigates
```

**Drift detection should detect, not automatically "fight" the person who changed AWS.**

---

# 38. Where we are now

We've covered:

|      # | Topic                    | Main idea                                |
| -----: | ------------------------ | ---------------------------------------- |
|     14 | Terraform Plan CI        | See changes before applying              |
|     15 | Terraform Apply CI       | Controlled infrastructure changes        |
| **16** | **Stage/Prod Promotion** | **Dev → Stage → Prod with approvals**    |
| **17** | **Drift Detection**      | **Detect AWS changes outside Terraform** |

The next major piece is **state management** if we haven't finalized it yet:

```text
Terraform
    ↓
S3 Remote State
    +
State Locking
```

That is particularly important because your stated end goal is **GitHub Actions-only Terraform**.
