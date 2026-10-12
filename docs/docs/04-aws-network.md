# AWS Network Foundation

 ## Goal

 In this step, we will create the basic network that our application will use later.

 By the end, we'll have:

```
AWS
└── VPC
    │
    ├── Public Subnet A
    ├── Public Subnet B
    │
    ├── Private Subnet A
    ├── Private Subnet B
    │
    ├── Internet Gateway
    │
    ├── Public Route Table
    └── Private Route Table
```

 We will **not create ECS, RDS, ALB, or other application services yet**.

 We will also **not create a NAT Gateway yet**, because it costs money and we don't need it at this stage.

---

 # 3.1 First: understand what we're building

 Before writing Terraform, let's understand five AWS networking terms:

 1. VPC
2. Subnet
3. Availability Zone
4. Route Table
5. Internet Gateway

 Later we'll learn:

 6. Security Group

---

 # 3.2 What is a VPC?

 **VPC = Virtual Private Cloud**

 A VPC is your private network inside AWS.

 Think about it like a building.

```
AWS Cloud
┌───────────────────────────────────────┐
│                                       │
│              Your VPC                 │
│                                       │
│        10.0.0.0/16                   │
│                                       │
│        Your AWS network               │
│                                       │
└───────────────────────────────────────┘
```

 Our VPC will use:

```
10.0.0.0/16
```

 This is our application's main private network.

---

 # 3.3 What is a subnet?

 A subnet is a **smaller network inside the VPC**.

 Our VPC:

```
10.0.0.0/16
```

 will be divided into four subnets:

```
VPC
10.0.0.0/16
│
├── Public Subnet A
│   10.0.1.0/24
│
├── Public Subnet B
│   10.0.2.0/24
│
├── Private Subnet A
│   10.0.11.0/24
│
└── Private Subnet B
    10.0.12.0/24
```

 Think of the VPC as a large building and subnets as different rooms.

---

 # 3.4 What is an Availability Zone?

 An AWS **Region** is a geographical location.

 We're using:

```
ap-south-1
```

 which is the Mumbai AWS Region.

 Inside the region are multiple Availability Zones (AZs).

 For example:

```
ap-south-1
│
├── ap-south-1a
├── ap-south-1b
└── ap-south-1c
```

 We'll use two:

```
ap-south-1a
ap-south-1b
```

 Our network will therefore look like:

```
                 ap-south-1
                 Mumbai
                    │
          ┌─────────┴─────────┐
          │                   │
          ▼                   ▼
    ap-south-1a          ap-south-1b
          │                   │
          │                   │
     Public A             Public B
     Private A             Private B
```

 Why two AZs?

 Because we don't want our entire application to depend on a single physical AWS location.

 Later, ECS and other services can distribute workloads across both AZs.

---

 # 3.5 Public vs Private Subnets

 This is one of the most important concepts.

 ## Public subnet

 A public subnet has a route to the Internet through an Internet Gateway.

 Conceptually:

```
Internet
   │
   ▼
Internet Gateway
   │
   ▼
Public Subnet
```

 We'll eventually put something like an **Application Load Balancer (ALB)** in public subnets.

---

 ## Private subnet

 A private subnet does **not** have a direct route to the Internet Gateway.

```
Internet
   │
   X
   │
Private Subnet
```

 We'll eventually put things like:

```
ECS
RDS
```

 in private subnets.

 For example:

```
Internet
   │
   ▼
ALB
   │
   ▼
ECS
   │
   ▼
RDS
```

 This keeps internal services away from direct Internet access.

---

 # 3.6 What is an Internet Gateway?

 An **Internet Gateway (IGW)** is the connection between your VPC and the Internet.

 Think of it as the main entrance/exit of our building.

```
Internet
    │
    ▼
┌──────────────────┐
│ Internet Gateway │
└────────┬─────────┘
         │
         ▼
        VPC
```

 But there's an important detail:

 > Creating an Internet Gateway does not automatically make every subnet public.

 We also need routing.

---

 # 3.7 What is a Route Table?

 A route table tells AWS:

 > "Where should network traffic go?"

 For our public subnet, we'll create this route:

```
0.0.0.0/0
      │
      ▼
Internet Gateway
```

 `0.0.0.0/0` essentially means:

 > Any IPv4 destination.

 So the traffic flow becomes:

```
Public Subnet
     │
     ▼
Public Route Table
     │
     │ 0.0.0.0/0
     ▼
Internet Gateway
     │
     ▼
Internet
```

 That's what makes the subnet publicly routed.

---

 # 3.8 What about the private route table?

 Our private route table will **not** have:

```
0.0.0.0/0 → Internet Gateway
```

 So:

