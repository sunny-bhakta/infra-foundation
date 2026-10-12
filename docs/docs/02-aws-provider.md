# AWS Provider

> **Concept → Why we need it → File → Code → Command → What happened**


---
## 1. First: What are Terraform and AWS?


### AWS

AWS is where our application infrastructure will actually run.

Eventually we'll have things like:

```text
AWS
│
├── Network
│
├── Container Registry
│
├── ECS
│
├── Database
│
├── Secrets
│
└── Monitoring
```

### Terraform

Terraform is a tool that lets us **describe AWS infrastructure using code**.

Instead of manually clicking through AWS Console:

```text
AWS Console
    ↓
Create VPC
    ↓
Create subnet
    ↓
Create ECS
    ↓
Create database
```

we write:

```text
Terraform code
      ↓
Terraform
      ↓
AWS
```

Terraform tells AWS:

> "This is the infrastructure I want."

---

# 2. What is a Terraform Provider?

This is the first important Terraform concept.

Terraform itself doesn't know how to create an AWS VPC.

Terraform needs an **AWS Provider**.

Think of a provider as a **translator**.

```text
Terraform
    │
    │ "Create a VPC"
    ▼
AWS Provider
    │
    │ translates Terraform instructions
    ▼
AWS
```

So:

> **Provider = bridge between Terraform and a platform such as AWS.**

There are providers for many platforms:

```text
Terraform
│
├── AWS Provider
├── Azure Provider
├── Google Cloud Provider
├── GitHub Provider
└── Kubernetes Provider
```

We're using the AWS provider.

---

# 3. Our first Terraform folder

We are working here:

```text
ai-engineering-platform/
└── infra/
    └── terraform/
        └── envs/
            └── dev/
```

Why `dev`?

Because we're going to have three environments eventually:

```text
envs/
├── dev/
├── stage/
└── prod/
```

For now:

> **Only work with `dev`.**

Don't worry about stage and production yet.

---

# 4. `versions.tf`

Create:

```text
infra/terraform/envs/dev/versions.tf
```

Put this inside:

```hcl
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

Now let's understand it.

---

## 4.1 What does `terraform {}` mean?

This section contains configuration about Terraform itself.

```hcl
terraform {
}
```

We're saying:

> "Here are the requirements for this Terraform project."

---

## 4.2 What does this mean?

```hcl
required_version = ">= 1.6.0"
```

It means:

> Terraform version must be 1.6.0 or newer.

You can check your installed version:

```powershell
terraform version
```

For example:

```text
Terraform v1.16.3
```

That's fine.

---

# 5. What is `required_providers`?

This:

```hcl
required_providers {
}
```

means:

> "Terraform, these are the external providers this project needs."

We tell Terraform:

```hcl
aws = {
  source  = "hashicorp/aws"
  version = "~> 6.0"
}
```

Meaning:

> "I need the AWS provider published by HashiCorp."

---

# 6. Initialize Terraform

Now open PowerShell.

Go to:

```powershell
cd infra\terraform\envs\dev
```

Run:

```powershell
terraform init
```

This is an important command.

### What does `terraform init` mean?

It means:

> "Prepare this Terraform project."

Terraform reads:

```text
versions.tf
```

and sees:

```text
I need the AWS provider.
```

So Terraform downloads the AWS provider.

Conceptually:

```text
versions.tf
     │
     ▼
terraform init
     │
     ▼
Download AWS Provider
     │
     ▼
Ready to use AWS
```

You should see something similar to:

```text
Initializing provider plugins...

- Finding hashicorp/aws versions matching "~> 6.0"...
- Installing hashicorp/aws ...

Terraform has been successfully initialized!
```

---

# 7. What is `.terraform.lock.hcl`?

After `terraform init`, you'll see:

```text
.terraform.lock.hcl
```

Don't be scared by the name.

Terraform created this file to **lock the provider version/checksums it selected**.

Think of it like:

> "Terraform, use the provider version we already agreed on."

We **commit this file to Git**.

So:

```text
Commit:
.terraform.lock.hcl
```

But don't commit:

```text
.terraform/
```

---

# 8. Configure the AWS Provider

Now create:

```text
infra/terraform/envs/dev/provider.tf
```

Put:

```hcl
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

This is where we actually configure the AWS provider.

---

# 9. What does `region` mean?

AWS has different geographic regions.

For example:

```text
us-east-1
eu-west-1
ap-south-1
```

We're using:

```text
ap-south-1
```

which is the Mumbai region.

So:

```hcl
region = var.aws_region
```

means:

> "Terraform, use this AWS region."

---

# 10. What is `var.aws_region`?

This is another Terraform concept.

`var` means:

> **variable**

So:

```hcl
var.aws_region
```

means:

> "Use the value stored in the `aws_region` variable."

We'll define that variable next.

---

# 11. Create `variables.tf`

Create:

```text
infra/terraform/envs/dev/variables.tf
```

Put:

```hcl
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

Let's simplify this.

---

# 12. What is a Terraform variable?

A variable is simply a **value that we don't want to hard-code everywhere**.

For example, instead of writing:

```hcl
region = "ap-south-1"
```

everywhere, we define:

```hcl
variable "aws_region" {
  type = string
}
```

Then provide the actual value somewhere else.

This gives us:

```text
Variable definition
        │
        ▼
aws_region
        │
        ▼
"ap-south-1"
```

---

# 13. What does `type = string` mean?

This:

```hcl
type = string
```

means:

> This variable must contain text.

For example:

```text
"ap-south-1"
```

is a string.

Later you'll see other types:

```text
string
number
bool
list
map
object
```

We'll learn those when we need them.

---

# 14. What is `environment`?

We have:

```hcl
variable "environment" {
```

because eventually we have:

```text
dev
stage
prod
```

We added:

```hcl
validation {
  condition = contains(
    ["dev", "stage", "prod"],
    var.environment
  )
}
```

This protects us from accidentally writing:

```text
environment = "productionnn"
```

Terraform will reject it.

---

# 15. Where do the variable values go?

Create:

```text
infra/terraform/envs/dev/terraform.tfvars
```

Put:

```hcl
aws_region   = "ap-south-1"
project_name = "ai-engineering-platform"
environment  = "dev"
```

Now we have:

```text
variables.tf
    │
    │ defines variables
    ▼
terraform.tfvars
    │
    │ provides values
    ▼
provider.tf
```

So:

```text
aws_region
    ↓
"ap-south-1"
```

---

# 16. Why separate variables from values?

Because later we can have:

### Dev

```text
environment = "dev"
```

### Stage

```text
environment = "stage"
```

### Prod

```text
environment = "prod"
```

while the Terraform code remains reusable.

This becomes very important later.

---

# 17. Add `main.tf`

Create:

```text
infra/terraform/envs/dev/main.tf
```

For now:

```hcl
data "aws_caller_identity" "current" {}

data "aws_region" "current" {}
```

Don't worry about the word `data` yet.

This is simply asking AWS for information.

---

# 18. What is a Data Source?

This is another important Terraform concept.

Terraform has two common things:

### Resource

Terraform **creates/manages** something.

For example:

```hcl
resource "aws_vpc" "main" {
}
```

means:

> Create/manage a VPC.

### Data source

Terraform **reads information** about something that already exists.

For example:

```hcl
data "aws_caller_identity" "current" {}
```

means:

> AWS, tell Terraform which account I'm currently using.

So remember:

```text
resource
   =
create/manage something

data
   =
read information
```

---

# 19. What is `aws_caller_identity`?

This:

```hcl
data "aws_caller_identity" "current" {}
```

asks AWS:

> "Who am I?"

AWS responds with information such as:

```text
Account ID
User/Role
ARN
```

---

# 20. What is `aws_region`?

This:

```hcl
data "aws_region" "current" {}
```

asks:

> "Which AWS region am I using?"

It should return:

```text
ap-south-1
```

---

# 21. Create outputs

Create:

```text
infra/terraform/envs/dev/outputs.tf
```

Put:

```hcl
output "aws_account_id" {
  description = "AWS account ID used by Terraform."
  value       = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  description = "AWS region used by Terraform."
  value       = data.aws_region.current.region
}
```

---

# 22. What is an output?

An output is simply information Terraform shows us after running.

For example:

```text
terraform output
```

might show:

```text
aws_account_id = "123456789012"
aws_region     = "ap-south-1"
```

Think:

```text
Input
  ↓
Terraform
  ↓
AWS
  ↓
Output
```

---

# 23. Now our complete Step 2 structure

We should have:

```text
infra/
└── terraform/
    └── envs/
        └── dev/
            │
            ├── main.tf
            ├── outputs.tf
            ├── provider.tf
            ├── terraform.tfvars
            ├── variables.tf
            └── versions.tf
```

After `terraform init`:

```text
            ├── .terraform/
            └── .terraform.lock.hcl
```

---

# 24. Now let's connect Terraform to AWS

First check AWS itself.

Run:

```powershell
aws --version
```

Then:

```powershell
aws sts get-caller-identity
```

If you see:

```json
{
  "Account": "123456789012",
  "Arn": "..."
}
```

AWS authentication is working.

---

# 25. Why are we checking AWS CLI?

Because Terraform needs credentials.

Our local flow is:

```text
Your computer
     │
     ▼
AWS CLI credentials
     │
     ▼
Terraform AWS Provider
     │
     ▼
AWS
```

Terraform doesn't magically know your AWS account.

It needs authentication.

---

# 26. Terraform initialization

Run:

```powershell
cd infra\terraform\envs\dev
```

Then:

```powershell
terraform init
```

---

# 27. Format the code

Run:

```powershell
terraform fmt -recursive
```

This automatically formats Terraform code.

Then check:

```powershell
terraform fmt -check -recursive
```

If there is no output, that's good.

---

# 28. Validate

Run:

```powershell
terraform validate
```

Expected:

```text
Success! The configuration is valid.
```

Important:

`validate` does **not** mean:

> AWS is working.

It means:

> The Terraform configuration syntax and structure are valid.

---

# 29. Plan

Now:

```powershell
terraform plan
```

At this point we haven't created any AWS resources.

We're only asking AWS:

```text
Who am I?
Which region am I using?
```

So you should see:

```text
No changes.
```

That's expected.

---

# 30. Apply

We actually don't need `terraform apply` for this step because we're not creating infrastructure.

But if you run:

```powershell
terraform apply
```

there should be:

```text
No changes.
```

That's because our configuration currently contains only data sources.

---

# 31. See our outputs

Run:

```powershell
terraform output
```

You should see something like:

```text
aws_account_id = "123456789012"
aws_region     = "ap-south-1"
```

Now we've proven:

```text
Terraform
    │
    ▼
AWS Provider
    │
    ▼
AWS Account
    │
    └── ap-south-1
```

🎉 **That's our first successful Terraform → AWS connection.**

---

# 32. Very important: AWS credentials

You may wonder:

> Where did Terraform get my AWS username/password/access keys?

We don't put them in Terraform.

**Never do this:**

```hcl
provider "aws" {
  access_key = "MY_KEY"
  secret_key = "MY_SECRET"
}
```

Also don't put them in:

```text
terraform.tfvars
```

Instead, AWS CLI credentials are configured separately.

Later, our CI/CD architecture will be better.

We'll use:

```text
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

No permanent AWS credentials stored in GitHub.

We'll learn OIDC later. **Don't worry about it now.**

---

# 33. What have we actually learned?

There are **six concepts** from this step that I want you to remember.

### 1. Terraform

Infrastructure-as-code tool.

```text
Code → Infrastructure
```

### 2. Provider

Connects Terraform to AWS.

```text
Terraform → AWS Provider → AWS
```

### 3. Variable

Stores configurable values.

```text
var.aws_region
```

### 4. Data source

Reads information from AWS.

```hcl
data "aws_caller_identity" "current" {}
```

### 5. Output

Shows information to us.

```hcl
output "aws_account_id" {}
```

### 6. `terraform init`

Prepares the Terraform project and downloads providers.

---

# 34. The commands to remember

For now, these are your most important Terraform commands:

```powershell
terraform init
```

**Prepare the project**

```powershell
terraform fmt
```

**Format the code**

```powershell
terraform validate
```

**Check Terraform configuration**

```powershell
terraform plan
```

**Show what Terraform wants to change**

```powershell
terraform apply
```

**Actually make the changes**

```powershell
terraform destroy
```

**Delete infrastructure managed by Terraform**

⚠️ We won't use `destroy` casually.

---

# 35. One simple mental model

Forget all the complicated Terraform terminology for now.

Think of it like this:

```text
             Terraform Project
                    │
                    ▼
             versions.tf
                    │
                    ▼
             AWS Provider
                    │
                    ▼
              AWS Account
                    │
                    ▼
             AWS Resources
```

And later:

```text
Terraform
   │
   ▼
Provider
   │
   ▼
Network
   │
   ▼
ECR
   │
   ▼
ECS
   │
   ▼
RDS
   │
   ▼
Application
```

---

# Step 2 complete

At this point, **we haven't created anything expensive or complicated in AWS**.

We've simply established:

```text
Terraform
   │
   │ AWS Provider
   ▼
AWS
   │
   └── Mumbai (ap-south-1)
```

That's exactly where a beginner should start.

---

# Next: Step 3 — AWS Networking

Before writing the code, we'll first learn the concepts:

```text
AWS Region
    ↓
Availability Zone
    ↓
VPC
    ↓
Subnet
    ↓
Public vs Private Subnet
    ↓
Internet Gateway
    ↓
Route Table
    ↓
Security Group
```

Then we'll build them one by one in Terraform.

The key idea will be:

> **VPC = our private AWS network.**

Once that makes sense, the Terraform code for the network module becomes much easier to understand.
