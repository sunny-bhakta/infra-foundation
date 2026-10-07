# RDS / PostgreSQL

## Goal

We currently have:

```text
Internet
   │
   ▼
ALB
   │
   ▼
ECS / Fargate
   │
   ▼
NestJS
```

Our NestJS application now needs a database.

We'll add:

```text
ECS / Fargate
      │
      │ PostgreSQL :5432
      ▼
   RDS PostgreSQL
```

The important security idea is:

```text
Internet
   │
   ▼
  ALB
   │
   ▼
ECS / NestJS
   │
   ▼
RDS PostgreSQL
```

**The internet should never connect directly to RDS.**

---

# 1. What is RDS?

RDS means:

> **Relational Database Service**

AWS RDS manages a relational database server for us.

Instead of manually creating a server and installing PostgreSQL:

```text
EC2
 │
 ├── Install PostgreSQL
 ├── Configure PostgreSQL
 ├── Manage updates
 ├── Manage backups
 └── Manage storage
```

we can say:

```text
AWS RDS
   │
   └── PostgreSQL
```

AWS handles much of the infrastructure management.

---

# 2. What is PostgreSQL?

PostgreSQL is the actual database engine.

So remember:

```text
RDS
 │
 └── PostgreSQL
```

RDS is the AWS managed service.

PostgreSQL is the database software.

---

# 3. Why are we using RDS?

Our NestJS application will eventually need things like:

```text
users
organizations
projects
conversations
messages
documents
```

Instead of storing this data inside the application container:

```text
ECS Container
└── Database ❌
```

we separate them:

```text
ECS
└── NestJS

RDS
└── PostgreSQL
```

This is much better because the application container can be replaced without losing our database.

---

# 4. Very important: Container vs database

This distinction is important for beginners.

Our ECS container is **temporary**.

For example:

```text
Task 1
   │
   └── NestJS
```

Tomorrow ECS might replace it:

```text
Task 1
   │
   X

Task 2
   │
   └── NestJS
```

We don't want our application data to disappear.

Therefore:

```text
ECS
  =
temporary application compute

RDS
  =
persistent database
```

---

# 5. Our architecture

The target architecture is:

```text
                         Internet
                            │
                            ▼
                          ALB
                            │
                            ▼
                     ECS / Fargate
                            │
                            │ :5432
                            ▼
                    ┌──────────────┐
                    │ RDS          │
                    │ PostgreSQL   │
                    └──────────────┘
```

But there's another important piece:

```text
Security Groups
```

We'll use them to control who can talk to PostgreSQL.

---

# 6. PostgreSQL port

PostgreSQL normally listens on:

```text
5432
```

So our communication is:

```text
NestJS
   │
   │ TCP 5432
   ▼
PostgreSQL
```

---

# 7. The security rule we want

We want:

```text
ECS Security Group
        │
        │ TCP 5432
        ▼
RDS Security Group
```

But we **do not** want:

```text
Internet
   │
   │ TCP 5432
   ▼
RDS
```

Therefore the RDS security group should only allow PostgreSQL traffic from the ECS security group.

---

# 8. Think of security groups as doors

Imagine RDS is a room:

```text
┌──────────────────────┐
│      PostgreSQL      │
│                      │
│       RDS            │
└──────────────────────┘
          ▲
          │
       Door :5432
```

We tell AWS:

> Only ECS is allowed through this door.

So:

```text
ECS ───────► RDS :5432 ✅

Internet ──► RDS :5432 ❌
```

This is an important production security principle.

---

# 9. RDS needs subnets

RDS doesn't just float somewhere in AWS.

It needs to live inside our VPC.

Our VPC looks roughly like:

```text
VPC
│
├── Public Subnets
│      └── ALB
│
└── Private Subnets
       ├── ECS
       └── RDS
```

Notice:

```text
ALB → Public

ECS → Private

RDS → Private
```

---