```
Private Subnet
      │
      ▼
Private Route Table
      │
      X
      │
   Internet
```

 This is intentional.

 Later, if our private ECS containers need outbound Internet access, we can introduce a **NAT Gateway**.

 For now:

```
Private subnet
      │
      X
   Internet
```

 is perfectly fine.

---

 # 3.9 Where do Security Groups fit?

 A **Security Group** is a network firewall attached to an AWS resource.

 It answers:

 > "Who is allowed to communicate with this resource?"

 For example, our eventual application will look like:

```
Internet
   │
   ▼
┌──────────────┐
│     ALB      │
└──────┬───────┘
       │
       ▼
┌──────────────┐
│     ECS      │
└──────┬───────┘
       │
       ▼
┌──────────────┐
│     RDS      │
└──────────────┘
```

 Security Groups could enforce:

```
Internet
   │
   │ 80/443
   ▼
ALB Security Group
   │
   │ application port
   ▼
ECS Security Group
   │
   │ 5432
   ▼
RDS Security Group
```

 ### Important distinction

 A **subnet** answers:

 > Where does the resource live?

 A **Security Group** answers:

 > Who can communicate with the resource?

 For example:

```
ECS
│
├── Location → Private Subnet
│
└── Firewall → ECS Security Group
```

 We will create the service-specific Security Groups when we introduce ALB, ECS, and RDS.

---

 # 3.10 Our target architecture

 Eventually, our application will look roughly like this:

```
                         INTERNET
                            │
                            ▼
                    ┌─────────────┐
                    │     ALB     │
                    │   Public    │
                    │   Subnets   │
                    └──────┬──────┘
                           │
                           ▼
                    ┌─────────────┐
                    │     ECS     │
                    │   Private   │
                    │   Subnets   │
                    └──────┬──────┘
                           │
                           ▼
                    ┌─────────────┐
                    │     RDS     │
                    │   Private   │
                    │   Subnets   │
                    └─────────────┘
```

 For now, we're only building the foundation:

```
                INTERNET
                    │
                    ▼
             Internet Gateway
                    │
                    ▼
        ┌───────────────────────┐
        │         VPC           │
        │      10.0.0.0/16      │
        │                       │
        │  Public   Public      │
        │    A        B         │
        │                       │
        │  Private  Private     │
        │    A        B         │
        └───────────────────────┘
```

---

 # 3.11 Terraform project structure

 Now that we understand the architecture, let's create it with Terraform.

 We'll use a reusable module:

```
infra/
└── terraform/
    │
    ├── modules/
    │   └── network/
    │       ├── main.tf
    │       ├── variables.tf
    │       └── outputs.tf
    │
    └── envs/
        └── dev/
            ├── main.tf
            ├── outputs.tf
            ├── provider.tf
            ├── terraform.tfvars
            ├── variables.tf
            └── versions.tf
```

 The important idea is:

```
modules/network
       ▲
       │
       │ reused by
       │
   envs/dev
```

 Later:

```
modules/network
       ▲
       │
 ┌─────┼──────────┐
 │     │          │
dev   stage      prod
```

---

 # 3.12 Create the network module

 From:

```
infra/terraform
```

 run:

```
mkdir modules\network
```

---

 # 3.13 Create `variables.tf`

 ### File

```
infra/terraform/modules/network/variables.tf
```

```
variable "project_name" {
  description = "Project name used for resource naming."
  type        = string
}

variable "environment" {
  description = "Deployment environment."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
}

variable "availability_zones" {
  description = "Availability zones used by the network."
  type        = list(string)

  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "At least two availability zones are required."
  }
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets."
  type        = list(string)

  validation {
    condition     = length(var.public_subnet_cidrs) == length(var.availability_zones)
    error_message = "Number of public subnet CIDRs must match availability zones."
  }
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets."
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_cidrs) == length(var.availability_zones)
    error_message = "Number of private subnet CIDRs must match availability zones."
  }
}
```

 ### What are variables?

 Variables are simply **inputs** to our module.

 For example:

```
vpc_cidr
    │
    ▼
10.0.0.0/16
```

 The module doesn't have to hard-code the network.

 We can give it different values for:

```
dev
stage
prod
```

---

 # 3.14 Create `main.tf`

 ### File

```
infra/terraform/modules/network/main.tf
```

```
locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${local.name_prefix}-vpc"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${local.name_prefix}-igw"
  }
}

resource "aws_subnet" "public" {
  count = length(var.availability_zones)

  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.name_prefix}-public-${count.index + 1}"
    Tier = "public"
  }
}

resource "aws_subnet" "private" {
  count = length(var.availability_zones)

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "${local.name_prefix}-private-${count.index + 1}"
    Tier = "private"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${local.name_prefix}-public-rt"
  }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${local.name_prefix}-private-rt"
  }
}

resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
```

