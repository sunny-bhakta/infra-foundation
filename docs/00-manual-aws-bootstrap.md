# Manual AWS bootstrap
**no IAM user**, using **GitHub OIDC + an IAM role for Terraform**.

> GitHub owner/repo is set for this project: `sunny-bhakta/infra-foundation`.

### Step 1 — Create the GitHub OIDC provider

In the AWS Console:

1. Open **IAM**.
2. In the left sidebar, select **Identity providers**.
3. Click **Add provider**.
4. For **Provider type**, choose **OpenID Connect**.
5. Enter:

**Provider URL**

```
   https://token.actions.githubusercontent.com
```

6. For **Audience**, enter:

```
   sts.amazonaws.com
```

7. Click **Add provider**.

Once that's created, **don't create an IAM user**.

## Step 2 — Create the Terraform IAM role

In **AWS Console → IAM → Roles → Create role**:

1. Select **Custom trust policy**.
2. Paste this exact policy:

```
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
  "Federated": "arn:aws:iam::831975835566:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:sunny-bhakta/infra-foundation:*"
        }
      }
    }
  ]
}
```

3. Click **Next**.

### Step 3 — Permissions

Attaching permissions to the Terraform role

1. On **Add permissions**, search for:

`AdministratorAccess`

2. Select **AdministratorAccess**.
3. Click **Next**.
4. For **Role name**, use:

```
   github-terraform-role
```

5. Click **Create role**.

This creates **one IAM role**, not an IAM user, and GitHub Actions will authenticate through the OIDC provider.

After the role is created, **don't create any additional IAM users, access keys, or roles**. The next step will be configuring the GitHub repository to assume this role.


## 4.1\. Open your GitHub repository

Go to:

[sunny-bhakta/infra-foundation](https://github.com/sunny-bhakta/infra-foundation)

Then:

**Settings → Secrets and variables → Actions**

You don't need to create AWS access keys.

## 4.2\. Add GitHub Actions variables (recommended)

Go to **Environments → dev (and later stage/prod) → Variables**.

Add:

**Name**

```
AWS_TERRAFORM_ROLE_ARN
```

**Value**

```
arn:aws:iam::831975835566:role/github-terraform-role
```

Also add:

**Name**

```
AWS_REGION
```

**Value**

```
ap-south-1
```

> If you are using app deployment workflows, you can similarly define `AWS_DEPLOY_ROLE_ARN` in the same environment.

You can still use repository-level variables if needed, but environment variables are better for `dev/stage/prod` separation.

### 4.2.1 Ready-to-use values for your current `dev` setup

Based on your current Terraform values (`project_name = ai-engineering-platform`, `environment = dev`, `aws_region = ap-south-1`), set these in **GitHub Environment → dev → Variables**:

```text
AWS_REGION=ap-south-1
AWS_TERRAFORM_ROLE_ARN=arn:aws:iam::831975835566:role/github-terraform-role
AWS_DEPLOY_ROLE_ARN=arn:aws:iam::831975835566:role/github-deploy-role
ECR_REPOSITORY=ai-engineering-platform-dev
ECS_CLUSTER=ai-engineering-platform-dev-cluster
ECS_SERVICE=ai-engineering-platform-dev-service
CONTAINER_NAME=ai-engineering-platform-dev
```

Notes:

- The variable key is `CONTAINER_NAME` (not `CONTAINER_NAM`).
- If you want to reuse a single role for now, `AWS_DEPLOY_ROLE_ARN` can temporarily point to the same ARN as `AWS_TERRAFORM_ROLE_ARN`.

## 4.3\. Configure GitHub Actions

Your workflow needs GitHub's OIDC permission and must assume the role.

In your repository, open:

```
.github/workflows/
```

For this project, Terraform OIDC is used by:

- `terraform-validate.yml`
- `terraform-plan.yml`
- `terraform-apply.yml`
- `terraform-destroy.yml`
- `terraform-drift.yml`

Find the Terraform workflow. In the workflow YAML, make sure it contains:

```
permissions:
  id-token: write
  contents: read
```

Then the AWS authentication step should look like:

```
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ vars.AWS_TERRAFORM_ROLE_ARN }}
    aws-region: ${{ vars.AWS_REGION }}
```

### Important

Do **not** add:

```
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
```

We're deliberately using **GitHub OIDC → AWS IAM Role**, so there are no long-lived AWS credentials stored in GitHub.

**AWS/GitHub OIDC bootstrap is complete** if these things are done:

- ✅ GitHub OIDC provider created in AWS
- ✅ IAM role `github-terraform-role` created
- ✅ Trust policy restricted to your repo (`repo:sunny-bhakta/infra-foundation:*`)
- ✅ `AWS_TERRAFORM_ROLE_ARN` and `AWS_REGION` added in GitHub Environment variables
- ✅ Workflow uses `role-to-assume: ${{ vars.AWS_TERRAFORM_ROLE_ARN }}`
- ✅ Workflow has `id-token: write`