# 10. What is an RDS subnet group?

This is another new AWS concept.

An RDS subnet group tells RDS:

> These are the subnets where your database is allowed to run.

For example:

```text
RDS Subnet Group
│
├── private-subnet-a
└── private-subnet-b
```

AWS can then place the database appropriately.

---

# 11. Why multiple subnets?

For production, we normally spread infrastructure across multiple Availability Zones.

Conceptually:

```text
AWS Region
│
├── Availability Zone A
│     └── Private subnet
│
└── Availability Zone B
      └── Private subnet
```

Our RDS subnet group can contain private subnets from both AZs.

This provides the foundation for high availability.

---

# 12. Our Terraform module

Earlier we planned:

```text
infra/
└── terraform/
    └── modules/
        ├── network/
        ├── compute/
        ├── iam/
        └── data/
```

We decided that database-related resources belong in:

```text
modules/data/
```

So we'll use:

```text
infra/terraform/modules/data/
```

Eventually:

```text
data/
├── main.tf
├── variables.tf
└── outputs.tf
```

---

# 13. First: RDS security group

Create:

```text
infra/terraform/modules/data/main.tf
```

Add:

```hcl
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-${var.environment}-rds-sg"
  description = "Security group for PostgreSQL RDS."
  vpc_id      = var.vpc_id

  ingress {
    description     = "PostgreSQL from ECS"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.ecs_security_group_id]
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-rds-sg"
  }
}
```

The most important part is:

```hcl
security_groups = [var.ecs_security_group_id]
```

This means:

> Allow PostgreSQL connections from the ECS security group.

---

# 14. Variables

Create:

```text
infra/terraform/modules/data/variables.tf
```

Add:

```hcl
variable "project_name" {
  description = "Project name."
  type        = string
}

variable "environment" {
  description = "Deployment environment."
  type        = string
}

variable "vpc_id" {
  description = "VPC where RDS will run."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for RDS."
  type        = list(string)
}

variable "ecs_security_group_id" {
  description = "Security group used by ECS tasks."
  type        = string
}
```

---

# 15. RDS subnet group

Now create:

```hcl
resource "aws_db_subnet_group" "app" {
  name = "${var.project_name}-${var.environment}-db"

  subnet_ids = var.private_subnet_ids

  tags = {
    Name = "${var.project_name}-${var.environment}-db-subnet-group"
  }
}
```

Remember:

```text
DB subnet group
      │
      ├── Private subnet A
      └── Private subnet B
```

RDS will use these subnets.

---

# 16. Database password

This is very important.

We **must not** do this:

```hcl
password = "MyPassword123"
```

Why?

Because Terraform configuration is source code.

We don't want database credentials sitting inside Git.

Instead, we'll generate a password.

We can use:

```hcl
resource "random_password" "db" {
  length  = 32
  special = true
}
```

This generates a random password.

---

# 17. Add the random provider

Our `versions.tf` needs the Random provider.