### Quick note: where does `aws_vpc.this.id` come from?

When you see:

```hcl
vpc_id = aws_vpc.this.id
```

Terraform reads it as:

- `aws_vpc` → resource type
- `this` → resource label (name you chose in `resource "aws_vpc" "this"`)
- `id` → attribute returned by AWS provider (example: `vpc-0abc123...`)

So:

```hcl
resource "aws_vpc" "this" { ... }
```

creates the VPC, and then `aws_vpc.this.id` is used by other resources (like Internet Gateway, subnets, and route tables) to attach them to that same VPC.

---

 # 3.15 Understand the Terraform code

 You don't need to memorize this code.

 Just understand the pattern.

 ### Create VPC

```
resource "aws_vpc" "this" {
```

 means:

 > Terraform, create an AWS VPC.

---

 ### Create Internet Gateway

```
resource "aws_internet_gateway" "this" {
```

 means:

 > Terraform, create an Internet Gateway for this VPC.

---

 ### Create public subnets

```
resource "aws_subnet" "public" {
```

 means:

 > Terraform, create public subnets.

 This:

```
count = length(var.availability_zones)
```

 means:

 > Create one subnet for each Availability Zone.

 We have:

```
2 AZs
```

 so Terraform creates:

```
2 public subnets
```

 and:

```
2 private subnets
```

---

 # 3.16 Why are we using `count.index`?

 This can look confusing at first:

```
var.public_subnet_cidrs[count.index]
```

 Think of our list:

```
public_subnet_cidrs

0 → 10.0.1.0/24
1 → 10.0.2.0/24
```

 Terraform creates:

```
count.index = 0
        ↓
10.0.1.0/24
```

 Then:

```
count.index = 1
        ↓
10.0.2.0/24
```

 So we get:

```
AZ-a → 10.0.1.0/24
AZ-b → 10.0.2.0/24
```

---

 # 3.17 Create module outputs

 ### File

```
infra/terraform/modules/network/outputs.tf
```

```
output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC."
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets."
  value       = aws_subnet.private[*].id
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway."
  value       = aws_internet_gateway.this.id
}

output "public_route_table_id" {
  description = "ID of the public route table."
  value       = aws_route_table.public.id
}

output "private_route_table_id" {
  description = "ID of the private route table."
  value       = aws_route_table.private.id
}
```

 ### What is an output?

 An output is information that the module gives back to the environment.

 For example:

```
Network module
      │
      ├── VPC ID
      ├── Public subnet IDs
      └── Private subnet IDs
```

 Later ECS can use:

```
module.network.private_subnet_ids
```

 without needing to know how the subnets were created.

---

 # 3.18 Configure the dev environment

 Now we tell our `dev` environment what network we want.

 Update:

```
infra/terraform/envs/dev/variables.tf
```

 with:

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

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
}

variable "availability_zones" {
  description = "Availability zones used by the environment."
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets."
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets."
  type        = list(string)
}
```

---

 # 3.19 Configure `terraform.tfvars`

 ### File

```
infra/terraform/envs/dev/terraform.tfvars
```

```
aws_region   = "ap-south-1"
project_name = "ai-engineering-platform"
environment  = "dev"

vpc_cidr = "10.0.0.0/16"

availability_zones = [
  "ap-south-1a",
  "ap-south-1b"
]

public_subnet_cidrs = [
  "10.0.1.0/24",
  "10.0.2.0/24"
]

private_subnet_cidrs = [
  "10.0.11.0/24",
  "10.0.12.0/24"
]
```

 Our final network will be:

```
VPC
10.0.0.0/16
│
├── ap-south-1a
│   ├── Public  10.0.1.0/24
│   └── Private 10.0.11.0/24
│
└── ap-south-1b
    ├── Public  10.0.2.0/24
    └── Private 10.0.12.0/24
```

---

 # 3.20 Connect the module to dev

 Update:

```
infra/terraform/envs/dev/main.tf
```

```
data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

module "network" {
  source = "../../modules/network"

  project_name = var.project_name
  environment = var.environment

  vpc_cidr = var.vpc_cidr

  availability_zones = var.availability_zones

  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}
```

 The important part is:

```
module "network" {
  source = "../../modules/network"
}
```

 This tells Terraform:

 > Use the network module located at `modules/network`.

 The relationship is:

```
envs/dev
    │
    │ uses
    ▼
modules/network
    │
    │ creates
    ▼
