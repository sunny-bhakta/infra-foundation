# ECS + Fargate

### Goal


```text
ECR
 │
 │ stores our container image
 ▼
ECS + Fargate
 │
 │ runs the container
 ▼
NestJS application
```

At the end of this step, you'll understand:

* What ECS is
* What Fargate is
* What a cluster is
* What a task definition is
* What a task is
* What an ECS service is
* How ECS gets an image from ECR
* How ECS uses the IAM roles we just created
* How Terraform creates all of this

We will **not add the ALB yet**. We'll first get the ECS/Fargate foundation right.

---

# 1. First: Why do we need ECS?

We already created ECR.

Remember:

```text
ECR = stores container images
```

But ECR doesn't run the application.

Suppose our NestJS application is packaged as:

```text
ai-engineering-platform:1.0.0
```

and stored in:

```text
ECR
└── ai-engineering-platform-dev
       └── 1.0.0
```

Something still needs to run that image.

That's where **ECS** comes in.

---

# 2. What is ECS?

ECS stands for:

> **Elastic Container Service**

In simple terms:

> ECS is an AWS service that manages and runs containers.

Our flow becomes:

```text
NestJS source code
       │
       ▼
Container image
       │
       ▼
ECR
       │
       ▼
ECS
       │
       ▼
Running NestJS container
```

---

# 3. What is Fargate?

This is another important concept.

There are different ways to run containers with ECS.

One option is managing your own EC2 servers.

Another option is:

> **AWS Fargate**

Fargate allows AWS to manage the underlying servers for us.

So instead of:

```text
You
 │
 ├── create EC2
 ├── manage OS
 ├── patch servers
 ├── manage capacity
 └── manage Docker runtime
```

we say:

```text
You
 │
 └── "AWS, run this container"
             │
             ▼
          Fargate
```

AWS handles the underlying compute infrastructure.

For our project:

```text
ECS = container orchestration
Fargate = compute that runs the containers
```

Remember that distinction.

---

# 4. Simple analogy

Imagine a restaurant.

```text
ECR
=
Food storage
```

```text
ECS
=
Restaurant manager
```

```text
Fargate
=
Kitchen infrastructure
```

```text
Container
=
Prepared meal
```

ECS tells Fargate:

> "Run this container."

Fargate provides the compute required to run it.

---

# 5. ECS architecture

Our target architecture looks like:

```text
                         AWS
                          │
                    ECS Cluster
                          │
                    ECS Service
                          │
                    ┌─────┴─────┐
                    │           │
                 Task 1       Task 2
                    │           │
                 Container   Container
                    │
                    ▼
             NestJS application
```

For development, we'll initially run:

```text
desired_count = 1
```

So:

```text
ECS Service
     │
     ▼
   Task 1
     │
     ▼
NestJS container
```

Later production might use:

```text
desired_count = 2
```

or more.

---

# 6. ECS has several important concepts

There are four terms you should understand:

```text
ECS
│
├── Cluster
├── Task Definition
├── Task
└── Service
```

Let's go one by one.

---

# 7. ECS Cluster

A cluster is basically a **logical grouping of ECS workloads**.

For us:

```text
ECS Cluster
└── ai-engineering-platform-dev
```

Think of it as:

> "This is the place where our application containers belong."

---

# 8. Task Definition

This is probably the most important ECS concept.

A task definition tells ECS:

> **How should my container run?**

It describes things such as:

```text
Container image
CPU
Memory
Port
Environment variables
IAM roles
Logging
```

For example:

```text
Task Definition
│
├── Image
│   └── ECR image
│
├── CPU
│   └── 256
│
├── Memory
│   └── 512 MB
│
├── Port
│   └── 3000
│
├── Execution Role
│
├── Task Role
│
└── Logging
```

So:

> **Task definition = recipe/instructions for running the container.**

---

# 9. Task

A task is an **actual running instance** of a task definition.

For example:

```text
Task Definition
       │
       │ start
       ▼
     Task
       │
       ▼
Running container
```

If we start two tasks:

```text
Task Definition
      │
      ├── Task 1
      │
      └── Task 2
```

Both use the same task definition.

---

# 10. Service

An ECS service keeps the desired number of tasks running.

For example:

```text
desired_count = 1
```

means:

> ECS, please keep one task running.

If the task crashes:

