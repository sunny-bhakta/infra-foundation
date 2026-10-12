# ECR: Container Image Repository

> Create an AWS ECR repository where our `ai-engineering-platform` container images will eventually be stored.

We are **not deploying ECS yet**. ECR only stores container images.

---

# 1. First: What problem does ECR solve?

Imagine our application is:

```text
ai-engineering-platform
```

Eventually, we want AWS ECS to run this application.

But ECS doesn't normally take your source code like:

```text
src/
package.json
pnpm-lock.yaml
...
```

Instead, ECS runs a **container**.

The flow looks like this:

```text
Your source code
      │
      ▼
Build container image
      │
      ▼
   Docker image
      │
      ▼
Push image to ECR
      │
      ▼
AWS ECR
      │
      ▼
ECS pulls image
      │
      ▼
Container starts
```

So ECR is basically AWS's **private storage/repository for container images**.

---

# 2. What is a container image?

Let's start even simpler.

Suppose our NestJS application needs:

```text
Node.js
pnpm
package.json
node_modules/dependencies
application code
environment configuration
startup command
```

A container image packages the application and the things it needs into a standardized package.

Conceptually:

```text
┌───────────────────────────────┐
│       Container Image         │
│                               │
│  Node.js runtime              │
│  Application dependencies     │
│  Application code             │
│  Configuration                │
│  Startup instructions         │
└───────────────────────────────┘
```

Think of it like a **ready-to-run application package**.

---

# 3. What is Docker?

You will hear Docker a lot when working with containers.

Docker is one of the most common technologies used to:

* build container images
* run containers
* test containers locally
* push images to registries

For example:

```text
Dockerfile
    │
    ▼
docker build
    │
    ▼
Container Image
```

You don't need to become a Docker expert right now.

For this step, the important relationship is:

```text
Docker
   ↓
builds container images

ECR
   ↓
stores container images

ECS
   ↓
runs containers
```

That's the mental model I want you to remember.

---

# 4. What exactly is ECR?

ECR stands for:

> **Elastic Container Registry**

It is an AWS service for storing container images.

Think of it like GitHub, but instead of storing source code repositories, ECR stores container images.

A rough comparison:

```text
GitHub
   ↓
stores source code

ECR
   ↓
stores container images
```

For example, we might eventually have:

```text
ECR Repository

ai-engineering-platform-dev
```

Inside that repository we could have image versions:

```text
ai-engineering-platform-dev

├── latest
├── 1.0.0
├── 1.1.0
├── 1.2.0
└── git-abc123
```

These are called **image tags**.

---

# 5. Repository vs image

This distinction is important.

An **ECR repository** is the place where images are stored.

For example:

```text
Repository:
ai-engineering-platform-dev
```

Inside it:

```text
Image
tag: 1.0.0

Image
tag: 1.1.0

Image
tag: 1.2.0
```

Think about it like this:

```text
ECR
│
└── Repository
     │
     ├── Image: 1.0.0
     ├── Image: 1.1.0
     └── Image: 1.2.0
```

---

# 6. Why do we need ECR?

Our eventual deployment will look approximately like:

```text
Developer
    │
    │ git push
    ▼
GitHub
    │
    │ GitHub Actions
    ▼
Build container image
    │
    ▼
Push image
    │
    ▼
ECR
    │
    │ ECS pulls image
    ▼
ECS Fargate
    │
    ▼
Running application
```

Without ECR, ECS needs another place to get the container image from.

ECR gives us an AWS-native private registry.

---

# 7. Where does ECR fit into our architecture?

Our architecture is becoming:

```text
                         AWS
┌───────────────────────────────────────────────┐
│                                               │
│  ECR                                          │
│  ┌─────────────────────────────────────────┐  │
│  │ ai-engineering-platform-dev             │  │
│  │                                         │  │
│  │ container images                        │  │
│  └─────────────────────────────────────────┘  │
│                     │                         │
│                     │ image                  │
│                     ▼                         │
│                ECS Fargate                    │
│                     │                         │
│                     ▼                         │
│                Application                    │
│                                               │
└───────────────────────────────────────────────┘
```

Later we'll connect this to our network:

```text
Internet
   │
   ▼
ALB
   │
   ▼
ECS
   │
   ├── pulls image from ECR
   │
   ▼
Application
   │
   ▼
RDS PostgreSQL
```

---

# 8. Does ECR run our application?

**No.**

This is one of the most important things to understand.

ECR:

```text
stores images
```

ECS:

```text
runs containers
```

So:

```text
ECR = storage
ECS = compute
```

For example:

```text
ECR
│
└── image
    │
    │ "Here is my application"
    ▼
ECS
│
└── container
    │
    │ "I am running the application"
    ▼
Application
```

---

# 9. ECR and our Terraform structure

We decided earlier to organize infrastructure into modules.

Our structure is:

```text
infra/
└── terraform/
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

For now, we'll put ECR under:

```text
modules/compute/
```

Why?

Because ECR is part of the application compute/deployment infrastructure.

Eventually:

```text
modules/
├── network/
│
├── compute/
│   └── ECR
│   └── ECS
│   └── Fargate
│
├── iam/
│
└── data/
    └── RDS
```

---

# 10. Why not create ECR manually in AWS Console?

We could.

We could go into AWS:

```text
AWS Console
   ↓
ECR
   ↓
Create repository
```

But we don't want infrastructure to depend on manual clicks.

We want:

```text
Terraform code
      ↓
terraform apply
      ↓
AWS infrastructure
```

That gives us:

* repeatability
* version control
* reviewable infrastructure
* easier dev/stage/prod environments
* automation through GitHub Actions

So we'll define the ECR repository using Terraform.

---

# 11. Create the compute module

Let's create:

```text
infra/terraform/modules/compute/
```

Inside it:

```text
compute/
├── main.tf
├── variables.tf
└── outputs.tf
```

For now, **compute contains only ECR**.

We are not creating ECS yet.

---

# 12. `variables.tf`

Create:

**Path**

```text
infra/terraform/modules/compute/variables.tf
```

Code:

```hcl
variable "project_name" {
  description = "Project name used for resource naming."
  type        = string
}

variable "environment" {
  description = "Deployment environment."
  type        = string
}
```

Why do we need these?

Because we want our repository name to be generated consistently.

For example:

```text
project_name = ai-engineering-platform
environment  = dev
```

can produce:

```text
ai-engineering-platform-dev
```

---

# 13. `main.tf`

Create:

**Path**

```text
infra/terraform/modules/compute/main.tf
```

Code:

```hcl
locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

resource "aws_ecr_repository" "app" {
  name = local.name_prefix

  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name = "${local.name_prefix}-ecr"
  }
}

resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep only the two most recent images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 2
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
```

Now let's understand **every part**.

---

# 14. What is `locals`?

```hcl
locals {
  name_prefix = "${var.project_name}-${var.environment}"
}
```

`locals` means:

> Create a value that Terraform can reuse inside this module.

If:

```text
project_name = ai-engineering-platform
environment = dev
```

then:

```text
local.name_prefix
```

becomes:

```text
ai-engineering-platform-dev
```

Instead of repeatedly writing:

```text
ai-engineering-platform-dev
```

we can use:

```hcl
local.name_prefix
```

---

# 15. What is `resource`?

This is extremely important in Terraform.

```hcl
resource "aws_ecr_repository" "app" {
```

`resource` means:

> Terraform should create/manage something in AWS.

The provider is AWS:

```text
aws
```

The resource type is:

```text
ecr_repository
```

Terraform therefore understands:

> Create/manage an AWS ECR repository.

---

# 16. Repository name

```hcl
name = local.name_prefix
```

So our repository becomes:

```text
ai-engineering-platform-dev
```

Eventually we can have:

```text
ai-engineering-platform-dev
ai-engineering-platform-stage
ai-engineering-platform-prod
```

This is one reason we use variables and modules.

---

# 17. What is image tag mutability?

We have:

```hcl
image_tag_mutability = "IMMUTABLE"
```

This is an important production concept.

Suppose we push:

```text
my-image:1.0.0
```

With mutable tags, someone could later replace the image behind:

```text
1.0.0
```

That can make deployments harder to reproduce.

With:

```text
IMMUTABLE
```

the tag cannot simply be overwritten.

So:

```text
1.0.0
```

continues to refer to the same image.

For production-oriented infrastructure, immutable tags are generally a good practice.

---

# 17.1 Keep only the latest 2 images

Add an ECR lifecycle policy so old images are automatically removed.

With:

```hcl
countType   = "imageCountMoreThan"
countNumber = 2
```

ECR keeps the two newest images and expires older ones.

This controls storage growth and keeps rollback options for the most recent two versions.

---

# 18. What is image scanning?

We have:

```hcl
image_scanning_configuration {
  scan_on_push = true
}
```

This means:

> When an image is pushed into ECR, AWS scans it for known vulnerabilities.

For example:

```text
Push image
    │
    ▼
ECR
    │
    ▼
Security scan
    │
    ├── vulnerabilities found
    │
    └── no known vulnerabilities
```

This is part of our security foundation.

It doesn't mean the image is automatically "safe", but it gives us vulnerability information.

---

# 19. What is encryption?

We have:

```hcl
encryption_configuration {
  encryption_type = "AES256"
}
```

This tells ECR to encrypt the stored images using AWS-managed encryption.

Very simply:

```text
Container image
       │
       ▼
   encrypted
       │
       ▼
      ECR
```

We don't need to manage encryption keys ourselves at this stage.

Later, if we have stronger compliance requirements, we can consider AWS KMS-managed keys.

For our current learning platform, AES-256 with AWS-managed encryption is a reasonable starting point.

---

# 20. What is `outputs.tf`?

We want other Terraform modules to eventually know:

> What is the ECR repository URL?

Create:

**Path**

```text
infra/terraform/modules/compute/outputs.tf
```

Code:

```hcl
output "ecr_repository_name" {
  description = "Name of the ECR repository."
  value       = aws_ecr_repository.app.name
}

output "ecr_repository_url" {
  description = "URL of the ECR repository."
  value       = aws_ecr_repository.app.repository_url
}

output "ecr_repository_arn" {
  description = "ARN of the ECR repository."
  value       = aws_ecr_repository.app.arn
}
```

Three useful pieces of information:

### Repository name

```text
ai-engineering-platform-dev
```

### Repository URL

Something similar to:

```text
123456789012.dkr.ecr.ap-south-1.amazonaws.com/ai-engineering-platform-dev
```

### Repository ARN

An AWS identifier for the repository.

---

# 21. Connect the module to `dev`

Now we need to tell our `dev` environment:

> Use the compute module.

Open:

```text
infra/terraform/envs/dev/main.tf
```

We already have:

```hcl
data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

module "network" {
  source = "../../modules/network"

  project_name = var.project_name
  environment = var.environment

  vpc_cidr = var.vpc_cidr

  availability_zones = var.availability_zones

  public_subnet_cidrs = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}
```

Add this **below the network module**:

```hcl
module "compute" {
  source = "../../modules/compute"

  project_name = var.project_name
  environment = var.environment
}
```

So the complete file becomes:

```hcl
data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

module "network" {
  source = "../../modules/network"

  project_name = var.project_name
  environment = var.environment

  vpc_cidr = var.vpc_cidr

  availability_zones = var.availability_zones

  public_subnet_cidrs = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

module "compute" {
  source = "../../modules/compute"

  project_name = var.project_name
  environment = var.environment
}
```

---

# 22. Add ECR outputs to dev

Open:

```text
infra/terraform/envs/dev/outputs.tf
```

Keep your existing outputs and add:

```hcl
output "ecr_repository_name" {
  description = "Name of the ECR repository."
  value       = module.compute.ecr_repository_name
}

output "ecr_repository_url" {
  description = "URL of the ECR repository."
  value       = module.compute.ecr_repository_url
}
```

So Terraform can display:

```text
ecr_repository_name
ecr_repository_url
```

after deployment.

---

# 23. We don't need new variables

Notice something important.

Our existing:

```text
terraform.tfvars
```

already has:

```hcl
project_name = "ai-engineering-platform"
environment  = "dev"
```

So we don't need to add anything.

Terraform passes:

```text
project_name
environment
```

from:

```text
dev environment
       ↓
compute module
```

---

# 24. Initialize Terraform

Because we created a new module, run:

```powershell
cd infra\terraform\envs\dev
```

Then:

```powershell
terraform init
```

Terraform will discover the new local module.

---

# 25. Format the code

Run:

```powershell
terraform fmt -recursive
```

Then:

```powershell
terraform fmt -check -recursive
```

The first formats the code.

The second checks whether everything is formatted correctly.

---

# 26. Validate

Run:

```powershell
terraform validate
```

You want:

```text
Success! The configuration is valid.
```

This checks the Terraform configuration itself.

It does **not** create anything.

---

# 27. Plan

Now run:

```powershell
terraform plan
```

Terraform should show that it wants to create the ECR repository.

Something conceptually like:

```text
Plan: 1 to add, 0 to change, 0 to destroy.
```

Depending on your current state and previous resources, the exact numbers may differ.

The important thing is that you should see:

```text
aws_ecr_repository.app
```

inside the compute module.

---

# 28. Apply

If the plan looks correct:

```powershell
terraform apply
```

Terraform will ask:

```text
Do you want to perform these actions?
```

Enter:

```text
yes
```

Terraform will create the ECR repository.

---

# 29. Check the outputs

Run:

```powershell
terraform output
```

You should get values similar to:

```text
ecr_repository_name = "ai-engineering-platform-dev"

ecr_repository_url = "123456789012.dkr.ecr.ap-south-1.amazonaws.com/ai-engineering-platform-dev"
```

Your account ID will obviously be different.

---

# 30. What did Terraform actually create?

At this point:

```text
AWS
│
├── VPC
│
├── Public Subnets
│
├── Private Subnets
│
├── Internet Gateway
│
├── Route Tables
│
└── ECR
    │
    └── ai-engineering-platform-dev
```

Notice that **ECR is completely independent of the VPC**.

That's an important concept.

ECR is an AWS managed service for storing images. We don't put the repository "inside" our VPC the way we put ECS tasks or RDS into subnets.

---

# 31. We still haven't pushed an image

This step only creates:

```text
ECR Repository
```

We have **not** done:

```text
docker build
docker push
```

yet.

That's intentional.

Our progression is:

```text
STEP 4
Create ECR repository
       ↓
STEP 5+
Create IAM
       ↓
Create ECS
       ↓
Create task definition
       ↓
Build application image
       ↓
Push image to ECR
       ↓
ECS pulls image
       ↓
Application runs
```

Later GitHub Actions will automate the image build and push.

---

# 32. Who is allowed to push images?

This brings us to an important security concept.

Not everyone should be able to push to our ECR repository.

Eventually we will have:

```text
GitHub Actions
       │
       │ OIDC
       ▼
AWS IAM Role
       │
       │ permission to push
       ▼
ECR
```

Similarly, ECS needs permission to pull the image:

```text
ECS
 │
 │ IAM permissions
 ▼
ECR
 │
 ▼
Container image
```

So IAM will control:

```text
Who can push?
Who can pull?
Who can manage?
```

We'll handle that in the IAM step.

---

# 33. The complete picture

By the time we finish the infrastructure, the deployment flow will look like this:

```text
                    GitHub
                       │
                       │ push code
                       ▼
                GitHub Actions
                       │
                       │ OIDC
                       ▼
                  AWS IAM Role
                       │
                       │ build/push
                       ▼
              ┌─────────────────┐
              │      ECR        │
              │                 │
              │ app:abc123      │
              │ app:def456      │
              └────────┬────────┘
                       │
                       │ pull image
                       ▼
                 ECS Fargate
                       │
                       ▼
                     ALB
                       │
                       ▼
                  Internet
```

And the application will eventually communicate with:

```text
ECS
 │
 ▼
RDS PostgreSQL
```

---

# 34. One very important beginner distinction

There are three things that are easy to confuse:

### ECR

**Stores the image**

```text
ECR = "Where is my application package?"
```

### ECS

**Runs the container**

```text
ECS = "Run my application package."
```

### Fargate

**Provides the serverless compute for the container**

```text
Fargate = "Run this container without me managing EC2 servers."
```

So:

```text
ECR
 ↓
stores image

ECS
 ↓
orchestrates/runs container

Fargate
 ↓
provides compute
```

You don't need to memorize the word "orchestrates" yet. Just remember:

> **ECR stores. ECS runs. Fargate provides the compute.**

---

# 35. What we have learned in Step 4

You should now understand:

| Concept         | Meaning                                           |
| --------------- | ------------------------------------------------- |
| Container       | A running packaged application                    |
| Container image | Package used to create a container                |
| Docker          | Common technology for building/running containers |
| Registry        | Storage location for container images             |
| ECR             | AWS container image registry                      |
| Repository      | Location inside ECR where images are stored       |
| Image tag       | Version/name attached to an image                 |
| Immutable       | Existing image tag cannot simply be replaced      |
| Image scanning  | Checks images for known vulnerabilities           |
| Encryption      | Protects stored image data                        |
| ECS             | Runs containers                                   |
| Fargate         | Provides compute for ECS containers               |
| IAM             | Controls who can access ECR                       |

### Our architecture so far

```text
                    AWS
                     │
        ┌────────────┴────────────┐
        │                         │
      Network                    ECR
        │                         │
     VPC                    Container Images
        │
   ┌────┴─────┐
Public       Private
Subnets      Subnets
```

And eventually:

```text
Internet
   │
   ▼
 ALB
   │
   ▼
 ECS/Fargate
   │
   ├──────────► ECR
   │             │
   │             └── container image
   │
   └──────────► RDS
```
