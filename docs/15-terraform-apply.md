
# Step 15 — Terraform Apply CI


Plan:

> What are we going to do?

Apply:

> Actually do it.

---

# 19. Apply workflow

Create:

```text
.github/workflows/terraform-apply.yml
```

For our first beginner-friendly implementation:

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
          role-to-assume: ${{ secrets.TERRAFORM_ROLE_ARN }}
          aws-region: ap-south-1

      - name: Terraform Plan
        run: terraform plan -out=tfplan

      - name: Terraform Apply
        run: terraform apply -auto-approve tfplan
```

---

# 20. Why `workflow_dispatch`?

```yaml
on:
  workflow_dispatch:
```

means:

> A person must manually start this workflow from GitHub.

That's useful for infrastructure.

Instead of:

```text
PR merged
   │
   ▼
AWS immediately changes
```

we have:

```text
PR merged
   │
   ▼
Someone intentionally starts Apply
   │
   ▼
AWS changes
```

That's safer while we're learning and is also useful for controlled environments.

---

# 21. The environment input

We have:

```yaml
environment:
  options:
    - dev
    - stage
    - prod
```

When someone runs the workflow, GitHub provides:

```text
Environment:
[ dev ▼ ]
```

or:

```text
Environment:
[ stage ▼ ]
```

or:

```text
Environment:
[ prod ▼ ]
```

---

# 22. Why GitHub Environments are useful

GitHub supports environments such as:

```text
dev
stage
prod
```

We can configure rules for each.

For example:

```text
dev
 └── no approval

stage
 └── 1 reviewer

prod
 └── required reviewer(s)
```

So production can require human approval.

---

# 23. Production flow

Eventually we want:

```text
Developer
   │
   ▼
Pull Request
   │
   ▼
Terraform Plan
   │
   ▼
Code Review
   │
   ▼
Merge
   │
   ▼
Apply workflow
   │
   ▼
GitHub "prod" environment
   │
   ▼
Approval required
   │
   ▼
Terraform Apply
   │
   ▼
AWS
```

This is much safer than:

```text
git push
   │
   ▼
AWS production
```

---

# 24. Plan vs Apply

This is the key distinction:

| Command              | Purpose                | Changes AWS? |
| -------------------- | ---------------------- | ------------ |
| `terraform fmt`      | Format code            | ❌            |
| `terraform validate` | Validate configuration | ❌            |
| `terraform init`     | Initialize Terraform   | ❌*           |
| `terraform plan`     | Preview changes        | ❌            |
| `terraform apply`    | Execute changes        | ✅            |

* `terraform init` can interact with the backend/provider systems, but it does not apply infrastructure changes.

---

# 25. Why do we plan again during Apply?

You might wonder:

> We already ran `terraform plan` in the PR. Why run it again?

Because the world can change between PR and apply.

For example:

```text
Monday
PR plan
   │
   ▼
0 to add
2 to change
```

Then Tuesday:

```text
Someone changed AWS
```

or:

```text
Another Terraform deployment happened
```

Therefore the old plan may no longer represent reality.

So our Apply workflow should generate a **fresh plan**:

```text
Apply workflow
      │
      ▼
terraform plan -out=tfplan
      │
      ▼
terraform apply tfplan
```

This is much safer.

---

# 26. Why `-out=tfplan`?

Normally:

```powershell
terraform plan
```

just displays the plan.

With:

```powershell
terraform plan -out=tfplan
```

Terraform saves the plan:

```text
tfplan
```

Then:

```powershell
terraform apply tfplan
```

means:

> Apply exactly this generated plan.

So:

```text
terraform plan
       │
       ▼
    tfplan
       │
       ▼
terraform apply tfplan
```

---

# 27. Why not simply do this?

You might see:

```yaml
terraform apply -auto-approve
```

This is technically possible.

But for our workflow:

```text
terraform plan -out=tfplan
terraform apply tfplan
```

is clearer and safer because we explicitly create the plan that will be applied.

---

# 28. What does `-auto-approve` mean?

Normally Terraform asks:

```text
Do you want to perform these actions?

