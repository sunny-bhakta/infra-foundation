# Step 16 — Stage/Prod Promotion

## 1. What does "promotion" mean?

Suppose we make a Terraform change.

We don't want to immediately send it to production.

Instead:

```text
Development
     ↓
   Stage
     ↓
 Production
```

This movement is called **promotion**.

Think of it like testing software.

```text
Developer
   ↓
Dev
   ↓
Stage
   ↓
Prod
```

Each environment gives us another safety checkpoint.

---

# 2. Why have three environments?

We have:

```text
dev
stage
prod
```

### Dev

Used for development.

```text
Developer changes
       ↓
      Dev
```

Mistakes are relatively inexpensive here.

### Stage

Used to test something closer to production.

```text
Dev
 ↓
Stage
```

We can verify:

* Terraform changes
* ECS
* RDS
* networking
* application deployment
* configuration

### Production

Real users and real workloads.

```text
Stage
  ↓
Prod
```

This should have the strongest controls.

---

# 3. The important concept

We should **not** think:

```text
Run Terraform three times randomly.
```

Instead:

```text
Same change
    │
    ▼
   Dev
    │
    ▼
  Stage
    │
    ▼
   Prod
```

Each environment is a controlled step.

---

# 4. GitHub Environments

GitHub has a feature called:

> **Environments**

We create:

```text
GitHub Repository
│
└── Environments
    ├── dev
    ├── stage
    └── prod
```

Each environment can have its own:

* approvals
* secrets
* variables
* deployment protection rules

---

# 5. Why is `prod` special?

Imagine somebody accidentally runs:

```text
Terraform Apply → production
```

We don't want production infrastructure changing immediately.

Instead:

```text
Terraform Apply
      ↓
GitHub checks "prod"
      ↓
Approval required
      ↓
Human approves
      ↓
Terraform continues
```

---

# 6. Configure the environments

Go to your GitHub repository:

```text
Settings
   ↓
Environments
```

Create:

```text
dev
stage
prod
```

---

# 7. Dev environment

For:

```text
dev
```

we can keep things simple.

For example:

```text
Required reviewers: none
```

So:

```text
Apply dev
   ↓
Runs
```

No manual approval.

---

# 8. Stage environment

For:

```text
stage
```

we can require approval.

For example:

```text
Required reviewers:
    Your team
```

Then:

```text
Apply stage
      ↓
Waiting for approval
      ↓
Reviewer approves
      ↓
Terraform Apply
```

---

# 9. Production environment

Production should be stricter.

For:

```text
prod
```

configure:

```text
Required reviewers
```

For example:

```text
Production deployment
        ↓
Required reviewer
        ↓
Approve
```

You can also restrict which branches are allowed to deploy.

For example:

```text
main
```

or a protected release branch.

---

# 10. Why environment approvals are better than Terraform approval

You might wonder:

> Why not just run `terraform apply` and let Terraform ask for confirmation?

Because GitHub Actions is automated.

We want the **deployment system** to control approval.

So:

```text
GitHub
  │
  ├── Plan
  ├── Approval
  └── Apply
```

is cleaner than:

```text
GitHub
  │
  └── Terraform waiting for "yes"
```

---

# 11. Our workflow

We can structure promotion like this:

```text
Pull Request
     ↓
Terraform Plan
     ↓
Merge
     ↓
Dev Apply
     ↓
Test
     ↓
Stage Apply
     ↓
Approval
     ↓
Test
     ↓
Prod Apply
     ↓
Approval
     ↓
Production
```

---

# 12. There are two possible promotion models

This is important.

### Model A — Manual promotion

Someone explicitly chooses:

```text
Run workflow
Environment = dev
```

then later:

```text
Environment = stage
```

then:

```text
Environment = prod
```

This is the simplest approach while learning.

---

### Model B — Automatic promotion

GitHub can automatically move forward:

```text
Dev
 ↓
tests
 ↓
Stage
 ↓
approval
 ↓
Prod
```

For your project, I recommend starting with **manual promotion**.

Why?

Because you're learning Terraform and AWS at the same time.

It gives you more control.

---

# 13. Our recommended beginner architecture

Use:

```text
terraform-plan.yml
```

for PRs.

Then:

```text
terraform-apply.yml
```

for controlled deployments.

The apply workflow accepts:

```text
environment
```

with:

```text
dev
stage
prod
```

So:

```text
GitHub Actions
      │
      ├── dev
      ├── stage
      └── prod
```

---

# 14. GitHub workflow

Our apply workflow can have:

```yaml
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
```

Then:

```yaml
environment: ${{ inputs.environment }}
```

This is extremely important.

It tells GitHub:

> Use the GitHub Environment selected by the person running this workflow.

---

# 15. What happens for dev?

You choose:

```text
environment = dev
```

GitHub sees:

```text
environment: dev
```

Then:

```text
Terraform
    ↓
AWS dev
```

No approval required.

---

# 16. What happens for stage?

You choose:

```text
environment = stage
```

GitHub sees:

```text
environment: stage
```

Then:

```text
Terraform
    ↓
GitHub Stage Environment
    ↓
Approval
    ↓
AWS stage
```

---

# 17. What happens for prod?

You choose:

```text
environment = prod
```

Then:

```text
Terraform
    ↓
GitHub Prod Environment
    ↓
⏸ Waiting for approval
    ↓
Human approves
    ↓
Terraform
    ↓
AWS production
```

That's our production safety gate.

---

# 18. Why this is called a "gate"

A gate means:

> Something must happen before the pipeline can continue.

For example:

```text
Stage
   ↓
[ APPROVAL ]
   ↓
Prod
```

The approval is a deployment gate.

---

# 19. Branch protection

Environment approval is one layer.

We should also protect `main`.

For example:

```text
feature branch
      ↓
Pull Request
      ↓
review
      ↓
CI passes
      ↓
main
```

Don't allow developers to simply do:

```text
git push main
```

without checks.

---

# 20. Production should combine protections

Our production safety model becomes:

```text
              Pull Request
                    ↓
              Terraform Plan
                    ↓
               Code Review
                    ↓
              Branch Protection
                    ↓
                  Merge
                    ↓
             Apply Workflow
                    ↓
             Prod Environment
                    ↓
            Required Approval
                    ↓
                 OIDC
                    ↓
               AWS IAM Role
                    ↓
              Terraform Apply
```


---