```text
Task
 │
 ▼
crashes
```

the service can start another task.

So:

```text
ECS Service
     │
     ├── desired = 1
     │
     └── keep one task running
```

This is very useful.

---

# 11. Putting everything together

The relationship is:

```text
ECS Cluster
     │
     ▼
ECS Service
     │
     ▼
Task
     │
     ▼
Container
     │
     ▼
NestJS
```

And:

```text
Task
  │
  └── uses
        │
        ▼
   Task Definition
```

---

# 12. Our desired architecture

Eventually:

```text
                    AWS
                     │
              ┌──────┴──────┐
              │             │
             ECR           ECS
              │             │
              │        Cluster
              │             │
              │          Service
              │             │
              │           Task
              │             │
              └──── image ──┤
                            │
                         Container
                            │
                            ▼
                      NestJS :3000
```

---

# 13. Important: What does NestJS need?

Our NestJS application needs to listen on a port.

Typically:

```typescript
await app.listen(3000);
```

So our container exposes:

```text
3000
```

We'll configure ECS accordingly.

Later:

```text
Internet
   │
   ▼
ALB :80
   │
   ▼
ECS container :3000
```

But **ALB comes later**.

---

# 14. Our Terraform compute module

We already created:

```text
infra/terraform/modules/compute/
```

Currently it contains ECR:

```text
compute/
├── main.tf
├── variables.tf
└── outputs.tf
```

We'll now expand it.

Eventually:

```text
compute/
├── main.tf
├── variables.tf
└── outputs.tf
```

will contain:

```text
ECR
ECS Cluster
Task Definition
ECS Service
```

For a larger project, we could split these into separate modules, but while learning this is easier to understand.

---

# 15. First: ECS Cluster

Open:

```text
infra/terraform/modules/compute/main.tf
```

We already have our ECR resource.

Add:

```hcl
resource "aws_ecs_cluster" "app" {
  name = "${local.name_prefix}-cluster"

  tags = {
    Name = "${local.name_prefix}-cluster"
  }
}
```

This creates:

```text
ECS Cluster
└── ai-engineering-platform-dev-cluster
```

---

# 16. Why do we need a cluster?

Because ECS needs a logical place to organize our services/tasks.

Think:

```text
AWS
 │
 └── ECS
      │
      └── Cluster
           │
           ├── Service A
           ├── Service B
           └── Service C
```

For our project:

```text
Cluster
└── NestJS application
```

---

# 17. ECS task definition

Now we get to the important part.

We need to tell ECS:

> What container should I run?

Add:

```hcl
resource "aws_ecs_task_definition" "app" {
  family                   = "${local.name_prefix}-app"
  requires_compatibilities = ["FARGATE"]

  network_mode = "awsvpc"

  cpu    = "256"
  memory = "512"

  execution_role_arn = var.ecs_task_execution_role_arn
  task_role_arn      = var.ecs_task_role_arn

  container_definitions = jsonencode([
    {
      name  = local.name_prefix
      image = "${aws_ecr_repository.app.repository_url}:${var.container_image_tag}"

      essential = true

      portMappings = [
        {
          containerPort = 3000
          hostPort      = 3000
          protocol      = "tcp"
        }
      ]
    }
  ])

  tags = {
    Name = "${local.name_prefix}-task-definition"
  }
}
```

This is a lot of code, so let's break it down.

---

# 18. What is `family`?

```hcl
family = "${local.name_prefix}-app"
```

This gives the task definition a family name.

For us:

```text
ai-engineering-platform-dev-app
```

Terraform/AWS can then have revisions:

```text
ai-engineering-platform-dev-app:1
ai-engineering-platform-dev-app:2
ai-engineering-platform-dev-app:3
```

This becomes very useful during deployments.

---

# 19. Why `FARGATE`?

```hcl
requires_compatibilities = ["FARGATE"]
```

This tells ECS:

> We want this task to run using Fargate.

---

# 20. What is `awsvpc`?

```hcl
network_mode = "awsvpc"
```

This is the network mode used for Fargate tasks.

It means the task gets its own network interface/IP inside our VPC.

Conceptually:

```text
VPC
 │
 └── Private Subnet
       │
       └── ECS Task
             │
             └── Network Interface
```

This will become very important when we connect ECS to our subnets and security groups.