Only 'yes' will be accepted to approve.
```

GitHub Actions can't sit there waiting for you to type:

```text
yes
```

So:

```text
-auto-approve
```

means:

> Don't ask for interactive confirmation.

But remember:

**GitHub Environment approval is separate.**

We can have:

```text
GitHub approval
       ↓
Terraform plan
       ↓
Terraform apply -auto-approve
```

The human approval happens at the GitHub level.

---

# 29. Add concurrency

This is a very important production feature.

Imagine:

```text
Workflow A
   │
   └── terraform apply
```

and at the same time:

```text
Workflow B
   │
   └── terraform apply
```

Both modify the same environment.

That's dangerous.

We can add:

```yaml
concurrency:
  group: terraform-${{ inputs.environment }}
  cancel-in-progress: false
```

Now:

```text
dev
 ├── Apply A
 └── Apply B
```

Apply B waits instead of running at the same time.

---

# 30. Apply workflow with concurrency

So I'd change the beginning to:

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
  group: terraform-${{ inputs.environment }}
  cancel-in-progress: false
```

This gives us:

```text
dev → one Terraform operation at a time

stage → one Terraform operation at a time

prod → one Terraform operation at a time
```

---

# 31. GitHub Environment approval

For production, configure GitHub:

```text
Repository
   │
   ▼
Settings
   │
   ▼
Environments
   │
   ▼
prod
```

Then configure:

```text
Required reviewers
```

For example:

```text
prod
 │
 └── Required reviewer: you/team
```

Now when Apply reaches:

```text
environment: prod
```

GitHub pauses:

```text
Waiting for approval
```

No Terraform apply happens yet.

---

# 32. Very important security model

Now combine everything we've learned.

```text
                  GitHub
                     │
                     ▼
               Pull Request
                     │
                     ▼
              Terraform Plan
                     │
                  review
                     │
                     ▼
                   Merge
                     │
                     ▼
             Terraform Apply
                     │
                GitHub Env
                     │
                approval
                     │
                     ▼
                  OIDC
                     │
                     ▼
                  AWS IAM
                     │
                     ▼
              Terraform Role
                     │
                     ▼
                   AWS
```

That's a production-style workflow.

---

# 33. Dev vs Stage vs Prod

We should treat them differently.

### Dev

```text
PR
 ↓
Plan
 ↓
Merge
 ↓
Apply
```

Minimal approval.

### Stage

```text
PR
 ↓
Plan
 ↓
Merge
 ↓
Apply
 ↓
Optional approval
```

### Production

```text
PR
 ↓
Plan
 ↓
Review
 ↓
Merge
 ↓
Apply
 ↓
Required approval
 ↓
Terraform
 ↓
AWS
```

---

# 34. One issue with our beginner workflow

There is one thing I don't want you to misunderstand.

This:

```yaml
secrets.TERRAFORM_ROLE_ARN
```

isn't necessarily the best long-term design if we're using GitHub Environments.

We can eventually configure the role ARN as an **environment-level variable** rather than putting the same value everywhere.

For example:

```text
GitHub
└── Environments
    ├── dev
    │   └── AWS_ROLE_ARN
    │
    ├── stage
    │   └── AWS_ROLE_ARN
    │
    └── prod
        └── AWS_ROLE_ARN
```

Then each environment uses its own IAM role.

---

# 35. Better final architecture

Eventually:

```text
GitHub
│
├── dev
│    │
│    └── terraform-dev
│
├── stage
│    │
│    └── terraform-stage
│
└── prod
     │
     └── terraform-prod
```

And:

```text
terraform-dev
     │
     └── AWS dev resources

terraform-stage
     │
     └── AWS stage resources

terraform-prod
     │
     └── AWS production resources
```

This prevents a dev workflow from accidentally using the production role.

---

# 36. What happens when you open a PR?

Let's walk through a real example.

You change:

```hcl
desired_count = 2
```

to:

```hcl
desired_count = 3
```

You push the branch:

```text
feature/increase-ecs-capacity
```

GitHub creates:

```text
Pull Request
```

Then:

```text
terraform-plan.yml
       │
       ├── checkout
       ├── setup Terraform
       ├── fmt
       ├── init
       ├── validate
       ├── OIDC → AWS
       └── plan
```

GitHub reports:

```text
Terraform Plan
✓ fmt
✓ init
✓ validate
✓ plan

Plan: 0 to add, 1 to change, 0 to destroy.
```

Now the reviewer knows:

> This PR changes ECS desired count from 2 to 3.

---

# 37. Then merge

Once approved:

```text
Pull Request
     │
     ▼
Merge
```

Nothing necessarily applies automatically if we're using the manual apply workflow.

Someone goes to:

```text
GitHub
 → Actions
 → Terraform Apply
 → Run workflow
```

and selects:

```text
environment = dev
```

Then:

```text
Terraform init
       ↓
Terraform validate
       ↓
OIDC
       ↓
Terraform plan
       ↓
Terraform apply
```

---

# 38. Production

For:

```text
environment = prod
```

GitHub can stop at:

```text
Waiting for approval
```

Then an authorized reviewer approves.

Only then:

```text
terraform apply
```

runs.

---

# 39. Why this is better than local Terraform

Without CI:

```text
Developer laptop
   │
   └── terraform apply
          │
          ▼
         AWS
```

Problems:

* Who ran it?
* Which credentials?
* Which Terraform version?
* Which code?
* Was it reviewed?
* Was there a plan?
* Could two people run apply simultaneously?

With CI:

```text
GitHub
 │
 ├── Code
 ├── Review
 ├── Plan
 ├── Approval
 ├── OIDC
 └── Apply
```

Much more controlled.

---

# 40. What about your "GitHub Actions only" requirement?

This design satisfies it.

After we finish the migration:

```text
Local machine
     │
     └── Terraform apply ❌

GitHub Actions
     │
     └── Terraform apply ✅
```

Your laptop is used for:

```text
code
commit
push
```

GitHub Actions handles:

```text
init
validate
plan
apply
```

---

# 41. The two workflows we now have

```text
.github/workflows/
│
├── terraform-plan.yml
│
└── terraform-apply.yml
```

### Plan

```text
PR
 │
 ▼
fmt
 │
 ▼
init
 │
 ▼
validate
 │
 ▼
OIDC
 │
 ▼
plan
```

### Apply

```text
Manual trigger
 │
 ▼
choose environment
 │
 ▼
init
 │
 ▼
validate
 │
 ▼
OIDC
 │
 ▼
fresh plan
 │
 ▼
approval if required
 │
 ▼
apply
```

---

# 42. The big picture

At this point, you should understand this entire flow:

```text
                    DEVELOPER
                        │
                        │ git push
                        ▼
                   GITHUB REPO
                        │
                        ▼
                 PULL REQUEST
                        │
                        ▼
             ┌────────────────────┐
             │ Terraform Plan CI  │
             │                    │
             │ fmt                │
             │ init               │
             │ validate           │
             │ plan               │
             └─────────┬──────────┘
                       │
                       ▼
                   CODE REVIEW
                       │
                       ▼
                     MERGE
                       │
                       ▼
             ┌────────────────────┐
             │ Terraform Apply CI │
             │                    │
             │ fresh plan         │
             │ approval           │
             │ apply              │
             └─────────┬──────────┘
                       │
                       │ OIDC
                       ▼
                  AWS IAM ROLE
                       │
                       ▼
                ┌──────────────┐
                │     AWS      │
                │              │
                │ VPC          │
                │ ECR          │
                │ ECS          │
                │ ALB          │
                │ RDS          │
                └──────────────┘
```

## The most important rule

Keep this distinction in your head:

> **Plan tells us what Terraform wants to do. Apply actually changes AWS.**

And our safety chain is:

> **PR → Plan → Review → Merge → Apply → Approval → AWS**

That is the foundation of a controlled Terraform CI/CD setup.