In the appropriate Terraform environment/module setup, add:

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
  }
}
```

Then:

```powershell
terraform init
```

Terraform downloads the provider.

---

# 18. Create the RDS instance

Now:

```hcl
resource "aws_db_instance" "postgres" {
  identifier = "${var.project_name}-${var.environment}-postgres"

  engine         = "postgres"
  engine_version = "17"

  instance_class = var.db_instance_class

  allocated_storage = var.db_allocated_storage
  storage_type      = "gp3"

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db.result

  port = 5432

  db_subnet_group_name   = aws_db_subnet_group.app.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  publicly_accessible = false

  backup_retention_period = var.backup_retention_period

  deletion_protection = var.deletion_protection

  skip_final_snapshot = var.skip_final_snapshot

  tags = {
    Name = "${var.project_name}-${var.environment}-postgres"
  }
}
```

Let's break this down carefully.

---

# 19. `engine`

```hcl
engine = "postgres"
```

This tells RDS:

> Use PostgreSQL.

---

# 20. `engine_version`

```hcl
engine_version = "17"
```

We're choosing PostgreSQL 17.

The exact version should be validated against the AWS region/account options before applying. The important concept is:

```text
RDS
└── PostgreSQL
```

---

# 21. Instance class

```hcl
instance_class = var.db_instance_class
```

This determines the compute capacity of the database.

For example:

```text
db.t4g.micro
```

or another currently available small instance class.

We'll keep this configurable by environment rather than hard-coding it inside the module.

---

# 22. Storage

```hcl
allocated_storage = var.db_allocated_storage
```

For development we might choose something small such as:

```text
20 GB
```

Again, make it an environment variable.

---

# 23. Database name

```hcl
db_name = var.db_name
```

For example:

```text
appdb
```

So PostgreSQL starts with:

```text
Database:
appdb
```

---

# 24. Username

```hcl
username = var.db_username
```

For example:

```text
appuser
```

Don't use:

```text
postgres
```

as your application's normal database user unless you have a specific reason.

A dedicated application user is a better practice.

---

# 25. Password

This is where our generated password is used:

```hcl
password = random_password.db.result
```

So:

```text
random_password
       │
       ▼
32-character password
       │
       ▼
RDS
```

We still need to think about how the application gets this credential.

We'll solve that using **Secrets Manager** in the next step.

---

# 26. `publicly_accessible = false`

This is extremely important.

```hcl
publicly_accessible = false
```

means:

> Don't expose the database directly to the public internet.

Our architecture remains:

```text
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

Not:

```text
Internet
   │
   ▼
RDS ❌
```

---

# 27. Backups

We have:

```hcl
backup_retention_period = var.backup_retention_period
```

RDS can automatically retain backups.

For example:

```text
Dev:
1 day

Stage:
7 days

Prod:
7–30 days
```

The exact values should reflect your cost/recovery requirements.

---

# 28. Deletion protection

We also have:

```hcl
deletion_protection = var.deletion_protection
```

This is useful for production.

For example:

```text
dev
→ false

prod
→ true
```

With deletion protection enabled, accidentally deleting the RDS instance becomes much harder.

---

# 29. Final snapshot

We also have:

```hcl
skip_final_snapshot = var.skip_final_snapshot
```

For development:

```text
true
```

might be acceptable.

For production:

```text
false
```

is generally safer because you can retain a final snapshot when deleting the instance.

---

# 30. Add variables

Add these to:

```text
infra/terraform/modules/data/variables.tf
```

```hcl
variable "db_instance_class" {
  description = "RDS instance class."
  type        = string
}

variable "db_allocated_storage" {
  description = "Allocated storage in GB."
  type        = number
}

variable "db_name" {
  description = "Initial PostgreSQL database name."
  type        = string
}

variable "db_username" {
  description = "Application database username."
  type        = string
}

variable "backup_retention_period" {
  description = "Number of days to retain automated backups."
  type        = number
}

variable "deletion_protection" {
  description = "Whether deletion protection is enabled."
  type        = bool
}

variable "skip_final_snapshot" {
  description = "Whether to skip the final snapshot when destroying RDS."
  type        = bool
}
```

---

# 31. Connect the environment to the data module

Now open:

```text
infra/terraform/envs/dev/main.tf
```

Add:

```hcl
module "data" {
  source = "../../modules/data"

  project_name = var.project_name
  environment  = var.environment

  vpc_id = module.network.vpc_id

  private_subnet_ids    = module.network.private_subnet_ids
  ecs_security_group_id = module.network.ecs_security_group_id

  db_instance_class = var.db_instance_class

  db_allocated_storage = var.db_allocated_storage

  db_name     = var.db_name
  db_username = var.db_username

  backup_retention_period = var.backup_retention_period

  deletion_protection = var.deletion_protection
  skip_final_snapshot = var.skip_final_snapshot
}
```