---

# 21. CPU

```hcl
cpu = "256"
```

Fargate CPU units.

For our development environment:

```text
256 CPU units
```

is approximately:

```text
0.25 vCPU
```

So we're starting small.

---

# 22. Memory

```hcl
memory = "512"
```

means:

```text
512 MB memory
```

So our initial task is:

```text
0.25 vCPU
512 MB RAM
```

That's appropriate for a small development workload.

We can increase it later.

---

# 23. Execution role

We created this in our IAM module:

```text
ECS Task Execution Role
```

Now we pass it into the task definition:

```hcl
execution_role_arn = var.ecs_task_execution_role_arn
```

Remember:

```text
Execution Role
       │
       ├── Pull ECR image
       └── Send logs
```

---

# 24. Task role

We also created:

```text
ECS Task Role
```

We pass it here:

```hcl
task_role_arn = var.ecs_task_role_arn
```

Remember:

```text
Task Role
    ↓
permissions for our NestJS application
```

Currently it doesn't have additional permissions.

That's good.

---

# 25. Container image

This line is extremely important:

```hcl
image = "${aws_ecr_repository.app.repository_url}:${var.container_image_tag}"
```

Suppose our ECR URL is:

```text
123456789012.dkr.ecr.ap-south-1.amazonaws.com/ai-engineering-platform-dev
```

If `container_image_tag = "git-a81f23c"`, then the image becomes:

```text
123456789012.dkr.ecr.ap-south-1.amazonaws.com/ai-engineering-platform-dev:git-a81f23c
```

ECS will eventually try to pull that image.

---

# 26. But wait — our ECR is empty!

Correct.

At this moment:

```text
ECR
└── ai-engineering-platform-dev
       └── no images yet
```

So **ECS cannot successfully start the NestJS container yet**.

This is an important distinction.

Terraform can create the ECS infrastructure now, but the actual application won't run until an image exists.

Later we'll do:

```text
GitHub Actions
      │
      ▼
Build NestJS image
      │
      ▼
Push to ECR
      │
      ▼
ECS
      │
      ▼
Run image
```

---

# 27. Container name

```hcl
name = local.name_prefix
```

So:

```text
ai-engineering-platform-dev
```

becomes the container name.

---

# 28. Port 3000

We have:

```hcl
portMappings = [
  {
    containerPort = 3000
    hostPort      = 3000
    protocol      = "tcp"
  }
]
```

This tells ECS:

> The NestJS application listens on TCP port 3000.

Our application:

```text
NestJS
   │
   └── :3000
```

Later ALB will send traffic to:

```text
ALB
 │
 ▼
ECS :3000
```

---

# 29. `essential = true`

```hcl
essential = true
```

means:

> This container is essential to the task.

For our task, we only have one application container.

So:

```text
Task
 │
 └── NestJS container
       │
       └── essential
```

If it stops, the task isn't healthy anymore.

---

# 30. Add variables to the compute module

Now our compute module needs the IAM role ARNs.

Open:

```text
infra/terraform/modules/compute/variables.tf
```

Add:

```hcl
variable "ecs_task_execution_role_arn" {
  description = "IAM role used by ECS to pull images and write logs."
  type        = string
}

variable "ecs_task_role_arn" {
  description = "IAM role used by the application running inside ECS."
  type        = string
}
```

---

# 31. Connect IAM to compute

Now we have:

```text
IAM Module
   │
   ├── execution role ARN
   └── task role ARN
             │
             ▼
      Compute Module
             │
             ▼
       ECS Task Definition
```

Open:

```text
infra/terraform/envs/dev/main.tf
```

Change our compute module to:

```hcl
module "compute" {
  source = "../../modules/compute"

  project_name = var.project_name
  environment = var.environment

  ecs_task_execution_role_arn = module.iam.ecs_task_execution_role_arn
  ecs_task_role_arn            = module.iam.ecs_task_role_arn
}
```

This is one of the most important Terraform patterns you'll learn:

> One module can provide outputs that another module consumes.

---

# 32. Terraform dependency flow

Terraform now understands:

```text
IAM
 │
 │ role ARN
 ▼
Compute
 │
 ▼
ECS Task Definition
```

Terraform can therefore determine the correct creation order.

---

# 33. ECS Service

The task definition tells ECS **how** to run the container.

