# AWS Provider + S3 Remote State + State Locking

 In Step 1, we created the Terraform project structure and configured the AWS provider.

 Now we'll do two important things:

 1. Verify that Terraform can communicate with AWS.
2. Move Terraform state from your computer to an **Amazon S3 remote backend**.

 By the end of this step:

```
                         AWS
                          │
             ┌────────────┴────────────┐
             │                         │
             ▼                         ▼
       AWS Provider              S3 Backend
             │                         │
             ▼                         ▼
       AWS resources            Terraform state
                                       │
                                       ▼
                                  S3 lock file
```

 We will **not** create application infrastructure yet.

 No:

```
VPC
ECS
RDS
ALB
Application S3 buckets
```

 The only AWS infrastructure we create in this step is the **Terraform state S3 bucket**.

---

 # 2.1 First: Provider vs Backend

 This distinction is extremely important.

 ## AWS Provider

 The AWS provider tells Terraform:

 > "How do I communicate with AWS?"

 Our provider will look like:

```
provider "aws" {
  region = var.aws_region
}
```

 The flow is:

```
Terraform
    │
    ▼
AWS Provider
    │
    ▼
AWS API
```

 The provider is responsible for interacting with AWS resources.

---

 ## S3 Backend

 The backend tells Terraform:

 > "Where should I store my Terraform state?"

 Without a remote backend, Terraform normally stores state locally:

```
Your computer
└── terraform.tfstate
```

 With an S3 backend:

```
Terraform
    │
    ▼
S3 Backend
    │
    ▼
Amazon S3
    │
    └── dev/terraform.tfstate
```

 So remember:

```
provider.tf
    ↓
How do I talk to AWS?

backend.tf
    ↓
Where do I store Terraform state?
```

 These are **two separate concepts**.

---

 # 2.2 Why do we need remote state?

 At the beginning, you might have:

```
Your laptop
    │
    └── terraform.tfstate
```

 That works for learning.

 But later we'll have something like:

```
Developer
     │
     ▼
Terraform
     │
     ▼
AWS
```

 and also:

```
GitHub Actions
     │
     ▼
Terraform
     │
     ▼
AWS
```

 We don't want each machine to have a different copy of Terraform state.

 Instead:

```
                    S3
                     │
              Terraform State
                     │
          ┌──────────┴──────────┐
          │                     │
      Developer           GitHub Actions
          │                     │
          └──────────┬──────────┘
                     ▼
                  Terraform
```

 Now everyone uses the same remote state.

---

 # 2.3 Our state design

 We'll use one S3 bucket for Terraform state.

 Inside that bucket, we'll separate environments using different keys:

```
S3 bucket
│
├── dev/
│   └── terraform.tfstate
│
├── stage/
│   └── terraform.tfstate
│
└── prod/
    └── terraform.tfstate
```

 For now, we're only working with:

```
dev/terraform.tfstate
```

 Later, we can add `stage` and `prod`.

---

 # 2.4 What is Terraform state?

 Terraform state is Terraform's record of the infrastructure it manages.

 For example, later we'll create:

```
VPC
Subnet
Security Group
ECS
RDS
ALB
```

 Terraform needs to remember those resources and their important IDs/details.

 Conceptually:

```
Terraform configuration
        │
        │ Desired infrastructure
        ▼
    Terraform
        │
        │ compares with
        ▼
Terraform State
        │
        ▼
       AWS
```

 That's why state is extremely important.

 We should **not store Terraform state in Git**.

---

 # 2.5 State locking

 Imagine two people run:

```
terraform apply
```

 at the same time.

 Without locking:

```
Developer A ──► Terraform ──► State
Developer B ──► Terraform ──► State
```

 Both could try to modify the same state.

 That's dangerous.

 With locking:

```
Developer A
    │
    ▼
terraform apply
    │
    🔒
    │
    ▼
State locked

Developer B
    │
    ▼
terraform apply
    │
    ▼
Cannot modify the same state simultaneously
```

 The current S3 backend supports native locking with:

```
use_lockfile = true
```

 We're going to use that.

---

 # 2.6 Why aren't we using DynamoDB?

 Older Terraform tutorials often show:

```
dynamodb_table = "terraform-locks"
```

 We will **not** use that.

 For the current S3 backend, Terraform supports S3-native locking:

```
use_lockfile = true
```

 DynamoDB-based locking is deprecated in the current Terraform S3 backend documentation.

 So our design is simpler:

