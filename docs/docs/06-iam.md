#  IAM


> Define **who is allowed to do what** in AWS.

The eventual flow will be:

```text
GitHub Actions
      │
      │ OIDC
      ▼
AWS IAM Role
      │
      ├── Push image → ECR
      │
      └── Deploy → ECS
```

And separately:

```text
ECS
 │
 │ IAM permissions
 ▼
ECR
 │
 └── Pull container image
```

### 1. What is IAM?

IAM means:

> **Identity and Access Management**

In simple terms:

> IAM answers two questions: **Who are you?** and **What are you allowed to do?**

For example:

```text
Person A
   ↓
allowed to read S3

Person B
   ↓
allowed to deploy ECS

Person C
   ↓
allowed to push Docker images to ECR
```

AWS doesn't simply say:

> "You're logged into AWS, so you can do everything."

Instead, AWS uses permissions.

---

## 2. Four IAM concepts you need first

There are four terms you'll see constantly:

```text
IAM
├── User
├── Role
├── Policy
└── Permission
```

### User

An IAM user represents a person/application identity.

Example:

```text
Sunny
   ↓
IAM User
```

For our production deployment, we **do not want GitHub Actions to have a permanent IAM user access key**.

We'll use a role instead.

---

### Role

A role is an identity that something can **assume temporarily**.

For example:

```text
GitHub Actions
       ↓
assume
       ↓
AWS IAM Role
       ↓
temporary permissions
```

This is much better than putting:

```text
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
```

inside GitHub.

---

### Policy

A policy describes what is allowed.

For example:

```text
Allow:
    ecr:PutImage
    ecr:BatchCheckLayerAvailability
    ecr:InitiateLayerUpload
```

That basically means:

> This identity is allowed to push container images to ECR.

---

### Permission

Permission is the actual ability to perform an AWS action.

For example:

```text
ecr:PutImage
```

means:

> Put an image into ECR.

---

# 3. IAM mental model

Think about a security guard.

```text
Person
   │
   ▼
IAM Role
   │
   ▼
IAM Policy
   │
   ▼
Allowed actions
```

For example:

```text
GitHub Actions
      │
      ▼
github-actions-deploy-role
      │
      ▼
Policy
      │
      ├── Push to ECR
      └── Update ECS service
```

---

# 4. Why are we doing IAM before ECS?

Because ECS needs permissions.

There are actually **different IAM roles for different purposes**.

This is extremely important.

We will eventually have something like:

```text
                    IAM
                     │
       ┌─────────────┼─────────────┐
       │             │             │
       ▼             ▼             ▼
GitHub Actions   ECS Task      ECS Execution
    Role           Role            Role
       │             │             │
       ▼             ▼             ▼
   Deploy        Application     Pull image
   resources      permissions     from ECR
```

Let's understand them.

---

# 5. GitHub Actions role

GitHub Actions needs to deploy our application.

Eventually:

```text
GitHub
   │
   ▼
GitHub Actions
   │
   ▼
AWS
```

It might need permissions such as:

```text
ECR:
  push image

ECS:
  update service

ECS:
  describe service
```

We'll give these permissions through an IAM role.

---

# 6. ECS execution role

ECS itself needs permission to do things like:

```text
ECS
 │
 ├── pull image from ECR
 │
 └── send logs to CloudWatch
```

Therefore ECS needs another role.

We call this the:

> **ECS Task Execution Role**

Conceptually:

```text
ECS
 │
 ▼
Execution Role
 │
 ├── ECR pull
 └── CloudWatch logs
```

---

# 7. ECS task role

This one is different.

Imagine our application eventually needs to call AWS:

```text
NestJS application
      │
      ├── Secrets Manager
      ├── S3
      └── SQS
```

The **application itself** needs permissions.

That's where the ECS **Task Role** comes in.

```text
Running application
       │
       ▼
ECS Task Role
       │
       ├── Read secrets
       ├── Read S3
       └── Send messages
```

This is different from the execution role.

### Easy way to remember

```text
Execution Role
    ↓
ECS infrastructure needs permission

Task Role
    ↓
Your application needs permission
```

---

# 8. GitHub Actions authentication

Now comes one of the most important modern AWS concepts:

## OIDC

Don't worry about the name yet.

OIDC allows GitHub Actions to prove:

> "I am a trusted GitHub Actions workflow from this repository."

Then AWS gives it temporary credentials.

The flow becomes:

```text
GitHub Actions
      │
      │ "I am this GitHub repository/workflow"
      ▼
GitHub OIDC
      │
      ▼
AWS IAM
      │
      │ verify trust
      ▼
IAM Role
      │
      ▼
Temporary AWS credentials
```

This is much safer than storing permanent AWS credentials in GitHub.