Again, use the **actual output names from your existing network module**.

---

# 32. Environment variables

Now open:

```text
infra/terraform/envs/dev/variables.tf
```

Add:

```hcl
variable "db_instance_class" {
  description = "RDS instance class for this environment."
  type        = string
}

variable "db_allocated_storage" {
  description = "RDS storage size in GB."
  type        = number
}

variable "db_name" {
  description = "Application database name."
  type        = string
}

variable "db_username" {
  description = "Application database username."
  type        = string
}

variable "backup_retention_period" {
  description = "RDS backup retention in days."
  type        = number
}

variable "deletion_protection" {
  description = "Enable RDS deletion protection."
  type        = bool
}

variable "skip_final_snapshot" {
  description = "Skip final RDS snapshot on destroy."
  type        = bool
}
```

---

# 33. Dev configuration

In:

```text
infra/terraform/envs/dev/terraform.tfvars
```

we can have something like:

```hcl
db_instance_class = "db.t4g.micro"

db_allocated_storage = 20

db_name     = "appdb"
db_username = "appuser"

backup_retention_period = 1

deletion_protection = false

skip_final_snapshot = true
```

**Before applying**, verify that the chosen instance class and PostgreSQL version are available in your selected AWS region and fit your current AWS account/free-tier eligibility.

---

# 34. Very important: database password and Terraform state

There is a subtle but important issue here.

We generated:

```hcl
random_password.db.result
```

and used it for:

```hcl
password = random_password.db.result
```

Terraform needs to know that value in order to manage the RDS resource.

Therefore, sensitive information can end up in Terraform state.

This is one reason why **Terraform state must be treated as sensitive**.

And this connects directly to the earlier topic we discussed:

> **Remote Terraform state**

For a real GitHub Actions setup, we should store Terraform state remotely and securely rather than committing:

```text
terraform.tfstate
```

to Git.

---

# 35. What we should eventually do

Our production architecture should become:

```text
Terraform
   │
   ▼
Remote State
   │
   ▼
Encrypted state
```

and:

```text
RDS
   │
   ▼
Secrets Manager
   │
   ▼
NestJS
```

We'll cover Secrets Manager next.

---

# 36. Outputs

Create:

```text
infra/terraform/modules/data/outputs.tf
```

Add:

```hcl
output "db_instance_endpoint" {
  description = "RDS PostgreSQL endpoint."
  value       = aws_db_instance.postgres.address
}

output "db_instance_port" {
  description = "RDS PostgreSQL port."
  value       = aws_db_instance.postgres.port
}

output "db_name" {
  description = "Database name."
  value       = aws_db_instance.postgres.db_name
}

output "db_username" {
  description = "Database username."
  value       = aws_db_instance.postgres.username
}

output "rds_security_group_id" {
  description = "Security group ID for RDS."
  value       = aws_security_group.rds.id
}
```

Notice we're **not outputting the password**.

That's intentional.

---

# 37. Environment outputs

In:

```text
infra/terraform/envs/dev/outputs.tf
```

we can expose:

```hcl
output "db_endpoint" {
  description = "RDS endpoint."
  value       = module.data.db_instance_endpoint
}

output "db_port" {
  description = "RDS PostgreSQL port."
  value       = module.data.db_instance_port
}
```

After apply, you'll get something like:

```text
db_endpoint = "ai-engineering-platform-dev-postgres.xxxxx.ap-south-1.rds.amazonaws.com"
db_port     = 5432
```

---

# 38. How NestJS will eventually connect

Your NestJS application will eventually need something conceptually like:

```text
DATABASE_HOST
DATABASE_PORT
DATABASE_NAME
DATABASE_USER
DATABASE_PASSWORD
```

For example:

```text
DATABASE_HOST     → RDS endpoint
DATABASE_PORT     → 5432
DATABASE_NAME     → appdb
DATABASE_USER     → appuser
DATABASE_PASSWORD → secret
```