```
S3
├── Terraform state
└── Terraform lock file
```

 instead of:

```
S3
└── Terraform state

DynamoDB
└── Terraform lock
```

---

 # 2.7 The bootstrap problem

 Here's something important that can confuse beginners.

 Terraform needs the S3 bucket to store its state.

 But we're using Terraform to create AWS infrastructure.

 So we have:

```
Terraform
    │
    ▼
Needs S3 bucket
    │
    ▼
But who creates the S3 bucket?
```

 This is called the **bootstrap problem**.

 The easiest approach for our project is:

```
Create S3 state bucket manually
          │
          ▼
Configure Terraform backend
          │
          ▼
terraform init
          │
          ▼
Terraform uses S3 state
```

 We'll give you **two ways** to create the bucket:

 - AWS Management Console
- AWS CLI

 Choose **one**.

---

 # 2.8 Verify AWS CLI and credentials

 Before creating anything, verify that AWS authentication works.

 From PowerShell:

```
aws --version
```

 You should see something similar to:

```
aws-cli/2.x.x
```

 Now:

```
aws sts get-caller-identity
```

 You should get something similar to:

```
{
    "UserId": "...",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/..."
}
```

 This tells us:

```
AWS CLI
   │
   ▼
AWS credentials
   │
   ▼
AWS account
```

---

 # 2.9 Find your AWS account ID

 Run:

```
aws sts get-caller-identity --query Account --output text
```

 Example:

```
123456789012
```

 You don't need to put this into Terraform.

 It's just useful to confirm which AWS account you're working with.

---

 # 2.10 Choose a state bucket name

 S3 bucket names must be globally unique.

 Don't use:

```
ai-engineering-platform-tfstate
```

 unless you know it is available.

 Instead, use something unique, for example:

```
ai-engineering-platform-tfstate-12345
```

 Replace:

```
12345
```

 with your own unique value.

 For the rest of this guide, I'll use:

```
ai-engineering-platform-tfstate-12345
```

 **Important:** Wherever you see that name, replace it with your actual bucket name.

---

 # 2.11 Option A — Create the S3 bucket using AWS Console

 This is the method I recommend if you're learning AWS for the first time.

 Open the AWS Management Console and go to:

 **Amazon S3 → Create bucket**

 ## Step 1 — Bucket name

 Enter:

```
ai-engineering-platform-tfstate-12345
```

 Use your own unique suffix.

---

 ## Step 2 — AWS Region

 Choose:

```
Asia Pacific (Mumbai)
```

 which is:

```
ap-south-1
```

 Our Terraform environment will also use:

```
ap-south-1
```

---

 ## Step 3 — Object Ownership

 For **Object Ownership**, use:

```
ACLs disabled
Bucket owner enforced
```

 This keeps bucket ownership simple.

---

 ## Step 4 — Block public access

 Keep:

```
Block all public access
```

 enabled.

 All four public-access-block options should remain enabled.

 Terraform state should **never be publicly accessible**.

---

 ## Step 5 — Bucket Versioning

 Enable:

```
Bucket Versioning
```

 Why?

 Because Terraform state is important.

 If something accidentally changes or deletes the state object, versioning gives us previous versions that can help with recovery.

 So:

```
Versioning = Enabled
```

---

 ## Step 6 — Default encryption

 Choose:

```
Server-side encryption with Amazon S3 managed keys (SSE-S3)
```

 This is:

```
SSE-S3
AES256
```

 For this project, that's a good starting point.

 Later, if required, we can introduce a customer-managed AWS KMS key.

---

 ## Step 7 — Create the bucket

 Click:

 **Create bucket**

 You should now see your bucket:

```
ai-engineering-platform-tfstate-12345
```

---

 # 2.12 Option B — Create the S3 bucket using AWS CLI

 If you prefer the command line, you can create the same bucket using PowerShell.

 ### Create bucket

```
aws s3api create-bucket `
  --bucket ai-engineering-platform-tfstate-12345 `
  --region ap-south-1 `
  --create-bucket-configuration LocationConstraint=ap-south-1
```

---

 ## Enable versioning

```
aws s3api put-bucket-versioning `
  --bucket ai-engineering-platform-tfstate-12345 `
  --versioning-configuration Status=Enabled