But we still need something to tell ECS:

> Keep this application running.

That's the ECS service.

Add:

```hcl
resource "aws_ecs_service" "app" {
  name            = "${local.name_prefix}-service"
  cluster         = aws_ecs_cluster.app.id
  task_definition = aws_ecs_task_definition.app.arn

  desired_count = 1

  launch_type = "FARGATE"

  network_configuration {
    subnets = var.private_subnet_ids

    security_groups = [
      var.ecs_security_group_id
    ]

    assign_public_ip = false
  }

  tags = {
    Name = "${local.name_prefix}-service"
  }
}
```

This is where our network starts connecting to ECS.

---

# 34. What is `desired_count`?

```hcl
desired_count = 1
```

means:

> Keep one task running.

So:

```text
Service
   │
   ▼
Task 1
```

Later production could be:

```hcl
desired_count = 2
```

which means:

```text
Service
   │
   ├── Task 1
   └── Task 2
```

---

# 35. Why private subnets?

We use:

```hcl
subnets = var.private_subnet_ids
```

because application containers generally shouldn't need to be directly exposed to the public internet.

Our eventual architecture will be:

```text
Internet
   │
   ▼
ALB
   │
   ▼
Private Subnet
   │
   ▼
ECS
   │
   ▼
NestJS
```

This is a much better architecture than:

```text
Internet
   │
   ▼
ECS directly
```

---

# 36. What is a Security Group?

We already discussed security groups in the networking part.

Think of one as a firewall.

Our ECS security group will eventually say something like:

```text
Allow:
ALB → ECS :3000
```

But:

```text
Internet → ECS :3000
```

should not be directly allowed.

We'll make sure this is correctly wired when we finish the networking/security group setup.

---

# 37. Why `assign_public_ip = false`?

```hcl
assign_public_ip = false
```

means:

> Don't give this ECS task a public IP address.

This supports our architecture:

```text
Internet
   │
   ▼
 ALB
   │
   ▼
Private ECS
```

rather than:

```text
Internet
   │
   ▼
Public ECS task
```

---

# 38. Add required variables

Open:

```text
infra/terraform/modules/compute/variables.tf
```

Add:

```hcl
variable "private_subnet_ids" {
  description = "Private subnet IDs where ECS tasks will run."
  type        = list(string)
}

variable "ecs_security_group_id" {
  description = "Security group ID assigned to ECS tasks."
  type        = string
}
```

---

# 39. Connect networking to ECS

Our `network` module should already expose the private subnet IDs and ECS security group.

Conceptually:

```text
Network Module
│
├── private subnet IDs
│
└── ECS security group
          │
          ▼
    Compute Module
          │
          ▼
      ECS Service
```

In `envs/dev/main.tf`, our compute module should therefore receive:

```hcl
module "compute" {
  source = "../../modules/compute"

  project_name = var.project_name
  environment  = var.environment

  ecs_task_execution_role_arn = module.iam.ecs_task_execution_role_arn
  ecs_task_role_arn            = module.iam.ecs_task_role_arn

  private_subnet_ids   = module.network.private_subnet_ids
  ecs_security_group_id = module.network.ecs_security_group_id
}
```

**Important:** use the exact output names from your existing network module. If your network module calls them something different, we should use those names rather than inventing new ones.

---

# 40. Outputs from compute

Open:

```text
infra/terraform/modules/compute/outputs.tf
```

Add:

```hcl
output "ecs_cluster_name" {
  description = "Name of the ECS cluster."
  value       = aws_ecs_cluster.app.name
}

output "ecs_service_name" {
  description = "Name of the ECS service."
  value       = aws_ecs_service.app.name
}

output "ecs_task_definition_arn" {
  description = "ARN of the ECS task definition."
  value       = aws_ecs_task_definition.app.arn
}
```

---

# 41. Dev outputs

Open:

```text
infra/terraform/envs/dev/outputs.tf
```

Add:

```hcl
output "ecs_cluster_name" {
  description = "ECS cluster name."
  value       = module.compute.ecs_cluster_name
}

output "ecs_service_name" {
  description = "ECS service name."
  value       = module.compute.ecs_service_name
}

output "ecs_task_definition_arn" {
  description = "ECS task definition ARN."
  value       = module.compute.ecs_task_definition_arn
}
```

---