AWS VPC + Subnets + Routes
```

---

 # 3.21 Export the network information

 Update:

```
infra/terraform/envs/dev/outputs.tf
```

```
output "aws_account_id" {
  description = "AWS account ID used by Terraform."
  value       = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  description = "AWS region used by Terraform."
  value       = data.aws_region.current.region
}

output "vpc_id" {
  description = "ID of the dev VPC."
  value       = module.network.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets."
  value       = module.network.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of the private subnets."
  value       = module.network.private_subnet_ids
}
```

---

 # 3.22 Now let Terraform check our work

 Go to:

```
cd infra\terraform\envs\dev
```

 Run:

```
terraform fmt -recursive
```

 Then:

```
terraform fmt -check -recursive
```

 Then:

```
terraform validate
```

 Expected:

```
Success! The configuration is valid.
```

---

 # 3.23 Initialize the module

 Because we've added a module, run:

```
terraform init
```

 You should see something similar to:

```
Initializing modules...
- network in ../../modules/network
```

---

 # 3.24 Preview before creating anything

 This is one of the most important Terraform habits:

 > **Always run `terraform plan` before `terraform apply`.**

 Run:

```
terraform plan
```

 Terraform should show resources being added.

 You should see resources related to:

```
VPC
Internet Gateway
Public subnets
Private subnets
Public route table
Private route table
Routes
Route table associations
```

 You should see:

```
0 to change
0 to destroy
```

 and some number greater than zero for:

```
to add
```

---

 # 3.25 Important: don't blindly trust the number

 You may see something like:

```
Plan: 11 to add, 0 to change, 0 to destroy.
```

 The exact number isn't the important part.

 What matters is that the plan contains the resources we expect.

 Look for things such as:

```
aws_vpc
aws_internet_gateway
aws_subnet.public
aws_subnet.private
aws_route_table.public
aws_route_table.private
aws_route.public_internet
```

 If Terraform wants to **destroy** resources unexpectedly:

```
0 to destroy
```

 should become your warning signal.

 Stop and investigate before applying.

---

 # 3.26 Create the network

 If the plan looks correct:

```
terraform apply
```

 Terraform will ask for confirmation.

 You'll see:

```
Do you want to perform these actions?
```

 Enter:

```
yes
```

 Terraform will now create the network in AWS.

---

 # 3.27 Verify Terraform outputs

 Run:

```
terraform output
```

 You should see values similar to:

```
aws_account_id = "123456789012"

aws_region = "ap-south-1"

private_subnet_ids = [
  "subnet-xxxxxxxx",
  "subnet-yyyyyyyy"
]

public_subnet_ids = [
  "subnet-aaaaaaaa",
  "subnet-bbbbbbbb"
]

vpc_id = "vpc-xxxxxxxx"
```

 Your IDs will obviously be different.

---

 # 3.28 Verify in AWS Console

 Open the AWS Console.

 Go to:

 **VPC → Your VPCs**

 You should see your VPC.

 Then:

 **VPC → Subnets**

 You should see four subnets:

```
ai-engineering-platform-dev-public-1
ai-engineering-platform-dev-public-2

ai-engineering-platform-dev-private-1
ai-engineering-platform-dev-private-2
```

 You can also inspect:

 **VPC → Route Tables**

 You should find:

```
dev-public-rt
dev-private-rt
```

---

 # 3.29 What we have created

 Our AWS environment now looks like:

```
                         AWS
                          │
                          ▼
                 ┌────────────────┐
                 │      VPC       │
                 │  10.0.0.0/16   │
                 └───────┬────────┘
                         │
             ┌───────────┴───────────┐
             │                       │
             ▼                       ▼
       ap-south-1a             ap-south-1b
             │                       │
       ┌─────┴─────┐           ┌─────┴─────┐
       │           │           │           │
       ▼           ▼           ▼           ▼
    Public      Private     Public      Private
    Subnet      Subnet      Subnet      Subnet
```

 And Internet connectivity:

```
                    Internet
                       │
                       ▼
                Internet Gateway
                       │
                       ▼
                  Public Route
                    Table
                       │
                 ┌─────┴─────┐
                 ▼           ▼
              Public A    Public B
```

 Private subnets currently have:

```
Private A
    │
    ▼
Private Route Table
    │
    X
Internet
```

 and:

```
Private B
    │
    ▼
Private Route Table
    │
    X
Internet
```

---

 # 3.30 Why aren't we creating a NAT Gateway?

 You may hear:

 > "Private subnets need a NAT Gateway."

 That's not always true.

 A NAT Gateway is needed when resources in a private subnet need **outbound Internet access**.

 For example:

```
ECS Private Subnet
       │
       ▼