```

---

 ## Block public access

```
aws s3api put-public-access-block `
  --bucket ai-engineering-platform-tfstate-12345 `
  --public-access-block-configuration `
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
```

---

 ## Enable bucket ownership

```
aws s3api put-bucket-ownership-controls `
  --bucket ai-engineering-platform-tfstate-12345 `
  --ownership-controls Rules=[{ObjectOwnership=BucketOwnerEnforced}]
```

---

 ## Enable encryption

```
aws s3api put-bucket-encryption `
  --bucket ai-engineering-platform-tfstate-12345 `
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
```

---

 # 2.13 Console or CLI — choose one

 Don't run both methods.

 If you used the Console:

```
AWS Console
    ↓
S3 bucket created
```

 If you used the CLI:

```
AWS CLI
    ↓
S3 bucket created
```

 Both produce the same basic result.

 For learning:

```
First time → Console
Later       → CLI / automation
```

 is a perfectly reasonable approach.

---

 # 2.14 Verify the bucket

 Regardless of whether you used Console or CLI, you can verify it.

 Run:

```
aws s3api head-bucket `
  --bucket ai-engineering-platform-tfstate-12345
```

 If there is no error, the bucket exists and you can access it.

---

 # 2.15 Verify versioning

 Run:

```
aws s3api get-bucket-versioning `
  --bucket ai-engineering-platform-tfstate-12345
```

 Expected:

```
{
    "Status": "Enabled"
}
```

---

 # 2.16 Configure Terraform's S3 backend

 Now that the bucket exists, Terraform can use it.

 Create:

```
infra/
└── terraform/
    └── envs/
        └── dev/
            └── backend.tf
```

 Add:

```
terraform {
  backend "s3" {
    bucket       = "ai-engineering-platform-tfstate-12345"
    key          = "dev/terraform.tfstate"
    region       = "ap-south-1"
    use_lockfile = true
    encrypt      = true
  }
}
```

 Replace:

```
ai-engineering-platform-tfstate-12345
```

 with your actual bucket name.

---

 # 2.17 Understand `backend.tf`

 Let's understand each setting.

 ## `bucket`

```
bucket = "ai-engineering-platform-tfstate-12345"
```

 Means:

 > Store Terraform state in this S3 bucket.

---

 ## `key`

```
key = "dev/terraform.tfstate"
```

 Means:

 > Store the dev environment's state at this location inside the bucket.

 So eventually:

```
S3 bucket
│
└── dev/
    └── terraform.tfstate
```

 Later we can have:

```
S3 bucket
│
├── dev/
│   └── terraform.tfstate
│
├── stage/
│   └── terraform.tfstate
│
└── prod/
    └── terraform.tfstate
```

---

 ## `region`

```
region = "ap-south-1"
```

 This tells Terraform where the S3 bucket exists.

---

 ## `use_lockfile`

```
use_lockfile = true
```

 This enables S3-native state locking.

 Think:

```
terraform apply
      │
      ▼
Acquire lock
      │
      ▼
Modify state
      │
      ▼
Release lock
```

---

 ## `encrypt`

```
encrypt = true
```

 This tells the backend to use server-side encryption for the state object.

 We have also configured default encryption on the bucket itself.

---

 # 2.18 One important Terraform limitation

 You might wonder why we don't write:

```
terraform {
  backend "s3" {
    bucket = var.state_bucket
  }
}
```

 We can't use normal Terraform variables inside backend configuration.

 So this is valid:

```
terraform {
  backend "s3" {
    bucket = "ai-engineering-platform-tfstate-12345"
  }
}
```

 But this is not:

```
terraform {
  backend "s3" {
    bucket = var.state_bucket
  }
}
```

 For this reason, the backend bucket name is normally written directly in the backend configuration or supplied during initialization.

---

 # 2.19 Initialize Terraform

 Go to:

```
cd infra\terraform\envs\dev
```

 Now run:

```
terraform init
```

 Terraform should say something similar to:

```
Initializing the backend...

Successfully configured the backend "s3"!
```

 You may also see:

```
Terraform has been successfully initialized!
```

---

 # 2.20 What just happened?

 Before:

```
Terraform
    │
    ▼
Local backend
    │
    ▼
Your computer
```

 Now:

```
Terraform
    │
    ▼
S3 backend
    │
    ▼
Amazon S3
    │
    └── dev/terraform.tfstate
```

 That's a major milestone.

