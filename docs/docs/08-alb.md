Absolutely. We’ll continue in the same **beginner-friendly, step-by-step** style.

# Step 7 — Application Load Balancer (ALB)

## Goal

Right now we have roughly:

```text
ECR
 │
 ▼
ECS / Fargate
 │
 ▼
NestJS :3000
```

But there is a problem:

> How does someone on the internet reach our NestJS application?

We don't want users connecting directly to an ECS task.

Instead, we'll introduce an **Application Load Balancer**.

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
NestJS :3000
```

This is the architecture we'll build.

---

# 1. What is an ALB?

ALB means:

> **Application Load Balancer**

It is an AWS service that receives HTTP/HTTPS requests and forwards them to our application.

For example, a user visits:

```text
http://my-api.example.com
```

The request goes:

```text
User
 │
 ▼
ALB
 │
 ▼
ECS Task
 │
 ▼
NestJS
```

The ALB becomes the **public entry point** for our application.

---

# 2. Why don't we expose ECS directly?

Our ECS task is running inside a private subnet.

```text
Internet
    X
    │
    │ no direct access
    ▼
Private ECS
```

That's intentional.

We want:

```text
Internet
   │
   ▼
Public ALB
   │
   ▼
Private ECS
```

This gives us a cleaner security boundary.

---

# 3. What does the ALB actually do?

Suppose our NestJS application has:

```text
GET /health
```

A user requests:

```text
http://ALB-DNS/health
```

The flow becomes:

```text
Browser
   │
   │ GET /health
   ▼
ALB :80
   │
   ▼
Target Group
   │
   ▼
ECS Task :3000
   │
   ▼
NestJS /health
```

---

# 4. Three important ALB concepts

You need to understand three things:

```text
ALB
 │
 ├── Listener
 │
 └── Target Group
```

Let's understand them.

---

# 5. Load Balancer

The load balancer is the actual AWS resource.

It has a DNS name similar to:

```text
my-api-dev-alb-123456789.ap-south-1.elb.amazonaws.com
```

Users can send requests to it.

---

# 6. Listener

A listener waits for incoming requests.

For example:

```text
ALB
 │
 └── Listener
       │
       └── HTTP :80
```

Meaning:

> Listen for HTTP traffic on port 80.

Later we can add HTTPS:

```text
ALB
 │
 ├── HTTP :80
 │
 └── HTTPS :443
```

For our initial setup, we'll use HTTP.

---

# 7. Target Group

The target group tells the ALB:

> Where should I send incoming traffic?

Our target is the ECS service.

Conceptually:

```text
ALB
 │
 ▼
Target Group
 │
 ▼
ECS Task :3000
```

---

# 8. Health checks

This is one of the most useful ALB features.

The ALB can periodically ask:

```text
GET /health
```

If the application responds successfully:

```text
200 OK
```

the ALB considers the task healthy.

If it doesn't:

```text
500
timeout
connection refused
```

the ALB considers it unhealthy.

So:

```text
ALB
 │
 ├── Health check
 │       │
 │       ▼
 │    /health
 │       │
 │       ▼
 │    NestJS
 │
 └── Healthy?
       │
       ├── Yes → send traffic
       └── No  → don't send traffic
```

---

# 9. Our network architecture

We're going to use:

```text
                 Internet
                    │
                    ▼
             ┌─────────────┐
             │     ALB     │
             │  Public     │
             │  Subnets    │
             └──────┬──────┘
                    │
                    ▼
             ┌─────────────┐
             │ ECS Service │
             │  Private    │
             │  Subnets    │
             └──────┬──────┘
                    │
                    ▼
               NestJS :3000
```

This is a very common AWS architecture.

---

# 10. Where will ALB live in Terraform?

We previously planned:

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

We can keep ALB inside the `network` module for now because it is tightly connected to:

* VPC
* subnets
* security groups
* target groups
* listeners

However, from an ownership perspective, a separate `load-balancer` module can eventually be cleaner.

For our learning architecture, let's use:

```text
modules/network/
```

for ALB-related networking.

---

# 11. ALB Security Group

Remember security groups?

Think:

> Security group = firewall.

We need two important security groups:

```text
Internet
   │
   ▼
ALB Security Group
   │
   ▼