But we **should not put the password in `terraform.tfvars` or GitHub**.

That's why the next step is Secrets Manager.

---

# 39. RDS connection flow

Eventually:

```text
                   AWS
                    │
             ┌──────┴──────┐
             │             │
           ECS           RDS
             │             │
             │             │
             └─────┬───────┘
                   │
                TCP 5432
```

Security groups enforce:

```text
ECS SG
  │
  │ allowed
  ▼
RDS SG
```

---

# 40. Full architecture so far

We're now building:

```text
                         Internet
                            │
                            ▼
                     ┌────────────┐
                     │    ALB     │
                     │ Public     │
                     └─────┬──────┘
                           │
                           ▼
                    ┌─────────────┐
                    │ ECS/Fargate │
                    │ Private     │
                    │ NestJS :3000│
                    └──────┬──────┘
                           │
                           │ PostgreSQL :5432
                           ▼
                    ┌─────────────┐
                    │ RDS         │
                    │ PostgreSQL  │
                    │ Private     │
                    └─────────────┘
```

And security:

```text
Internet
   │
   │ :80
   ▼
ALB SG
   │
   │ :3000
   ▼
ECS SG
   │
   │ :5432
   ▼
RDS SG
```

This is the key concept I want you to remember.

---

# 41. What does Terraform create?

At this step:

```text
Terraform
   │
   ├── RDS Subnet Group
   │
   ├── RDS Security Group
   │
   ├── Random DB Password
   │
   └── RDS PostgreSQL
```

And AWS gives us:

```text
RDS PostgreSQL
      │
      ├── Endpoint
      ├── Port 5432
      ├── Database
      └── Persistent storage
```

---

# 42. Before running `apply`

Run:

```powershell
cd infra\terraform\envs\dev
```

Then:

```powershell
terraform fmt -recursive
```

Then:

```powershell
terraform init
```

Then:

```powershell
terraform validate
```

Then:

```powershell
terraform plan
```

**Do not immediately apply if you're using a paid RDS configuration.**

RDS can incur charges depending on instance class, storage, backups, and other settings.

For your AWS account, verify the current pricing/free-tier eligibility before creating it.

---

# 43. One more important beginner concept

Don't confuse:

```text
RDS
```

with:

```text
database
```

More precisely:

```text
AWS RDS
   │
   └── PostgreSQL database engine
          │
          └── appdb
                │
                ├── users
                ├── projects
                ├── conversations
                └── messages
```

So:

* **RDS** = AWS managed database service
* **PostgreSQL** = database engine
* **appdb** = our database
* **tables** = data structure inside the database

---

# 44. Where we are now

Our learning path is becoming:

|  Step | AWS component       | Purpose                         |
| ----: | ------------------- | ------------------------------- |
|     1 | Terraform           | Infrastructure foundation       |
|     2 | AWS Provider        | Connect Terraform to AWS        |
|     3 | VPC/Network         | Networking                      |
|     4 | ECR                 | Store Docker images             |
|     5 | IAM                 | Permissions                     |
|     6 | ECS/Fargate         | Run NestJS                      |
|     7 | ALB                 | Receive HTTP traffic            |
| **8** | **RDS PostgreSQL**  | **Persistent database**         |
| **9** | **Secrets Manager** | **Secure database credentials** |
|    10 | CloudWatch          | Logs/monitoring                 |
|    11 | GitHub Actions      | Build/deploy                    |
|    12 | Hardening           | HTTPS/scaling/security          |

### The next topic is especially important:

**Step 9 — AWS Secrets Manager**

We'll take the database credentials we just created and learn how to securely store them so that:

```text
RDS password
     │
     ▼
Secrets Manager
     │
     ▼
ECS / NestJS
```

instead of putting passwords in:

```text
❌ Git
❌ terraform.tfvars
❌ Dockerfile
❌ GitHub Actions YAML
❌ source code
```
