# GitHub OIDC

## Goal

Right now, our architecture is:

```text
GitHub
   │
   │
   ▼
GitHub Actions
   │
   ▼
AWS
   │
   ├── ECR
   ├── ECS
   ├── RDS
   └── ...
```

The question is:

> **How can GitHub Actions authenticate to AWS without storing an AWS access key and secret key?**

The answer is:

> **GitHub OIDC + AWS IAM Role**

The final flow will be:

```text
GitHub Actions
      │
      │ OIDC token
      ▼
AWS IAM
      │
      │ verifies GitHub
      ▼
IAM Role
      │
      │ temporary credentials
      ▼
AWS
```

No permanent AWS access keys are required.

---

# 1. First understand the old approach

Before OIDC, people commonly did this:

```text
GitHub Secrets
│
├── AWS_ACCESS_KEY_ID
└── AWS_SECRET_ACCESS_KEY
```

Then GitHub Actions would use them:

```yaml
env:
  AWS_ACCESS_KEY_ID: ...
  AWS_SECRET_ACCESS_KEY: ...
```

This works, but it's not ideal.

Why?

Because those are **long-lived credentials**.

If they are compromised, the attacker may be able to use them until they are revoked/rotated.

---

# 2. What do we want instead?

We want:

```text
GitHub Actions
      │
      │ "I am GitHub workflow X"
      ▼
AWS
      │
      │ verify identity
      ▼
IAM Role
      │
      │ temporary credentials
      ▼
AWS resources
```

The credentials are temporary.

That's the major advantage.

---

# 3. What is OIDC?

OIDC stands for:

> **OpenID Connect**

You don't need to understand the entire OIDC protocol right now.

For our purposes, think of it as:

> A secure way for GitHub to prove its identity to AWS.

GitHub can tell AWS:

```text
I am:
GitHub

Repository:
your-repository

Branch:
main

Workflow:
your-workflow
```

AWS then checks whether that GitHub identity is allowed to assume a particular IAM role.

---

# 4. The most important concept

GitHub doesn't directly get AWS permissions.

Instead:

```text
GitHub
   │
   ▼
OIDC Identity
   │
   ▼
IAM Role
   │
   ▼
Permissions
```

The IAM role determines what GitHub is actually allowed to do.

---

# 5. Think of it like an office badge

Imagine AWS is an office.

You don't give GitHub the master key.

Instead:

```text
GitHub
   │
   │ proves identity
   ▼
Reception
   │
   │ checks rules
   ▼
Temporary visitor badge
   │
   ▼
Allowed rooms
```

The IAM role is essentially that controlled permission.

---

# 6. Three things we need

To implement GitHub OIDC with AWS, we need:

```text
1. GitHub OIDC Provider
2. IAM Role
3. IAM Permissions
```

Let's understand each.

---

# 7. Part 1 — GitHub OIDC Provider

AWS needs to know:

> "I trust GitHub as an identity provider."

We create an IAM OIDC provider for GitHub.

Conceptually:

```text
AWS IAM
   │
   └── OIDC Provider
          │
          └── GitHub
```

The provider points to:

```text
https://token.actions.githubusercontent.com
```

You don't need to memorize that URL yet.

---

# 8. What does the provider do?

Suppose GitHub says:

```text
I'm GitHub Actions workflow from repository X.
```

AWS needs to know:

> Is this actually a GitHub-issued identity token?

The OIDC provider establishes that trust relationship.

---

# 9. Part 2 — IAM Role

Next we create a role.

For example:

```text
github-actions-dev
```

The role has two separate concepts:

```text
IAM Role
│
├── Trust Policy
│
└── Permissions Policy
```

This distinction is **very important**.

---

# 10. Trust policy

The trust policy answers:

> **Who is allowed to assume this role?**

For example:

```text
Only:
GitHub
+
our repository
+
dev branch
```

could be allowed.

So:

```text
GitHub repository
      │
      │ trusted
      ▼
github-actions-dev
```

---

# 11. Permissions policy

The permissions policy answers:

> **Once GitHub assumes the role, what can it do?**

For example:

```text
github-actions-dev
      │
      ├── ECR push
      ├── ECS update
      └── CloudWatch access
```

The trust policy and permission policy are different.

Remember:

```text
Trust policy
=
WHO can assume me?

Permissions
=
WHAT can they do?
```

---

# 12. Our architecture