---

 # 2.21 If Terraform asks about migrating state

 If you previously ran Terraform and have an existing local state, `terraform init` may ask whether you want to migrate the state.

 For example:

```
Do you want to copy existing state to the new backend?
```

 **Don't blindly answer `yes`.**

 Read the prompt.

 If this is a fresh project and there is no important infrastructure/state yet, there may be nothing meaningful to migrate.

 If you already created resources during an earlier step, stop and verify before migrating.

---

 # 2.22 Configure the AWS provider

 Now let's verify that Terraform can communicate with AWS.

 Your:

```
infra/terraform/envs/dev/provider.tf
```

 should contain:

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

 The important part is:

```
region = var.aws_region
```

 Terraform gets the region from our environment variables.

---

 # 2.23 Check the variables

 Your:

```
infra/terraform/envs/dev/variables.tf
```

 should contain:

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

---

 # 2.24 Configure `terraform.tfvars`

 Your:

```
infra/terraform/envs/dev/terraform.tfvars
```

 should contain:

```
aws_region   = "ap-south-1"
project_name = "ai-engineering-platform"
environment  = "dev"
```

---

 # 2.25 Add AWS data sources

 Now let's ask AWS:

 > Which account am I using?

 and:

 > Which region am I using?

 Update:

```
infra/terraform/envs/dev/main.tf
```

 with:

```
data "aws_caller_identity" "current" {}

data "aws_region" "current" {}
```

 These are **data sources**.

 A data source means:

 > "Terraform, read existing information from AWS."

 We're not creating an AWS resource here.

---

 # 2.26 Add outputs

 Create or update:

```
infra/terraform/envs/dev/outputs.tf
```

 with:

```
output "aws_account_id" {
  description = "AWS account ID used by Terraform."
  value       = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  description = "AWS region used by Terraform."
  value       = data.aws_region.current.name
}
```

 These outputs let us confirm exactly which AWS account and region Terraform is using.

---

 # 2.27 Format Terraform

 Run:

```
terraform fmt -recursive
```

 Then:

```
terraform fmt -check -recursive
```

 If the second command produces no output, that's good.

---

 # 2.28 Validate Terraform

 Run:

```
terraform validate
```

 Expected:

```
Success! The configuration is valid.
```

---

 # 2.29 Run Terraform plan

 Now run:

```
terraform plan
```

 At this point, we haven't created application infrastructure.

 Terraform should therefore report something similar to:

```
No changes.
```

 The data sources are simply reading information from AWS.

---

 # 2.30 Apply

 Now run:

```
terraform apply
```

 You should eventually see:

```
Apply complete! Resources: 0 added, 0 changed, 0 destroyed.
```

 That's what we expect.

 Why?

 Because:

```
S3 state bucket
    ↓
was created manually
```

 and:

```
AWS account/region data sources
    ↓
only read information
```

 We're not creating the VPC or application resources yet.

---

 # 2.31 Check Terraform outputs

 Run:

```
terraform output
```

 You should see something similar to:

```
aws_account_id = "123456789012"
aws_region     = "ap-south-1"
```

 This proves:

```
Terraform
    │
    ├── AWS Provider
    │       │
    │       └── AWS account ✓
    │
    └── S3 Backend
            │
            └── Remote state ✓
```

---

 # 2.32 Verify state in S3

 Run:

```
aws s3 ls s3://ai-engineering-platform-tfstate-12345/dev/
```

 You should eventually see something similar to:

```
terraform.tfstate
```

 Depending on the S3 backend/locking behavior, you may also see a lock-related object while a Terraform operation is active.

 The important object is:

```
dev/terraform.tfstate
```

---

 # 2.33 Verify using the AWS Console

 You can also check manually.

 Open:

 **AWS Console → S3 → your Terraform state bucket**

 You should see:

```
dev/
```

 Open it:

```
dev/
└── terraform.tfstate
```

 This is a nice way to visually confirm that Terraform is now using remote state.

---

 # 2.34 What happens to `.terraform/`?

 After:

```
terraform init
```

 you'll have:

```
.terraform/
```

 on your local machine.

 That's normal.

 It contains Terraform's local working data and provider/module information.

 But:

 **Do not commit `.terraform/` to Git.**

---

 # 2.35 What should we commit?

 Commit:

```
*.tf
```

 For example:

```
backend.tf
main.tf
outputs.tf
provider.tf
variables.tf
versions.tf
```

 Commit:

```
.terraform.lock.hcl
```

 Do **not** commit:

```
.terraform/
```

 Do **not** commit:

```
*.tfstate
```

 Terraform state now belongs in S3.

 Also be careful with:

```
*.tfvars
```

 If a `.tfvars` file contains secrets, don't commit it.

 Our current `terraform.tfvars` only contains non-secret environment configuration, but we'll establish a better secrets strategy later.

---

 # 2.36 Our Step 2 directory

 After completing this step, your directory should look roughly like:

```
infra/
└── terraform/
    └── envs/
        └── dev/
            ├── .terraform/
            ├── .terraform.lock.hcl
            ├── backend.tf
            ├── main.tf
            ├── outputs.tf
            ├── provider.tf
            ├── terraform.tfvars
            ├── variables.tf
            └── versions.tf
```

 Remember:

```
.terraform/
```

 is local working data and should be ignored by Git.

---

 # 2.37 What each file does

 | File | Purpose |
| --- | --- |
| `versions.tf` | Terraform and provider versions |
| `backend.tf` | Where Terraform stores state |
| `provider.tf` | How Terraform communicates with AWS |
| `variables.tf` | Defines Terraform inputs |
| `terraform.tfvars` | Provides environment values |
| `main.tf` | Main Terraform configuration |
| `outputs.tf` | Displays useful results |

The two files to remember are:

```
provider.tf
    ↓
How do I talk to AWS?
```

 and:

```
backend.tf
    ↓
Where do I store Terraform state?
```

---

 # 2.38 Local AWS credentials vs Remote State

 These are completely different things.

 ## AWS authentication

 This answers:

 > How does Terraform get permission to access AWS?

 For local development:

```
AWS credentials
      │
      ▼
AWS Provider
      │
      ▼
AWS
```

 Later we'll use:

```
GitHub Actions
      │
      ▼
OIDC
      │
      ▼
AWS IAM Role
      │
      ▼
AWS Provider
```

---

 ## Terraform state

 This answers:

 > Where does Terraform store its state?

```
Terraform
    │
    ▼
S3 Backend
    │
    ▼
S3
```

 Therefore:

 **S3 remote state does not authenticate Terraform to AWS.**

 And:

 **AWS credentials do not determine where Terraform state is stored.**

 They're separate concepts.

---

 # 2.39 Future GitHub Actions architecture

 Eventually we'll have:

```
                       GitHub
                          │
                          ▼
                  GitHub Actions
                          │
                          │ OIDC
                          ▼
                     AWS IAM Role
                          │
                          ▼
                     Terraform
                      │       │
                      │       │
                      ▼       ▼
                AWS Provider  S3 Backend
                      │       │
                      ▼       ▼
                     AWS     State
```

 The security goal is:

 > No permanent AWS access keys stored in GitHub.

 We'll implement GitHub OIDC later.

---

 # 2.40 Beginner Terraform workflow

 From this point forward, use this workflow whenever you change Terraform:

```
1. Write/change Terraform code
             │
             ▼
2. terraform fmt
             │
             ▼
3. terraform validate
             │
             ▼
4. terraform plan
             │
             ▼
5. Review the plan carefully
             │
             ▼
6. terraform apply
```

 Most importantly:

 > **Never blindly run `terraform apply`.**

 Always understand what Terraform plans to create, change, or destroy.

---

 # 2.41 Step 2 checklist

 ## AWS authentication

```
aws --version
```

```
aws sts get-caller-identity
```

```
aws sts get-caller-identity --query Account --output text
```

---

 ## Create S3 state bucket

 Choose **one**:

 ### Method A — AWS Console

```
S3
 ↓
Create bucket
 ↓
Unique bucket name
 ↓
ap-south-1
 ↓
Bucket owner enforced
 ↓
Block all public access
 ↓
Enable versioning
 ↓
SSE-S3 encryption
 ↓
Create bucket
```

 ### Method B — AWS CLI

```
aws s3api create-bucket `
  --bucket YOUR-UNIQUE-TFSTATE-BUCKET `
  --region ap-south-1 `
  --create-bucket-configuration LocationConstraint=ap-south-1
```

 Then:

```
aws s3api put-bucket-versioning `
  --bucket YOUR-UNIQUE-TFSTATE-BUCKET `
  --versioning-configuration Status=Enabled