ECS Security Group
```

### ALB security group

Allow:

```text
Internet → ALB :80
```

### ECS security group

Allow:

```text
ALB → ECS :3000
```

Not:

```text
Internet → ECS :3000
```

That's an important security principle.

---

# 12. ALB security group

Inside our network module, we'll create:

```hcl
resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-alb-sg"
  description = "Security group for the application load balancer."
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from the internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name_prefix}-alb-sg"
  }
}
```

The important part is:

```hcl
from_port   = 80
to_port     = 80
```

We're allowing HTTP.

---

# 13. ECS security group

The ECS security group should **not** allow the entire internet.

Instead:

```hcl
resource "aws_security_group" "ecs" {
  name        = "${local.name_prefix}-ecs-sg"
  description = "Security group for ECS tasks."
  vpc_id      = var.vpc_id

  ingress {
    description     = "HTTP from ALB"
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name_prefix}-ecs-sg"
  }
}
```

Notice this:

```hcl
security_groups = [aws_security_group.alb.id]
```

This means:

> Only resources belonging to the ALB security group can connect to ECS port 3000.

That's much safer.

---

# 14. ALB itself

Now create the load balancer.

```hcl
resource "aws_lb" "app" {
  name               = "${local.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"

  security_groups = [
    aws_security_group.alb.id
  ]

  subnets = var.public_subnet_ids

  tags = {
    Name = "${local.name_prefix}-alb"
  }
}
```

Let's understand:

### `internal = false`

Means:

> This is an internet-facing load balancer.

### `load_balancer_type = "application"`

Means:

> Use Application Load Balancer.

### `subnets`

We're putting the ALB in **public subnets**.

---

# 15. Why public subnets for ALB?

Because the ALB needs to receive traffic from the internet.

```text
Internet
   │
   ▼
Public Subnet
   │
   ▼
ALB
```

Our ECS application stays private:

```text
ALB
 │
 ▼
Private Subnet
 │
 ▼
ECS
```

So:

```text
Public
└── ALB

Private
└── ECS
```

---

# 16. Target Group

Now we tell ALB where to send traffic.

```hcl
resource "aws_lb_target_group" "app" {
  name        = "${local.name_prefix}-tg"
  port        = 3000
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  health_check {
    enabled             = true
    path                = "/health"
    protocol            = "HTTP"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  tags = {
    Name = "${local.name_prefix}-tg"
  }
}
```

---

# 17. Why `target_type = "ip"`?

This is important for Fargate.

Our ECS tasks get their own network interfaces/IP addresses.

Therefore:

```text
ECS Task
   │
   └── private IP
```

The target group sends traffic to that IP.

That's why:

```hcl
target_type = "ip"
```

is appropriate.

---

# 18. Health check

We're saying:

```text
GET /health
```

Every 30 seconds.

The ALB expects:

```text
HTTP 200
```

So our NestJS application must have:

```text
GET /health
```

returning:

```text
200 OK
```

You already have a health endpoint in the broader project setup, so this fits our architecture.

---

# 19. Listener

Now connect the ALB to the target group.

```hcl
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"

    forward {
      target_group {
        arn = aws_lb_target_group.app.arn
      }
    }
  }
}
```

The flow is now:

```text
HTTP :80
   │
   ▼
ALB
   │
   ▼
Target Group
   │
   ▼
ECS :3000
```

---

# 20. Connect ECS to the target group

Now we need to tell the ECS service:

> Register my tasks with this target group.

In the ECS service:

```hcl
load_balancer {
  target_group_arn = var.target_group_arn
  container_name   = local.name_prefix
  container_port   = 3000
}
```

So the ECS service knows:

```text
Container:
ai-engineering-platform-dev

Port:
3000

Target Group:
dev target group
```

---

# 21. Add the variable

In:

```text
infra/terraform/modules/compute/variables.tf
```

add:

```hcl
variable "target_group_arn" {
  description = "ARN of the ALB target group."
  type        = string
}
```

Then add the `load_balancer` block to:

```text
infra/terraform/modules/compute/main.tf
```

inside `aws_ecs_service.app`:

```hcl
load_balancer {
  target_group_arn = var.target_group_arn
  container_name   = local.name_prefix
  container_port   = 3000
}
```

---

# 22. Connect network → compute

Our network module should expose:

```hcl
output "target_group_arn" {
  description = "ARN of the application target group."
  value       = aws_lb_target_group.app.arn
}
```

Then in:

```text
infra/terraform/envs/dev/main.tf
```

our compute module receives:

```hcl
target_group_arn = module.network.target_group_arn
```

So now Terraform understands:

```text
Network Module
      │
      │ target group ARN
      ▼
