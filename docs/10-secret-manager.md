#  Add Secrets Manager in this same step (recommended)

If you want to finish RDS + credential storage together, add Secrets Manager now.

## 1 Why add it here?

Because Terraform state can still contain generated password values.

Using Secrets Manager gives your application a secure runtime source for DB credentials:

```text
RDS credentials
     │
     ▼
Secrets Manager
     │
     ▼
ECS task (NestJS)
```

## 2 Add secret resources in `modules/data/main.tf`

```hcl
resource "aws_secretsmanager_secret" "db" {
  name        = "${var.project_name}/${var.environment}/database"
  description = "Database credentials for ${var.project_name}-${var.environment}"

  tags = {
    Name = "${var.project_name}-${var.environment}-db-secret"
  }
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id

  secret_string = jsonencode({
    host     = aws_db_instance.postgres.address
    port     = aws_db_instance.postgres.port
    dbname   = aws_db_instance.postgres.db_name
    username = var.db_username
    password = random_password.db.result
  })
}
```

This stores a JSON payload your app can parse directly.

## 3 Output only the secret ARN (not secret value)

In `infra/terraform/modules/data/outputs.tf`:

```hcl
output "db_secret_arn" {
  description = "Secrets Manager ARN containing DB connection values."
  value       = aws_secretsmanager_secret.db.arn
}
```

## 4 Pass secret ARN to environment outputs

In `infra/terraform/envs/dev/outputs.tf`:

```hcl
output "db_secret_arn" {
  description = "Secrets Manager ARN for database credentials."
  value       = module.data.db_secret_arn
}
```

## 5 ECS task role permission (least privilege)

Your ECS task role should get only read access to this one secret.

Conceptually:

```text
Allow:
  secretsmanager:GetSecretValue
Resource:
  db_secret_arn only
```

This keeps the blast radius small.

## 6 Runtime behavior

At runtime, NestJS resolves credentials from Secrets Manager and connects to RDS:

```text
ECS task start
   │
   ▼
Read DB secret (host/port/db/user/password)
   │
   ▼
Connect to RDS :5432
```

This is the production-safe pattern and avoids hardcoding credentials anywhere.
