 # Terraform Foundation 

 ## Goal

 In this step, we will set up Terraform for our project and make sure it can:

 1. Read our Terraform configuration.
2. Download the AWS provider.
3. Validate our configuration.
4. Connect to AWS using our local AWS credentials.
5. Create **zero AWS resources**.

 > **Important:** We are only setting up Terraform. We are **not creating a VPC, EC2 instance, ECS cluster, database, or any other AWS infrastructure yet.**

---

 # 1\. First, understand what Terraform does

 Terraform is an **Infrastructure as Code (IaC)** tool.

 Instead of creating AWS resources manually through the AWS Console, we describe what we want using code.

 For example, later we might write:

```
I want a VPC.
I want 2 private subnets.
I want an ECS cluster.
I want an RDS database.
```

 Terraform reads that code and communicates with AWS to create those resources.

 For now, however, we don't want any resources.

 We just want to prove:

```
Terraform
    │
    ▼
AWS Provider
    │
    ▼
AWS
```

 is working correctly.

---

 # 2\. Our project structure

 Our project will eventually look like this:

```
ai-engineering-platform/
│
├── apps/
│
├── packages/
│
├── .gitignore
│
└── infra/
    └── terraform/
        │
        ├── modules/
        │
        │   └── # Reusable Terraform modules will go here later
        │
        └── envs/
            │
            ├── dev/
            │   ├── versions.tf
            │   ├── provider.tf
            │   ├── variables.tf
            │   ├── terraform.tfvars
            │   └── main.tf
            │
            ├── stage/
            │
            └── prod/
```

 ### What do these folders mean?

 #### `modules/`

 This will contain reusable infrastructure building blocks.

 For example, later we might have:

```
modules/
├── network/
├── compute/
├── database/
└── iam/
```

 We don't need any modules yet.

 #### `envs/`

 This contains our different environments.

 We will have:

```
dev
stage
prod
```

 For now, we are only configuring `dev`.

---

 # 3\. Create the directories

 Open PowerShell from the project root:

```
cd ai-engineering-platform
```

 Then run:

```
mkdir infra\terraform\modules
mkdir infra\terraform\envs
mkdir infra\terraform\envs\dev
mkdir infra\terraform\envs\stage
mkdir infra\terraform\envs\prod
```

 Your directory structure should now look like:

```
infra/
└── terraform/
    ├── modules/
    └── envs/
        ├── dev/
        ├── stage/
        └── prod/
```

---

 # 4\. Understand the Terraform files

 Our `dev` environment will contain five Terraform files:

```
dev/
├── versions.tf
├── provider.tf
├── variables.tf
├── terraform.tfvars
└── main.tf
```

 Each file has a specific purpose.

 | File | Purpose |
| --- | --- |
| `versions.tf` | Defines Terraform and provider versions |
| `provider.tf` | Configures AWS |
| `variables.tf` | Defines inputs our configuration needs |
| `terraform.tfvars` | Provides values for those inputs |
| `main.tf` | Where we will eventually define infrastructure |

Think of it like this:

```
versions.tf
    │
    │ "What versions do I need?"
    ▼
provider.tf
    │
    │ "How do I connect to AWS?"
    ▼
variables.tf
    │
    │ "What information do I need?"
    ▼
terraform.tfvars
    │
    │ "Here are the values."
    ▼
main.tf
    │
    │ "What infrastructure should exist?"
    ▼
AWS
```

---

 # 5\. Create `versions.tf`

 Create:

```
infra/terraform/envs/dev/versions.tf
```

 Add:

```
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
```

 ## What does this mean?

 We are telling Terraform:

 > "This project requires Terraform 1.6 or newer."

 And:

 > "This project uses the AWS provider from HashiCorp."

 The AWS provider is what allows Terraform to communicate with AWS.

 Without the provider, Terraform doesn't know how to talk to AWS.

 ### What is `~> 6.0`?

 This is a version constraint.

 It means we want the AWS provider from the `6.x` family rather than locking ourselves to one exact patch release.

 For example, Terraform can select a compatible version such as:

