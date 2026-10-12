# Application Deployment Runbook (ECS + GitHub Actions)

This runbook explains how to deploy safely using `.github/workflows/app-cd.yml`.

## 1) Preconditions

Before deployment, ensure:

- `terraform apply` for target environment has completed successfully.
- GitHub Environment variables are configured for that environment:
  - `AWS_DEPLOY_ROLE_ARN`
  - `AWS_REGION`
  - `ECR_REPOSITORY`
  - `ECS_CLUSTER`
  - `ECS_SERVICE`
  - `CONTAINER_NAME` (optional)
- ECR repository and ECS service already exist.

---

## 2) What to use for `image_tag`

### Default (recommended)

Use Git commit SHA format:

```
sha-<short_commit_sha>
```

Example:

```
sha-a1b2c3d
```

Generate it in `cmd.exe`:

```bat
for /f %i in ('git rev-parse --short HEAD') do @echo sha-%i
```

Avoid mutable tags like `latest`.

### Other acceptable immutable formats

- Release version, e.g. `v1.4.0`
- Build timestamp + SHA, e.g. `2026-10-12-a1b2c3d`

---

## 3) Deploy from GitHub Actions

1. Open **GitHub → Actions → Application CD**.
2. Click **Run workflow**.
3. Select:
   - `environment`: `dev` / `stage` / `prod`
   - `image_tag`: immutable tag from step 2
4. Start workflow.

What the workflow does:

1. Assumes AWS role via OIDC.
2. Builds Docker image from repository `Dockerfile`.
3. Pushes image to ECR with chosen tag.
4. Registers new ECS task definition revision.
5. Updates ECS service to new revision.
6. Waits for service stabilization.
7. Rolls back automatically if stabilization fails.

---

## 4) Post-deploy verification checklist

After workflow success, verify:

- ECS service is stable (desired tasks == running tasks).
- New task definition revision is active on service.
- Application endpoint responds from ALB URL.
- Health endpoint returns expected success response.
- No critical errors in task logs.

---

## 5) Rollback options

### Automatic rollback (already built in)

If ECS fails to stabilize, workflow restores previous task definition and marks run as failed.

### Manual rollback

If needed, re-run **Application CD** using last known good `image_tag`.

---

## 6) Promotion flow (recommended)

Promote the same tested image tag across environments:

1. Deploy to `dev`.
2. Verify smoke checks.
3. Deploy same tag to `stage`.
4. Verify.
5. Deploy same tag to `prod`.

This keeps behavior consistent and reduces release risk.
