# Ciel Backend - Setup & Deployment Guide

## TL;DR

1. Create Scaleway project + API keys
2. Create S3 bucket for Terraform state
3. Generate secrets (PASETO keys, DB passwords, Redis password)
4. Add 9 GitHub Secrets
5. Push to main (or trigger workflow manually)

---

## Initial Setup (One-Time)

### Step 1: Scaleway Account & Project

1. Create a [Scaleway account](https://console.scaleway.com) and enable billing
2. Create a project (e.g., `ciel-production`)
3. Note your **Project ID** (visible in console URL or Project Settings)

### Step 2: API Credentials

1. Go to **IAM > API Keys > Generate New API Key**
2. Scope it to your project
3. Save the **Access Key** and **Secret Key** — these are your `SCW_ACCESS_KEY` and `SCW_SECRET_KEY`

### Step 3: Terraform State Bucket

Create before running `terraform init`:

```bash
# Via Scaleway CLI
scw object bucket create name=ciel-terraform-state region=fr-par

# Or via AWS CLI
aws s3 mb s3://ciel-terraform-state \
  --endpoint-url https://s3.fr-par.scw.cloud \
  --region fr-par
```

### Step 4: Generate Secrets

Run these commands and save the output securely:

```bash
echo "DB_ADMIN_PASSWORD:"
openssl rand -base64 24

echo "DB_USER_PASSWORD:"
openssl rand -base64 24

echo "REDIS_PASSWORD:"
openssl rand -base64 24

echo "PASETO_ACCESS_KEY:"
openssl rand -base64 32

echo "PASETO_REFRESH_KEY:"
openssl rand -base64 32

echo "ADMIN_TOKEN (optional):"
openssl rand -hex 32
```

### Step 5: GitHub Secrets

Go to **Repository > Settings > Secrets and variables > Actions > New repository secret** and add:

| Secret Name | Value |
|-------------|-------|
| `SCW_ACCESS_KEY` | From Step 2 |
| `SCW_SECRET_KEY` | From Step 2 |
| `SCW_PROJECT_ID` | From Step 1 |
| `DB_ADMIN_PASSWORD` | From Step 4 |
| `DB_USER_PASSWORD` | From Step 4 |
| `REDIS_PASSWORD` | From Step 4 |
| `PASETO_ACCESS_KEY` | From Step 4 |
| `PASETO_REFRESH_KEY` | From Step 4 |
| `ADMIN_TOKEN` | From Step 4 (optional) |

### Step 6: First Deploy

**Option A — GitHub Actions (recommended):**

1. Go to **Actions > "Scaleway Terraform CI/CD" > Run workflow**
2. Select environment (`prod` or add `dev` to the workflow matrix)
3. Wait ~15-20 minutes for first run
4. Check logs for errors

**Option B — Manual from local machine:**

```bash
cd terraform/environments/dev

# Set credentials for Terraform backend
export AWS_ACCESS_KEY_ID="your-scw-access-key"
export AWS_SECRET_ACCESS_KEY="your-scw-secret-key"

terraform init \
  -backend-config="access_key=$AWS_ACCESS_KEY_ID" \
  -backend-config="secret_key=$AWS_SECRET_ACCESS_KEY"

terraform validate

# Set all required variables
export TF_VAR_project_id="your-project-id"
export TF_VAR_db_admin_password="your-db-admin-pass"
export TF_VAR_db_user_password="your-db-user-pass"
export TF_VAR_redis_password="your-redis-pass"
export TF_VAR_paseto_access_key="your-paseto-access"
export TF_VAR_paseto_refresh_key="your-paseto-refresh"

terraform plan
terraform apply
```

Or create `terraform.tfvars` from the example:

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit with your values — NEVER commit this file
```

### Step 7: Run Database Migrations

If deploying manually (CI/CD does this automatically):

```bash
DATABASE_URL=$(terraform output -raw database_url)

for f in ../../../migrations/*.sql; do
  echo "Running: $f"
  psql "$DATABASE_URL" -f "$f"
done
```

### Step 8: Verify Deployment

```bash
# Get the combined instance public IP
API_IP=$(terraform output -raw api_instance_public_ips | jq -r '.[0]')

# Test health endpoint
curl http://$API_IP:8080/health

# Or SSH to bastion and check Docker containers
BASTION_IP=$(terraform output -raw bastion_ip)
ssh root@$BASTION_IP
docker ps
docker logs ciel-api-1
```

Check that you see:
- `ciel-api` container running (APP_MODE=api)
- `redis` container running
- Health endpoint returns 200

Check the serverless worker:
```bash
terraform output serverless_worker_endpoint
# Should show the container's domain name (or null if not yet deployed)
```

---

## DNS Setup (Optional)

If using the DNS module:

1. Register your domain with Scaleway DNS or update nameservers at your registrar to:
   - `ns0.dom.scw.cloud`
   - `ns1.dom.scw.cloud`
2. Wait for propagation (up to 48 hours)
3. Set in your tfvars:

```hcl
enable_dns  = true
domain_name = "ciel-social.eu"
```

4. Run `terraform apply`
5. Verify: `dig dev-api.ciel-social.eu`

---

## Ongoing Operations

### Deploying Updates

**Via CI/CD (recommended):**
Push to main or trigger the workflow manually. The pipeline builds a Docker image, runs Terraform, and applies migrations.

**Manually:**

```bash
cd terraform/environments/dev
terraform apply -var="container_image_tag=NEW_TAG"
```

### Checking Logs

```bash
# SSH to combined instance via bastion
ssh root@$(terraform output -raw bastion_ip)
docker logs -f ciel-api-1

# Serverless worker logs are in Scaleway Cockpit
```

### Application Rollback

```bash
# Deploy the previous image tag
terraform apply -var="container_image_tag=PREVIOUS_TAG"
```

### Database Rollback

Migrations are forward-only. Restore from Scaleway automatic backups or write reverse migration SQL.

---

## Scaling

See [SCALEWAY_TF_PLAN.md](./SCALEWAY_TF_PLAN.md) for the full scaling scenarios with exact variable changes. Quick reference:

| Scenario | Key Change | Cost Delta |
|----------|-----------|------------|
| **1. Bigger instance** | `combined_instance_type = "DEV1-L"` | +€19/mo |
| **2. Split API + Redis** | `enable_combined_mode = false`, `cache.enabled = true` | +€6/mo |
| **3. Load balancer + multi-API** | `enable_load_balancer = true`, `api_instance_count = 2` | +€12/mo + instances |
| **4. Managed Redis** | `use_managed_redis = true` | +€35/mo |
| **5. Upgrade DB** | `db_node_type = "DB-PRO2-XXS"` | +€63/mo |
| **6. More worker capacity** | `serverless_worker_max_scale = 10` | ~€0 |
| **7. CDN** | `enable_cdn = true` | ~€1-15/mo |
| **8. Production-ready** | All of the above | ~€200-250/mo |
| **9. Kubernetes** | Kapsule migration | Varies |

To apply any scenario, update the variables in your tfvars or CI/CD secrets and run `terraform apply`.

---

## CDN Setup (Manual)

After enabling `enable_cdn = true` in the storage module:

1. Go to **Scaleway Console > Edge Services**
2. Create a pipeline for your media bucket
3. Cache `processed/*` prefix with long TTL (1 year for processed images)
4. Optionally add a custom domain
5. Update `S3_PUBLIC_ENDPOINT` with the CDN URL

---

## Monitoring

After the observability module deploys:

1. Access Grafana via Scaleway Cockpit
2. Key metrics to watch:
   - API: request latency P95, error rate
   - Database: connection count, query latency
   - Worker: SQS queue depth, processing time
   - Instance: CPU, memory, disk usage

Set `enable_alerts = true` in the observability module for production.

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `terraform init` fails with S3 error | Verify state bucket exists and credentials are correct |
| Container won't start | Check cloud-init logs: `/var/log/cloud-init-output.log` on the instance |
| DB connection fails | Verify instance is on the private network, check security groups |
| Serverless worker not triggering | Check SQS trigger in Scaleway Console, verify queue name matches |
| DNS not resolving | Wait for propagation, verify nameservers at registrar |
| Rate limit errors in tests | The IP rate limit is 10 login attempts/hr — use direct token issuance for tests |

---

## Security Reminders

- Never commit `terraform.tfvars` to version control
- Rotate secrets every 90 days
- Use separate credentials per environment
- Enable MFA on your Scaleway account
- Instances fetch runtime secrets from Scaleway Secret Manager at boot (no plaintext secrets in cloud-init)
- Admin endpoints require `X-Admin-Token` header