```
6.1.x
6.2.x
6.3.x
```

 depending on what is available and compatible with the lock file.

---

 # 6\. Create `provider.tf`

 Create:

```
infra/terraform/envs/dev/provider.tf
```

 Add:

```
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}
```

 ## What is a provider?

 A provider is Terraform's connection to an external platform.

 In our case:

```
Terraform
    │
    ▼
AWS Provider
    │
    ▼
AWS
```

 The provider knows how to create and manage AWS resources.

 ### AWS region

 This line:

```
region = var.aws_region
```

 means:

 > "Use the AWS region provided by the `aws_region` variable."

 We will provide that value in `terraform.tfvars`.

 ### Default tags

 We are also saying:

 > "Whenever Terraform creates an AWS resource through this provider, add these tags."

 For our development environment:

```
Project     = ai-engineering-platform
Environment = dev
ManagedBy   = Terraform
```

 Tags will make it much easier to identify and manage our AWS resources later.

---

 # 7\. Create `variables.tf`

 Create:

```
infra/terraform/envs/dev/variables.tf
```

 Add:

```
variable "aws_region" {
  description = "AWS region where the environment will be deployed."
  type        = string
}

variable "project_name" {
  description = "Name of the project."
  type        = string
}

variable "environment" {
  description = "Deployment environment."
  type        = string

  validation {
    condition     = contains(["dev", "stage", "prod"], var.environment)
    error_message = "Environment must be dev, stage, or prod."
  }
}
```

 ## What is a variable?

 A variable is simply an input.

 For example:

```
aws_region
project_name
environment
```

 are inputs that our Terraform configuration needs.

 Instead of writing values directly into `provider.tf`, we define variables.

 For example:

```
region = var.aws_region
```

 means:

 > "Use the value stored in the `aws_region` variable."

---

 # 8\. Why do we use variables?

 Imagine we eventually have:

```
dev
stage
prod
```

 Each environment could have different values.

 For example:

```
dev   → ap-south-1
stage → ap-south-1
prod  → ap-south-1
```

 Or later:

```
dev   → ap-south-1
stage → ap-southeast-1
prod  → us-east-1
```

 Variables make this easier to manage.

---

 # 9\. Environment validation

 We also have:

```
validation {
  condition     = contains(["dev", "stage", "prod"], var.environment)
  error_message = "Environment must be dev, stage, or prod."
}
```

 This prevents accidental values such as:

```
development
production
testing
random-name
```

 Our allowed environments are:

```
dev
stage
prod
```

 If somebody enters:

```
environment = "testing"
```

 Terraform will report an error instead of continuing.

---

 # 10\. Create `terraform.tfvars`

 Create:

```
infra/terraform/envs/dev/terraform.tfvars
```

 Add:

```
aws_region   = "ap-south-1"
project_name = "ai-engineering-platform"
environment  = "dev"
```

 ## What is `terraform.tfvars`?

 We created the variables in:

```
variables.tf
```

 Now we provide their values in:

```
terraform.tfvars
```

 Think of it as:

```
variables.tf
        │
        │ defines the inputs
        ▼
terraform.tfvars
        │
        │ provides the values
        ▼
Terraform
```

 Our values are:

```
AWS region  → Mumbai
Project     → ai-engineering-platform
Environment → dev
```

 `ap-south-1` is the AWS region for Mumbai.

---

 # 11\. Create `main.tf`

 Create:

```
infra/terraform/envs/dev/main.tf
```

 For now, add:

```
# Infrastructure will be added here in later steps.
```

 That's it.

 There are currently **no AWS resources** in this file.

 Later, this is where we will connect our reusable modules.

 For example, eventually we might have:

```
module "network" {
  # ...
}

module "compute" {
  # ...
}

module "database" {
  # ...
}
```

 But **do not add these yet**.