# 42. One important problem we'll encounter

At this point Terraform can create:

```text
ECS Cluster
ECS Task Definition
ECS Service
```

But:

```text
ECR
└── no image
```

So ECS will attempt to start the task and won't be able to pull:

```text
the configured immutable tag
```

Therefore the service won't become healthy yet.

**That's okay.**

We have separated two things:

### Infrastructure

```text
Terraform
   ↓
ECR
ECS
IAM
Network
```

### Application deployment

```text
GitHub Actions
   ↓
Build image
   ↓
Push image to ECR
   ↓
Deploy ECS
```

The second part comes with our CI/CD work.

---

# 43. Why use immutable tags now?

Use a fixed image tag from day one:

```hcl
image = "${aws_ecr_repository.app.repository_url}:${var.container_image_tag}"
```

Examples of immutable versioned tags:

```text
git-a81f23c
```

or:

```text
2026.10.07-001
```

Then:

```text
ECS Task Definition
        │
        ▼
image: git-a81f23c
```

This gives us reproducible deployments and safer rollbacks.

With GitHub Actions, set `container_image_tag` to a build-specific value (for example the commit SHA) and deploy that exact version.

---

# 44. Terraform plan

Now run:

```powershell
cd infra\terraform\envs\dev
```

Then:

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

The plan should contain resources conceptually like:

```text
+ aws_ecs_cluster.app
+ aws_ecs_task_definition.app
+ aws_ecs_service.app
```

along with anything else still pending from the earlier steps.

---

# 45. Don't blindly run `apply`

This is especially important now.

We're creating a real ECS service.

Before applying, inspect:

```text
CPU
Memory
Subnets
Security group
IAM roles
ECR repository
Desired count
Public IP
```

You want:

```text
CPU              = 256
Memory           = 512
Desired count    = 1
Launch type      = FARGATE
Public IP        = false
```

And:

```text
ECS → private subnet
```

not a public subnet.

---

# 46. Our architecture after this step

Once this is configured, our infrastructure conceptually looks like:

```text
                         AWS
                          │
             ┌────────────┴────────────┐
             │                         │
           ECR                        VPC
             │                         │
        Docker image                  │
             │                 ┌───────┴───────┐
             │                 │               │
             │              Public          Private
             │              Subnets         Subnets
             │                                 │
             │                                 ▼
             │                              ECS
             │                               │
             │                            Cluster
             │                               │
             │                            Service
             │                               │
             └──────────────────────────────►Task
                                             │
                                             ▼
                                       NestJS :3000
```

And IAM:

```text
IAM
│
├── ECS Execution Role
│      ├── ECR pull
│      └── CloudWatch logs
│
└── ECS Task Role
       └── Application permissions
```

---

# 47. What you should remember from ECS

Don't try to memorize every Terraform resource.

Remember these four concepts:

### ECS Cluster

```text
Where our ECS workloads are organized.
```

### Task Definition

```text
Instructions for running our container.
```

### Task

```text
An actual running instance of the task definition.
```

### Service

```text
Keeps the desired number of tasks running.
```

And:

### Fargate

```text
AWS-managed compute that runs the ECS containers.
```

The complete mental model is:

```text
                 ECS
                  │
             ┌────┴────┐
             │ Cluster │
             └────┬────┘
                  │
               Service
                  │
                  ▼
                 Task
                  │
                  │ uses
                  ▼
           Task Definition
                  │
                  ▼
             Container
                  │
                  ▼
               NestJS
```

---

# One important correction before you apply

Because we're building this **from your actual repo**, I don't want you to blindly paste the ECS code if your existing `network` module has different output names or subnet/security-group structure.

The next practical step should be:

```text
1. Check existing network outputs
2. Check ECS-related variables
3. Wire compute → network → IAM
4. terraform plan
5. Fix any dependency/output mismatches
6. Only then apply
```

That will prevent the common Terraform beginner problem of getting errors such as:

```text
module.network.private_subnet_ids
does not exist
```

or:

```text
module.network.ecs_security_group_id
does not exist
```

**After ECS/Fargate, the next major piece is ALB**, which gives us:

```text
Internet
   ↓
Application Load Balancer
   ↓
ECS/Fargate
   ↓
NestJS :3000
```

That is when we'll finally be able to access the NestJS application from outside AWS.