NAT Gateway
       │
       ▼
Internet
```

 But NAT Gateways have ongoing AWS costs.

 At this stage we're learning and building the foundation, so we're deliberately not adding one.

 Later, we'll decide whether our ECS architecture needs one.

---

 # 3.31 Why aren't we creating Security Groups yet?

 Security Groups are important, but they make more sense when we know which services need them.

 Eventually we'll have:

```
ALB
 │
 │ allowed by ALB SG
 ▼
ECS
 │
 │ allowed by ECS SG
 ▼
RDS
```

 For example:

```
ALB Security Group
    │
    └── Internet → 443

ECS Security Group
    │
    └── ALB → application port

RDS Security Group
    │
    └── ECS → PostgreSQL 5432
```

 We'll create these when we introduce the corresponding services.

 This gives each Security Group a clear purpose instead of creating generic firewall rules that are too permissive.

---

 # 3.32 Terraform mental model

 There are three Terraform concepts you should understand from this step.

 ## Variables

 Variables are **inputs**.

```
dev configuration
       │
       ▼
variables
       │
       ▼
network module
```

 Example:

```
vpc_cidr = "10.0.0.0/16"
```

---

 ## Resources

 Resources are things Terraform creates.

 For example:

```
resource "aws_vpc" "this"
```

 means:

 > Create/manage an AWS VPC.

---

 ## Outputs

 Outputs are information Terraform gives back.

```
network module
      │
      ├── VPC ID
      ├── Public subnet IDs
      └── Private subnet IDs
```

 Later another module can use those outputs.

---

 # 3.33 Why use modules?

 Without modules, we could put everything into:

```
envs/dev/main.tf
```

 But that's difficult to maintain.

 Instead:

```
modules/
└── network/
```

 contains the reusable network design.

 Then:

```
envs/
├── dev/
├── stage/
└── prod/
```

 can all use it.

 Conceptually:

```
                Network Module
                      │
          ┌───────────┼───────────┐
          │           │           │
          ▼           ▼           ▼
         Dev        Stage        Prod
```

 The architecture stays consistent while configuration can differ.

---

 # 3.34 Final STEP 3 checklist

 Before moving on, make sure all of these are true:

 ### Terraform

```
terraform fmt -check -recursive
```

 works.

```
terraform validate
```

 returns:

```
Success! The configuration is valid.
```

```
terraform plan
```

 shows:

```
0 to change
0 to destroy
```

 and the expected resources to add.

 ### AWS

 You can see:

```
1 VPC
4 Subnets
2 Route Tables
1 Internet Gateway
```

 approximately matching our design.

 ### Architecture

 You understand:

```
VPC
 ↓
Subnets
 ↓
Route Tables
 ↓
Internet Gateway
```

 and the difference between:

```
Public subnet
Private subnet
Security Group
```

---

 # One important correction to our overall learning path

 There is one thing I would change from the earlier plan.

 We shouldn't jump immediately from:

```
Network
   ↓
ECR
```

 without understanding **why ECR exists**.

 A better learning sequence is:

```
STEP 1
Terraform Foundation
        │
        ▼
STEP 2
AWS Provider + Authentication
        │
        ▼
STEP 3
Remote State
        │
        ▼
STEP 4
AWS Networking
        │
        ▼
STEP 5
ECR
        │
        ▼
STEP 6
IAM
        │
        ▼
STEP 7
ECS
        │
        ▼
STEP 8
ALB
        │
        ▼
STEP 9
RDS
        │
        ▼
STEP 10
Secrets Manager
        │
        ▼
STEP 11
CloudWatch
        │
        ▼
STEP 12
GitHub OIDC
        │
        ▼
STEP 13
GitHub Actions
```

 And **Remote State should actually come before creating this VPC**. If you haven't implemented it yet, I'd pause here rather than continue creating AWS resources.

 Your Terraform state currently needs to be managed safely:

```
Terraform
    │
    ▼
S3 Remote State
    │
    ▼
AWS infrastructure
```

 rather than relying on a local:

```
terraform.tfstate
```

 That is especially important because you're building this for **multiple environments and GitHub Actions**.

 So the clean beginner-friendly progression should be:

```
Foundation
    ↓
AWS authentication
    ↓
Remote state
    ↓
Network
    ↓
ECR
    ↓
IAM
    ↓
ECS
    ↓
ALB
    ↓
RDS
    ↓
Secrets
    ↓
Monitoring
    ↓
GitHub OIDC
    ↓
CI/CD
```

 **I recommend doing Remote State before applying the Step 3 network plan.** This avoids having to migrate your first real AWS state later.