---

# 9. What we do NOT want

We don't want:

```text
GitHub Secrets
│
├── AWS_ACCESS_KEY_ID
└── AWS_SECRET_ACCESS_KEY
```

with a permanent AWS user.

Why?

If those credentials leak, someone may potentially use them until they are revoked.

Instead:

```text
GitHub
   │
   │ OIDC
   ▼
AWS
   │
   ▼
Temporary credentials
```

This is the approach we'll use.

---

# 10. IAM structure for our project

Let's target this architecture:

```text
IAM
│
├── GitHub Actions Role
│     │
│     ├── ECR push
│     └── ECS deployment
│
├── ECS Task Execution Role
│     │
│     ├── ECR pull
│     └── CloudWatch logs
│
└── ECS Task Role
      │
      └── Application AWS permissions
```

For now, we can create the roles and keep the application task role minimal.

---

# 11. Where will IAM live?

Our Terraform structure becomes:

```text
infra/
└── terraform/
    ├── modules/
    │   ├── network/
    │   ├── compute/
    │   └── iam/
    │
    └── envs/
        ├── dev/
        ├── stage/
        └── prod/
```

Create:

```text
infra/terraform/modules/iam/
```

We'll have:

```text
iam/
├── main.tf
├── variables.tf
└── outputs.tf
```

---

# 12. IAM module variables

Create:

**Path**

```text
infra/terraform/modules/iam/variables.tf
```

```hcl
variable "project_name" {
  description = "Project name used for IAM resource naming."
  type        = string
}

variable "environment" {
  description = "Deployment environment."
  type        = string
}
```

We'll add GitHub-specific variables when we create the OIDC trust relationship.

---

# 13. ECS execution role

Create:

**Path**

```text
infra/terraform/modules/iam/main.tf
```

Start with:

```hcl
locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

resource "aws_iam_role" "ecs_task_execution" {
  name = "${local.name_prefix}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${local.name_prefix}-ecs-task-execution-role"
  }
}
```

Let's understand this.

---

# 14. What does `aws_iam_role` mean?

```hcl
resource "aws_iam_role" "ecs_task_execution"
```

means:

> Terraform should create an AWS IAM role.

The role is:

```text
ecs-task-execution-role
```

---

# 15. What is `assume_role_policy`?

This part:

```hcl
assume_role_policy = jsonencode({
```

answers:

> **Who is allowed to assume this role?**

We have:

```hcl
Principal = {
  Service = "ecs-tasks.amazonaws.com"
}
```

Meaning:

> ECS tasks are trusted to assume this role.

This is called the **trust policy**.

That's different from the permissions policy.

---

# 16. Trust vs permission

This distinction is very important.

### Trust policy

Answers:

> Who can use this role?

```text
ECS
 ↓
allowed to assume role
```

### Permissions policy

Answers:

> What can the role do?

```text
Role
 ↓
allowed to pull ECR image
 ↓
allowed to write CloudWatch logs
```

So:

```text
IAM Role
├── Trust policy
│     └── Who can assume me?
│
└── Permission policy
      └── What can I do?
```

---

# 17. Give ECS execution role standard permissions

AWS provides a managed policy for the standard ECS task execution use case.

Add to `main.tf`:

```hcl
resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role = aws_iam_role.ecs_task_execution.name

  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
```

This provides the standard permissions ECS needs for things such as:

* pulling images from ECR
* sending container logs to CloudWatch Logs

We'll use more restrictive/custom policies later if our requirements demand them.

---

# 18. ECS task role

Now create the role our actual application will use.

Add:

```hcl
resource "aws_iam_role" "ecs_task" {
  name = "${local.name_prefix}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${local.name_prefix}-ecs-task-role"
  }
}
```

At this point the application role has **no additional AWS permissions**.

That's intentional.

This follows an important security principle:

> **Least privilege.**

Give an application only the permissions it actually needs.

Later, if our NestJS application needs:

```text
Secrets Manager
```

we add only the required permission.

If it needs:

```text
S3
```

we add only the required S3 permission.

We don't give it:

```text
AdministratorAccess
```

---

# 19. Outputs

Create:

**Path**

```text
infra/terraform/modules/iam/outputs.tf
```

```hcl
output "ecs_task_execution_role_arn" {
  description = "ARN of the ECS task execution role."
  value       = aws_iam_role.ecs_task_execution.arn
}

output "ecs_task_role_arn" {
  description = "ARN of the ECS task role."
  value       = aws_iam_role.ecs_task.arn
}
```

Why output the ARN?

Because ECS will eventually need these values in its task definition:

```text
ECS Task Definition
       │
       ├── executionRoleArn
       │
       └── taskRoleArn
```

Terraform will connect them automatically.