Compute Module
      │
      ▼
ECS Service
```

---

# 23. Final architecture

At this point, our architecture becomes:

```text
                         Internet
                            │
                            │ HTTP :80
                            ▼
                 ┌─────────────────────┐
                 │   Application       │
                 │   Load Balancer     │
                 │                     │
                 │   Public Subnets    │
                 └──────────┬──────────┘
                            │
                            │ :3000
                            ▼
                 ┌─────────────────────┐
                 │    Target Group     │
                 └──────────┬──────────┘
                            │
                            ▼
                 ┌─────────────────────┐
                 │    ECS Service      │
                 │                     │
                 │  Private Subnets   │
                 └──────────┬──────────┘
                            │
                            ▼
                     ┌────────────┐
                     │ ECS Task   │
                     │            │
                     │ NestJS     │
                     │ :3000      │
                     └────────────┘
```

---

# 24. Security flow

Our security groups create this:

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
   ▼
NestJS
```

But:

```text
Internet
   │
   X
   │
   ▼
ECS :3000
```

is blocked.

This is exactly what we want.

---

# 25. What happens when a task dies?

This is where ECS + ALB becomes powerful.

Suppose:

```text
ALB
 │
 ▼
Task 1
```

Task 1 crashes.

The ECS service notices:

```text
desired_count = 1
running_count = 0
```

and starts another task:

```text
Task 2
```

The ALB performs health checks:

```text
GET /health
```

Once Task 2 becomes healthy:

```text
ALB
 │
 ▼
Task 2
```

Traffic resumes.

---

# 26. What happens if we have two tasks?

Later:

```text
ECS Service
   │
   ├── Task 1
   │
   └── Task 2
```

ALB can distribute requests:

```text
             ALB
            /   \
           /     \
       Task 1   Task 2
```

That's the "load balancing" part.

---

# 27. What we should NOT do yet

Don't add these yet:

```text
HTTPS / ACM
Auto Scaling
WAF
CloudFront
Route 53
```

Those are useful, but they add complexity.

Our learning sequence should be:

```text
ALB
 ↓
HTTP
 ↓
Health check
 ↓
ECS
 ↓
NestJS
```

Get that working first.

Then harden it.

---

# 28. Terraform plan

After wiring everything:

```powershell
cd infra\terraform\envs\dev
```

Run:

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

You should expect resources similar to:

```text
+ aws_lb.app
+ aws_lb_target_group.app
+ aws_lb_listener.http
+ aws_security_group.alb
+ aws_security_group.ecs
```

plus any ECS changes.

---

# 29. One important issue before `apply`

Remember our earlier problem:

```text
ECR
└── no image yet
```

Therefore:

```text
ALB
 ↓
ECS
 ↓
Task
 ↓
ECR image
```

will not become healthy until the NestJS image exists.

So don't be surprised if the ECS service cannot successfully start the application yet.

That's actually the reason our next CI/CD step will be important.

---

# 30. Our roadmap now

We're progressing like this:

|  Step | Component            | Purpose                          |
| ----: | -------------------- | -------------------------------- |
|     1 | Terraform foundation | Terraform project                |
|     2 | AWS Provider         | Connect Terraform → AWS          |
|     3 | Network              | VPC/subnets/security groups      |
|     4 | ECR                  | Store container images           |
|     5 | IAM                  | Permissions                      |
|     6 | ECS/Fargate          | Run NestJS container             |
| **7** | **ALB**              | **Expose NestJS safely**         |
|     8 | RDS                  | PostgreSQL database              |
|     9 | Secrets Manager      | Store database secrets           |
|    10 | CloudWatch           | Logs/monitoring                  |
|    11 | GitHub Actions       | Build + push + deploy            |
|    12 | Hardening            | HTTPS, scaling, alarms, security |

### The big picture

We're building:

```text
                    GitHub
                       │
                       │ later
                       ▼
                GitHub Actions
                       │
                       ▼
                      ECR
                       │
                       │ Docker image
                       ▼
Internet ───────► ALB
                   │
                   │
                   ▼
                ECS/Fargate
                   │
                   ▼
                NestJS
                   │
                   ▼
                  RDS
```

And IAM controls who is allowed to do what.

**The next topic after ALB should be RDS/PostgreSQL**, where we'll connect our NestJS application to a real AWS database while keeping the database private.