For our project:

```text
                    GitHub
                       │
                       │ OIDC
                       ▼
                AWS IAM OIDC
                   Provider
                       │
                       ▼
              GitHub Actions Role
                       │
                 permissions
                       │
          ┌────────────┼────────────┐
          ▼            ▼            ▼
         ECR          ECS       Terraform
```

---

# 13. Why we're doing this now

Eventually our deployment should work like:

```text
Developer
    │
    ▼
git push
    │
    ▼
GitHub
    │
    ▼
GitHub Actions
    │
    ├── Build Docker image
    │
    ├── Push image → ECR
    │
    └── Deploy → ECS
```

GitHub needs AWS access for this.

OIDC gives it that access securely.

---

# 14. One important distinction: Terraform vs deployment

We actually have **two types of GitHub Actions access**.

### Infrastructure

Terraform needs to create things like:

```text
VPC
ECR
IAM
ECS
ALB
RDS
```

### Application deployment

GitHub Actions needs to:

```text
Build image
   ↓
Push ECR
   ↓
Update ECS
```

These shouldn't necessarily have identical permissions.

This is an important production principle.

---

# 15. Recommended role structure

For our project, I'd recommend eventually having:

```text
AWS IAM
│
├── terraform-dev
├── terraform-stage
├── terraform-prod
│
├── deploy-dev
├── deploy-stage
└── deploy-prod
```

Why?

Because infrastructure management and application deployment are different responsibilities.

For our beginner implementation, we'll first understand one role:

```text
github-actions-dev
```

Then we'll expand it.

---

# 16. Terraform module

We already have:

```text
infra/terraform/modules/iam/
```

This is exactly where our OIDC resources belong.

Structure:

```text
modules/
└── iam/
    ├── main.tf
    ├── variables.tf
    └── outputs.tf
```

---

# 17. Create GitHub OIDC provider

Inside:

```text
infra/terraform/modules/iam/main.tf
```

we can define:

```hcl
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]

  thumbprint_list = [
    "ffffffffffffffffffffffffffffffffffffffff"
  ]
}
```

### Important

Don't blindly use an old hard-coded thumbprint from a tutorial.

GitHub/AWS OIDC certificate handling has evolved, and AWS can validate the provider differently depending on the current setup.

For a current implementation, we should use the current AWS/GitHub-supported configuration rather than copying an outdated thumbprint.

The important concept is:

```text
AWS IAM
   │
   └── trusts GitHub OIDC
```

---

# 18. Trust policy

Now comes the most important part.

We need to tell AWS:

> Only GitHub Actions from my repository can assume this role.

We can create an IAM policy document:

```hcl
data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type = "Federated"

      identifiers = [
        aws_iam_openid_connect_provider.github.arn
      ]
    }

    actions = [
      "sts:AssumeRoleWithWebIdentity"
    ]

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"

      values = [
        "sts.amazonaws.com"
      ]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"

      values = [
        "repo:YOUR_GITHUB_ORG/YOUR_REPOSITORY:ref:refs/heads/main"
      ]
    }
  }
}
```

This is where security becomes interesting.

---

# 19. What is `aud`?

This:

```text
token.actions.githubusercontent.com:aud
```

means:

> Who is this token intended for?

We expect:

```text
sts.amazonaws.com
```

because GitHub is requesting AWS Security Token Service credentials.

---

# 20. What is `sub`?

This is even more important.

The subject can identify the GitHub repository and workflow context.

For example:

```text
repo:my-org/my-project:ref:refs/heads/main
```

means:

```text
GitHub
 └── repository
      └── my-org/my-project
            └── main branch
```

So we can say:

> Only this repository's main branch can assume this role.

---

# 21. Why branch restrictions matter

Suppose we didn't restrict the role.

Potentially:

```text
Any GitHub workflow
       │
       ▼
AWS Role
```

That's too broad.

Instead:

```text
GitHub
 │
 ├── random repo        ❌
 │
 ├── random branch      ❌
 │
 └── our main branch    ✅
```

This is **least privilege** applied to identity.

---

# 22. Create the role

Now:

```hcl
resource "aws_iam_role" "github_actions_dev" {
  name = "${var.project_name}-${var.environment}-github-actions"

  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json

  tags = {
    Name = "${var.project_name}-${var.environment}-github-actions"
  }
}
```

Now AWS has:

```text
IAM Role
└── github-actions-dev
```

---

# 23. Give the role permissions

The role needs permissions.

For example, if GitHub needs to push Docker images:

```text
ECR permissions
```

and deploy ECS:

```text
ECS permissions
```

A simplified deployment policy might include things such as:

```hcl
data "aws_iam_policy_document" "github_actions_permissions" {
  statement {
    effect = "Allow"

    actions = [
      "ecr:GetAuthorizationToken"
    ]

    resources = ["*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart"
    ]

    resources = [
      var.ecr_repository_arn
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "ecs:DescribeServices",
      "ecs:DescribeTaskDefinition",
      "ecs:UpdateService"
    ]

    resources = ["*"]
  }
}
```

Then attach it:

```hcl
resource "aws_iam_role_policy" "github_actions" {
  name = "${var.project_name}-${var.environment}-github-actions"

  role = aws_iam_role.github_actions_dev.id

  policy = data.aws_iam_policy_document.github_actions_permissions.json
}
```

---

# 24. Why not give AdministratorAccess?

You may see beginner tutorials doing this:

```text
AdministratorAccess
```

Don't do that for our production-oriented project.

That would effectively mean:

```text
GitHub Actions
      │
      ▼
AWS
      │
      └── almost everything
```

Instead:

```text
GitHub Actions
      │
      ├── ECR push
      ├── ECS deployment
      └── only what is actually required
```

This is called:

> **Least privilege**

---

# 25. GitHub Actions configuration

Now the interesting part.

Inside GitHub Actions, we'll use:

```yaml
permissions:
  id-token: write
  contents: read
```

The important line is:

```yaml
id-token: write
```

This allows the GitHub workflow to request an OIDC identity token.

---

# 26. Configure AWS credentials

We'll use the official AWS credentials action.

Conceptually:

```yaml
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
    aws-region: ap-south-1
```

Notice something important.

There is:

```text
AWS_ACCESS_KEY_ID ❌
AWS_SECRET_ACCESS_KEY ❌
```

We don't need them.

Instead:

```text
role-to-assume
```

is used.

---

# 27. What actually happens?

When the GitHub workflow runs:

```text
GitHub Actions
       │
       │ requests OIDC token
       ▼
GitHub OIDC
       │
       ▼
AWS STS
       │
       │ checks trust policy
       ▼
IAM Role
       │
       ▼
Temporary AWS credentials
```

Then the workflow can execute AWS commands.

---

# 28. Test the connection

After configuring credentials:

```yaml
- name: Verify AWS identity
  run: aws sts get-caller-identity
```

The output should show the assumed role.

Something like:

```text
Account:
123456789012

Arn:
arn:aws:sts::123456789012:assumed-role/...
```

This proves:

```text
GitHub
   ↓
OIDC
   ↓
AWS
   ↓
IAM Role
```

is working.

---

# 29. Very important security comparison

### Old approach

```text
GitHub Secrets
     │
     ├── Access Key
     └── Secret Key
            │
            ▼
           AWS
```

Long-lived credentials.

### OIDC approach

```text
GitHub
   │
   ▼
OIDC token
   │
   ▼
AWS STS
   │
   ▼
Temporary credentials
   │
   ▼
AWS
```

No long-lived AWS credentials stored in GitHub.

---

# 30. GitHub Environment security

We also have three environments:

```text
dev
stage
prod
```

We can create:

```text
GitHub Environment
├── dev
├── stage
└── prod
```

Then:

```text
main
 │
 ▼
dev
```

and eventually:

```text
stage
 │
 ▼
manual approval
 │
 ▼
prod
```

This works very well with our Terraform architecture.

---

# 31. Environment-specific IAM roles

Eventually:

```text
GitHub
 │
 ├── dev workflow
 │      │
 │      ▼
 │   terraform-dev
 │
 ├── stage workflow
 │      │
 │      ▼
 │   terraform-stage
 │
 └── prod workflow
        │
        ▼
     terraform-prod
```

And the trust policies can be different.

For example:

```text
dev
→ development branch/workflow

stage
→ protected branch

prod
→ protected branch/tag + GitHub Environment approval
```

This gives us multiple layers of protection.

---

# 32. OIDC doesn't replace IAM

This is another important beginner point.

OIDC does **not** mean:

> GitHub automatically gets access to AWS.

Instead:

```text
OIDC
=
proves identity

IAM Role
=
defines permissions
```

So:

```text
OIDC + IAM
```

work together.

---

# 33. OIDC doesn't replace GitHub secrets completely

We don't need:

```text
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
```

But GitHub may still have other secrets later.

For example:

```text
API keys
external service credentials
```

Those are separate from AWS authentication.

For AWS itself, we're using:

```text
OIDC
```

---

# 34. Our final CI/CD authentication flow

Eventually our deployment pipeline will look like:

```text
Developer
   │
   │ git push
   ▼
GitHub
   │
   ▼
GitHub Actions
   │
   │ OIDC
   ▼
AWS IAM
   │
   │ assume role
   ▼
Temporary credentials
   │
   ├───────────────┐
   ▼               ▼
  ECR              ECS
   │               │
   │ image         │ deployment
   └───────┬───────┘
           ▼
       NestJS
```

---

# 35. Where this fits in our Terraform structure

Our project now looks like:

```text
infra/
└── terraform/
    │
    ├── modules/
    │   │
    │   ├── network/
    │   │
    │   ├── compute/
    │   │
    │   ├── iam/
    │   │
    │   └── data/
    │
    └── envs/
        │
        ├── dev/
        │
        ├── stage/
        │
        └── prod/
```

IAM contains:

```text
iam/
├── OIDC provider
├── GitHub Actions roles
├── ECS execution role
└── ECS task role
```

---

# 36. One thing I would change from our earlier plan

Earlier we talked about:

```text
one role per environment
```

That's good, but I recommend eventually separating:

```text
Terraform role
```

from:

```text
Application deployment role
```

So production could look like:

```text
GitHub
 │
 ├── Terraform workflow
 │       │
 │       ▼
 │   terraform-prod
 │
 └── Deploy workflow
         │
         ▼
      deploy-prod
```

Why?

Because deploying an image shouldn't necessarily give a workflow permission to modify:

```text
VPC
RDS
IAM
Security Groups
```

That's a major production security improvement.

---

# 37. What you should remember

Don't try to memorize the Terraform syntax yet.

Remember these five things:

### 1. OIDC

```text
GitHub → proves its identity to AWS
```

### 2. IAM OIDC Provider

```text
AWS → trusts GitHub as an identity provider
```

### 3. IAM Role

```text
Role → temporary AWS identity GitHub can assume
```

### 4. Trust Policy

```text
Trust Policy → WHO can assume the role
```

### 5. Permissions Policy

```text
Permissions → WHAT the role can do
```

The complete mental model:

```text
                 GitHub
                    │
                    │ OIDC
                    ▼
             AWS IAM Provider
                    │
                    ▼
              Trust Policy
                    │
                    │ allowed?
                    ▼
                IAM Role
                    │
                    ▼
             Permissions
                    │
              ┌─────┴─────┐
              ▼           ▼
             ECR         ECS
```

---

# 38. Our roadmap

We're now at:

|  Step | Component            | Purpose                       |
| ----: | -------------------- | ----------------------------- |
|     1 | Terraform foundation | Infrastructure                |
|     2 | AWS Provider         | Terraform → AWS               |
|     3 | Network              | VPC/subnets/security          |
|     4 | ECR                  | Container images              |
|     5 | IAM                  | AWS permissions               |
|     6 | ECS/Fargate          | Run NestJS                    |
|     7 | ALB                  | Public HTTP entry point       |
|     8 | RDS                  | PostgreSQL                    |
| **9** | **GitHub OIDC**      | **GitHub → AWS without keys** |
|    10 | Secrets Manager      | Secure application secrets    |
|    11 | CloudWatch           | Logs/monitoring               |
|    12 | GitHub Actions       | Build → ECR → ECS             |
|    13 | Production hardening | HTTPS/scaling/security        |

### The next topic should be **Secrets Manager**.

That will connect directly to our RDS work:

```text
                    RDS
                     │
             DB username/password
                     │
                     ▼
              Secrets Manager
                     │
                     │
                     ▼
               ECS / NestJS
```

Then we can move into the really useful part:

```text
GitHub
   │
   ▼
GitHub Actions
   │
   │ OIDC
   ▼
AWS
   │
   ├── Build Docker image
   ├── Push → ECR
   └── Deploy → ECS
```

That will give you the complete **GitHub → AWS deployment pipeline without storing AWS access keys**.