---

# 20. Connect IAM to dev

Open:

```text
infra/terraform/envs/dev/main.tf
```

Add:

```hcl
module "iam" {
  source = "../../modules/iam"

  project_name = var.project_name
  environment = var.environment
}
```

Your architecture is now:

```text
dev
│
├── network module
│
├── compute module
│     └── ECR
│
└── iam module
      ├── ECS execution role
      └── ECS task role
```

---

# 21. Add IAM outputs

Open:

```text
infra/terraform/envs/dev/outputs.tf
```

Add:

```hcl
output "ecs_task_execution_role_arn" {
  description = "ARN of the ECS task execution role."
  value       = module.iam.ecs_task_execution_role_arn
}

output "ecs_task_role_arn" {
  description = "ARN of the ECS task role."
  value       = module.iam.ecs_task_role_arn
}
```

---

# 22. Validate

From:

```powershell
cd infra\terraform\envs\dev
```

run:

```powershell
terraform fmt -recursive
```

Then:

```powershell
terraform validate
```

Then:

```powershell
terraform plan
```

You should see the two IAM roles and the policy attachment being created.

Conceptually:

```text
Plan:
  + ECS task execution role
  + ECS task role
  + execution role policy attachment
```

---

# 23. Don't add GitHub Actions role yet

There's a small architectural decision here.

We **can** create the GitHub Actions OIDC role now, but I recommend doing it as the next part of IAM after we establish exactly what our deployment workflow needs.

The final flow will be:

```text
GitHub Actions
      │
      ▼
GitHub OIDC Provider
      │
      ▼
AWS IAM Role
      │
      ├── ECR push
      ├── ECS update
      └── ECS describe
```

The GitHub role should be scoped to **your repository**, not made broadly assumable by arbitrary GitHub workflows.

For example, the trust relationship will eventually restrict access to something conceptually like:

```text
repo:<your-github-user>/<your-repository>:ref:refs/heads/main
```

We'll use your actual GitHub repository information when we implement that part.

---

# 24. Why are we separating IAM from ECS?

Because IAM is a foundation.

Think of the dependency chain:

```text
IAM
 │
 ├──────────────┐
 │              │
 ▼              ▼
ECR            ECS
 │              │
 │              ├── execution role
 │              └── task role
 │
 └── GitHub Actions
```

Then:

```text
GitHub Actions
      │
      ▼
     ECR
      │
      ▼
     ECS
      │
      ▼
   Fargate
```

This is much easier to understand than creating ECS, IAM, ECR and GitHub Actions all at once.

---

# 25. One more important concept: ARN

You'll see something like:

```text
arn:aws:iam::123456789012:role/ai-engineering-platform-dev-ecs-task-role
```

This is an **ARN**.

ARN means:

> Amazon Resource Name

It is basically the unique identifier for an AWS resource.

Think:

```text
Name:
ai-engineering-platform-dev-ecs-task-role

ARN:
the globally unique AWS identifier for that role
```

Terraform outputs the ARN because other AWS resources often need the ARN rather than just the friendly name.

---

# 26. Our infrastructure now

We're building this in layers:

```text
                     AWS
                      │
       ┌──────────────┼───────────────┐
       │              │               │
       ▼              ▼               ▼
    Network          ECR             IAM
       │              │               │
       │              │        ┌──────┴──────┐
       │              │        │             │
       │              │        ▼             ▼
       │              │     ECS Task    ECS Execution
       │              │       Role          Role
       │              │
       └──────────────┴───────────────┐
                                      │
                                      ▼
                                   ECS
                                      │
                                      ▼
                                  Fargate
```

Then GitHub Actions will be added:

```text
GitHub
   │
   ▼
GitHub Actions
   │
   │ OIDC
   ▼
IAM Role
   │
   ├── ECR
   └── ECS
```

---

## Where we are in the roadmap

The implementation order is intentionally:

```text
IAM → ECS + Fargate → GitHub Actions + OIDC
```

This keeps permissions clear and avoids granting CI/CD deploy access before ECS requirements are fully known.

|  Step | Component                        | Status     |
| ----: | -------------------------------- | ---------- |
|     1 | Terraform Foundation             | ✅          |
|     2 | AWS Provider                     | ✅          |
|     3 | Network / VPC / Subnets          | ✅          |
|     4 | ECR                              | ✅          |
| **5** | **IAM**                          | **➡️ Now** |
| **6** | **ECS + Fargate**                | **Next**   |
| **7** | **GitHub Actions + OIDC deploy** | **After ECS** |
|     8 | ALB                              | Later      |
|     9 | RDS                              | Later      |
|    10 | Secrets Manager                  | Later      |
|    11 | CloudWatch                       | Later      |