---

 # 12\. Create `.gitignore`

 At the project root:

```
ai-engineering-platform/.gitignore
```

 Add:

```
# Terraform
**/.terraform/
*.tfstate
*.tfstate.*
*.tfplan
*.tfplan.*
crash.log
crash.*.log

# Terraform variable files containing secrets
*.tfvars
*.tfvars.json

# Allow non-secret example variables
!*.example.tfvars

# Terraform lock file should be committed
!**/.terraform.lock.hcl
```

 ## Why do we need `.gitignore`?

 Terraform creates files locally that we generally don't want to put into Git.

 Most importantly:

```
.terraform/
terraform.tfstate
```

 Terraform state can contain information about our infrastructure and potentially sensitive values.

 Therefore:

```
terraform.tfstate
```

 should **not** be committed to Git.

---

 # 13\. Why are we ignoring `.tfvars`?

 We currently have:

```
terraform.tfvars
```

 with harmless values:

```
aws_region   = "ap-south-1"
project_name = "ai-engineering-platform"
environment  = "dev"
```

 But later a `.tfvars` file could contain sensitive information.

 For example:

```
database_password = "very-secret-password"
```

 We therefore make it a rule that:

```
*.tfvars
```

 is ignored by Git.

 If we need to share example values, we can create:

```
terraform.example.tfvars
```

 because our `.gitignore` explicitly allows:

```
!*.example.tfvars
```

---

 # 14\. Initialize Terraform

 Now we are ready to test our Terraform setup.

 Move into the development environment:

```
cd infra\terraform\envs\dev
```

 Run:

```
terraform init
```

 ## What does `terraform init` do?

 This is one of the most important Terraform commands.

 It prepares the current directory for Terraform.

 It will:

 1. Read our Terraform configuration.
2. Find the required AWS provider.
3. Download the AWS provider.
4. Create Terraform's local working directory.
5. Create/update the dependency lock file.

 After it finishes, you should see:

```
.terraform/
.terraform.lock.hcl
```

 The important files will look like:

```
dev/
├── .terraform/
├── .terraform.lock.hcl
├── main.tf
├── provider.tf
├── terraform.tfvars
├── variables.tf
└── versions.tf
```

 ### Important

 Commit:

```
.terraform.lock.hcl
```

 Do **not** commit:

```
.terraform/
```

---

 # 15\. Format the Terraform code

 Run:

```
terraform fmt -recursive
```

 This automatically formats Terraform files according to Terraform's standard formatting.

 Then check whether everything is formatted:

```
terraform fmt -check -recursive
```

 If there is no output, that's good.

 It means the files are already correctly formatted.

---

 # 16\. Validate the configuration

 Run:

```
terraform validate
```

 Terraform now checks whether our configuration is valid.

 We are looking for:

```
Success! The configuration is valid.
```

 This does **not** create anything in AWS.

 It only checks our Terraform configuration.

---

 # 17\. Understand `terraform plan`

 Now run:

```
terraform plan
```

 This is another very important Terraform command.

 `terraform plan` asks:

 > "If I applied this configuration, what would Terraform change?"

 Normally, Terraform might say:

```
Plan: 3 to add, 0 to change, 0 to destroy.
```

 But we haven't defined any AWS resources yet.

 Therefore, we expect essentially:

```
No changes.
```

 That is exactly what we want.

 ### Remember

```
terraform plan
```

 does **not** create resources.

 It only shows what Terraform would do.

---

 # 18\. Terraform's basic workflow

 As you learn Terraform, remember this basic workflow:

```
Write Terraform code
        │
        ▼
terraform fmt
        │
        ▼
terraform validate
        │
        ▼
terraform plan
        │
        ▼
terraform apply
        │
        ▼
AWS infrastructure
```

 For this step, we will **not run `terraform apply`**.

 There is nothing to create yet.

---

 # 19\. Check AWS authentication

 Terraform also needs permission to communicate with AWS.

 First check whether AWS CLI is installed:

```
aws --version
```

 You should get a version such as:

```
aws-cli/2.x.x ...
```

 The exact version doesn't matter for this step.

 Now run:

```
aws sts get-caller-identity
```

 If your AWS credentials are configured correctly, you should receive something similar to:

```
{
    "UserId": "...",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/..."
}
```

---

 # 20\. What does `aws sts get-caller-identity` do?

 This command asks AWS:

 > "Who am I authenticated as?"

 AWS responds with information about the identity making the request.

 The important part is that the command succeeds.

 That proves:

```
Your computer
     │
     ▼
AWS CLI
     │
     ▼
AWS
```

 is working.

 Terraform can use the same AWS credential configuration when it communicates with AWS.

---

 # 21\. Important: Terraform does not need AWS keys in the code

 Do **not** put this into `provider.tf`:

```
access_key = "..."
secret_key = "..."
```

 We don't want AWS credentials inside our Terraform files.

 Instead, Terraform can use credentials configured through the AWS CLI/environment.

 This is safer and also prepares us for our eventual CI/CD setup.

---

 # 22\. Our eventual CI/CD authentication

 For local development we can use our local AWS credentials.

 Later, when GitHub Actions manages infrastructure, we will use:

```
GitHub Actions
       │
       │ OIDC
       ▼
AWS IAM Role
       │
       ▼
Terraform
       │
       ▼
AWS
```

 We will **not** store long-lived AWS access keys in GitHub Secrets.

 That is a later step.

 Don't worry about OIDC yet.

 For now, the only thing we need to prove is:

```
AWS CLI → AWS
```

 and:

```
Terraform → AWS
```

 work correctly.

---

 # 23\. Final directory structure

 After running `terraform init`, your structure should look approximately like this:

```
ai-engineering-platform/
│
├── .gitignore
│
├── apps/
│
├── packages/
│
└── infra/
    └── terraform/
        │
        ├── modules/
        │
        │
        └── envs/
            │
            ├── dev/
            │   ├── .terraform/
            │   ├── .terraform.lock.hcl
            │   ├── main.tf
            │   ├── provider.tf
            │   ├── terraform.tfvars
            │   ├── variables.tf
            │   └── versions.tf
            │
            ├── stage/
            │
            └── prod/
```

 Remember:

```
.terraform/
```

 is local and ignored by Git.

 But:

```
.terraform.lock.hcl
```

 should be committed.

---

 # 24\. Step 1 checklist

 Run these commands from:

```
infra\terraform\envs\dev
```

 ### Step 1 — Initialize

```
terraform init
```

 Expected:

```
Terraform has been successfully initialized!
```

 ### Step 2 — Format

```
terraform fmt -check -recursive
```

 Expected:

```
No output
```

 ### Step 3 — Validate

```
terraform validate
```

 Expected:

```
Success! The configuration is valid.
```

 ### Step 4 — Plan

```
terraform plan
```

 Expected:

```
No changes.
```

 ### Step 5 — Check AWS

 From anywhere:

```
aws sts get-caller-identity
```

 Expected:

```
Your AWS account/identity information
```

---

 # 25\. When is Step 1 complete?

 Step 1 is complete when all five checks work:

```
              Terraform Foundation
                       │
          ┌────────────┴────────────┐
          │                         │
      Terraform                    AWS
          │                         │
          ▼                         ▼
    terraform init          aws sts get-caller-identity
          │
          ▼
    terraform fmt
          │
          ▼
    terraform validate
          │
          ▼
    terraform plan
          │
          ▼
      No changes
```

 At this point:

```
AWS resources created = 0
```

 That is intentional.

 We have only proven that our Terraform foundation works.

---

 # 26\. What have we learned?

 At the end of Step 1, you should understand these concepts:

 ### Terraform

 Terraform is a tool for defining and managing infrastructure using code.

 ### Provider

 The AWS provider allows Terraform to communicate with AWS.