```

 Then:

```
aws s3api put-public-access-block `
  --bucket YOUR-UNIQUE-TFSTATE-BUCKET `
  --public-access-block-configuration `
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
```

 Then:

```
aws s3api put-bucket-ownership-controls `
  --bucket YOUR-UNIQUE-TFSTATE-BUCKET `
  --ownership-controls Rules=[{ObjectOwnership=BucketOwnerEnforced}]
```

 Then:

```
aws s3api put-bucket-encryption `
  --bucket YOUR-UNIQUE-TFSTATE-BUCKET `
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
```

---

 ## Terraform backend

 Create:

```
infra/terraform/envs/dev/backend.tf
```

 with:

```
terraform {
  backend "s3" {
    bucket       = "YOUR-UNIQUE-TFSTATE-BUCKET"
    key          = "dev/terraform.tfstate"
    region       = "ap-south-1"
    use_lockfile = true
    encrypt      = true
  }
}
```

---

 ## Initialize

```
cd infra\terraform\envs\dev
```

```
terraform init
```

---

 ## Format

```
terraform fmt -recursive
```

```
terraform fmt -check -recursive
```

---

 ## Validate

```
terraform validate
```

 Expected:

```
Success! The configuration is valid.
```

---

 ## Plan

```
terraform plan
```

 Expected:

```
No changes.
```

---

 ## Apply

```
terraform apply
```

 Expected:

```
Apply complete! Resources: 0 added, 0 changed, 0 destroyed.
```

---

 ## Check outputs

```
terraform output
```

 Expected:

```
aws_account_id = "123456789012"
aws_region     = "ap-south-1"
```

---

 ## Verify remote state

```
aws s3 ls s3://YOUR-UNIQUE-TFSTATE-BUCKET/dev/
```

 Expected:

```
terraform.tfstate
```

---

 # 2.42 Step 2 success criteria

 Step 2 is complete when:

```
AWS CLI authentication          ✓
          │
          ▼
AWS account identified          ✓
          │
          ▼
AWS Provider configured         ✓
          │
          ▼
Terraform can query AWS         ✓
          │
          ▼
S3 state bucket exists          ✓
          │
          ▼
S3 versioning enabled           ✓
          │
          ▼
Public access blocked           ✓
          │
          ▼
S3 encryption enabled           ✓
          │
          ▼
S3 native locking configured   ✓
          │
          ▼
Terraform state is remote       ✓
```

 And importantly:

```
Application AWS resources created = 0
```

 The only AWS infrastructure created so far is:

```
Terraform State S3 Bucket
```

---

 # 2.43 Final architecture after Step 2

 At this point:

```
                         AWS
                          │
             ┌────────────┴────────────┐
             │                         │
             ▼                         ▼
       AWS Provider               S3 Backend
             │                         │
             ▼                         ▼
       AWS Account              Terraform State
                                       │
                                       ▼
                                  S3 Lock File
```

 We have **not** created:

```
VPC                  ❌
Subnets              ❌
Internet Gateway     ❌
NAT Gateway          ❌
Security Groups      ❌
ECS                  ❌
RDS                  ❌
Load Balancer        ❌
Application IAM      ❌
```

 That's intentional.

---

 # 2.44 What's next — Step 3

 Now that we have:

```
Terraform
    │
    ├── AWS Provider ✓
    │
    ├── AWS authentication ✓
    │
    ├── S3 remote state ✓
    │
    └── State locking ✓
```

 we're ready to create our **first real application infrastructure**.

 ## STEP 3 — Network

 We'll build:

```
VPC
│
├── Availability Zone A
│   ├── Public Subnet
│   └── Private Subnet
│
├── Availability Zone B
│   ├── Public Subnet
│   └── Private Subnet
│
├── Internet Gateway
│
├── Route Tables
│
└── Security Groups
```

 And we'll learn what each piece means before writing the Terraform.

 The reusable code will live here:

```
infra/
└── terraform/
    └── modules/
        └── network/
```

 while the `dev` environment will call it:

```
module "network" {
  source = "../../modules/network"

  # configuration...
}
```

 So the architecture becomes:

```
envs/dev
    │
    ▼
network module
    │
    ▼
AWS VPC
    │
    ├── Public subnets
    ├── Private subnets
    ├── Internet Gateway
    └── Routes
```

 **Step 2 is therefore: AWS Provider + Remote S3 State + Native State Locking. Step 3 is where we start creating the actual application network.**