```
Terraform → AWS Provider → AWS
```

 ### Variables

 Variables are inputs to our Terraform configuration.

```
variables.tf
      +
terraform.tfvars
```

 ### `terraform init`

 Prepares a Terraform project and downloads required providers.

 ### `terraform fmt`

 Formats Terraform code.

 ### `terraform validate`

 Checks whether the Terraform configuration is valid.

 ### `terraform plan`

 Shows what Terraform would change without actually making those changes.

 ### `terraform apply`

 Actually makes the changes.

 > We are **not using `terraform apply` yet**.

 ### Terraform state

 Terraform keeps track of infrastructure using state.

 For now, state is local.

 Later, we will move it to remote storage.

---

 # 27\. What comes next?

 Now that our foundation works, the next important step is **Terraform remote state**.

 We eventually want:

```
GitHub Actions
       │
       ▼
Terraform
       │
       ├──────────────► AWS infrastructure
       │
       ▼
S3 Terraform State
```

 Remote state becomes important when:

 - Multiple environments exist.
- Terraform runs from GitHub Actions.
- Multiple people work on the project.
- We need state locking/protection.
- Terraform should not depend on one developer's laptop.

 So the next step will be:

 # Step 2 — Remote Terraform State

 We will introduce:

```
S3
 │
 └── Terraform state
```

 and configure Terraform so that the state is stored remotely instead of relying on a local state file.

 **Do not create the VPC, ECS, RDS, IAM application roles, or other infrastructure yet.**

 The recommended order is:

```
Step 1
Terraform foundation
        │
        ▼
Step 2
Remote state
        │
        ▼
Step 3
Networking / VPC
        │
        ▼
Step 4
IAM
        │
        ▼
Step 5
Compute
        │
        ▼
Step 6
Data services
        │
        ▼
Step 7
GitHub Actions + OIDC
```

 This version keeps the same technical foundation, but introduces the Terraform concepts **before** asking you to run commands. It also makes the key distinction very explicit: **`plan` previews changes, while `apply` actually creates them.**


 Yes — **for Step 1, we’re covered**. The beginner-friendly doc includes everything from your original version, plus explanations for a new Terraform user.

 ### Step 1 coverage

 - ✅ Target Terraform directory structure
- ✅ `modules`, `envs`, `dev`, `stage`, `prod` directories
- ✅ `versions.tf`
- ✅ Terraform version constraint
- ✅ AWS provider version constraint
- ✅ `provider.tf`
- ✅ AWS region configuration
- ✅ Default AWS tags
- ✅ `variables.tf`
- ✅ Variable validation for `dev/stage/prod`
- ✅ `terraform.tfvars`
- ✅ `main.tf`
- ✅ `.gitignore`
- ✅ Explanation of why `.terraform/` is ignored
- ✅ Explanation of why Terraform state isn't committed
- ✅ `.terraform.lock.hcl` is committed
- ✅ `terraform init`
- ✅ `terraform fmt`
- ✅ `terraform fmt -check`
- ✅ `terraform validate`
- ✅ `terraform plan`
- ✅ Expected `No changes`
- ✅ AWS CLI installation check
- ✅ `aws sts get-caller-identity`
- ✅ Explanation of local AWS authentication
- ✅ Explicitly **no AWS infrastructure created**
- ✅ Explanation of Terraform's basic workflow
- ✅ Explanation of providers, variables, state, plan, and apply
- ✅ Future GitHub Actions → OIDC → AWS architecture
- ✅ Clear Step 1 completion checklist
- ✅ Clear introduction to Step 2: remote state

 ### One small thing I'd add

 For a **complete beginner**, I would add a short **Prerequisites** section at the very beginning:

```
Before starting, make sure you have:

- Git
- PowerShell
- Terraform >= 1.6
- AWS CLI
- An AWS account
- AWS credentials configured locally
```

 And commands to verify:

```
terraform version
aws --version
git --version
```
