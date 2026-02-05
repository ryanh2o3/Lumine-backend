# Ciel Backend - Deployment Manual Steps

This document outlines all manual steps required before and during deployment of the Ciel backend infrastructure to Scaleway.

---

## TL;DR - Minimal Setup for CI/CD

If you're using GitHub Actions (recommended), you only need to:

1. **Scaleway Console:** Create project, get API keys
2. **Scaleway Console:** Create state bucket `ciel-terraform-state`
3. **GitHub Secrets:** Add 9 secrets (see "GitHub Actions Setup" section)
4. **Push to main** or trigger workflow manually

That's it! The CI/CD pipeline handles everything else.

---

## Pre-Deployment Checklist

Complete these steps **before** running `terraform init` for the first time.

### 1. Scaleway Account Setup

**When:** Before any Terraform operations
**Where:** [Scaleway Console](https://console.scaleway.com)

- [ ] Create a Scaleway account if you don't have one
- [ ] Enable billing and add payment method
- [ ] Note your Organization ID (visible in console URL or settings)

### 2. Create Scaleway Project

**When:** Before Terraform operations
**Where:** Scaleway Console > Project Settings

```bash
# Or via CLI if you have scw installed:
scw account project create name=ciel-production
```

- [ ] Create project named `ciel-production` (or your preferred name)
- [ ] Note the **Project ID** - you'll need this for `terraform.tfvars`

### 3. Generate API Credentials

**When:** Before Terraform operations
**Where:** Scaleway Console > IAM > API Keys

- [ ] Go to IAM > API Keys > Generate New API Key
- [ ] Select your project scope
- [ ] Save the **Access Key** and **Secret Key** securely
- [ ] These are your `SCW_ACCESS_KEY` and `SCW_SECRET_KEY`

> Note: The infrastructure now provisions a **scoped runtime IAM key** for instances and pulls secrets from Scaleway Secret Manager at boot. You no longer pass runtime secrets (DB/Redis/S3/SQS/PASETO/admin token) via cloud-init or `terraform.tfvars`.

### 4. Create Terraform State Bucket

**When:** Before `terraform init`
**Where:** Scaleway Console > Object Storage OR via CLI

```bash
# Via Scaleway CLI
scw object bucket create name=ciel-terraform-state region=fr-par

# Or via AWS CLI with Scaleway endpoint
aws s3 mb s3://ciel-terraform-state \
  --endpoint-url https://s3.fr-par.scw.cloud \
  --region fr-par
```

- [ ] Create bucket named `ciel-terraform-state` in `fr-par` region
- [ ] Ensure the bucket is private (default)

### 4.5 Runtime Secrets (NEW)

Instances now **fetch runtime secrets from Scaleway Secret Manager at boot** using a scoped IAM key created by Terraform. You do not need to pass secrets into cloud-init or `terraform.tfvars` beyond the Terraform inputs below. Ensure instances have outbound access (public gateway) so the `scw` CLI can reach Secret Manager.

### 5. Create Container Registry Namespace

**When:** Before first Docker push
**Where:** Scaleway Console > Container Registry

```bash
# Via CLI
scw registry namespace create name=ciel-social region=fr-par
```

- [ ] Create namespace named `ciel-social` in `fr-par` region
- [ ] Note: Terraform will also create a namespace, but having one ready helps

### 6. Register Your Domain (If using DNS module)

**When:** Before enabling DNS in Terraform
**Where:** Scaleway Console > Domains

- [ ] If your domain is registered elsewhere, add it to Scaleway DNS
- [ ] Update nameservers at your registrar to point to Scaleway:
  - `ns0.dom.scw.cloud`
  - `ns1.dom.scw.cloud`
- [ ] Wait for DNS propagation (can take up to 48 hours)

---

## Generate Required Secrets

**When:** Before creating `terraform.tfvars`
**Where:** Your local terminal

### PASETO Keys (Authentication)

```bash
# Generate PASETO access key (32 bytes, base64 encoded)
openssl rand -base64 32
# Example output: K7gNU3sdo+OL0wNhqoVWhr3g6s1xYv72ol/pe/Unols=

# Generate PASETO refresh key (32 bytes, base64 encoded)
openssl rand -base64 32
# Example output: dGhpcyBpcyBhIHRlc3Qga2V5IGZvciB0ZXN0aW5nIQ==
```

- [ ] Generate and save PASETO access key
- [ ] Generate and save PASETO refresh key

### Database Passwords

```bash
# Generate secure database admin password
openssl rand -base64 24
# Example: Yx3Kp8mNqR2wT5vZ7aB9cD1eF4gH

# Generate secure database user password
openssl rand -base64 24
```

- [ ] Generate and save database admin password (min 16 characters)
- [ ] Generate and save database user password (min 16 characters)

### Redis Password

```bash
# Generate Redis password
openssl rand -base64 24
```

- [ ] Generate and save Redis password

### Admin Token (Optional)

```bash
# Generate admin token for initial setup
openssl rand -hex 32
```

- [ ] Generate and save admin token (optional)

---

## Create terraform.tfvars Files (OPTIONAL - Only for Local Development)

> **Note:** If you're using GitHub Actions for deployment, you can skip this section entirely. All variables are passed via GitHub Secrets automatically.

**When:** Only if you need to run Terraform manually from your local machine
**Where:** Each environment directory

### For Production (`terraform/environments/prod/terraform.tfvars`)

```bash
cd terraform/environments/prod
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

```hcl
# terraform.tfvars
project_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

db_admin_password = "your-secure-admin-password"
db_user_password  = "your-secure-user-password"
redis_password    = "your-secure-redis-password"

paseto_access_key  = "your-base64-encoded-32-byte-key"
paseto_refresh_key = "your-base64-encoded-32-byte-key"

# Optional
# admin_token = "your-admin-token"

container_image_tag = "stable"
alert_contact_emails = ["ops@example.com"]
ssh_allowed_cidrs = []
domain_name = "ciel-social.eu"
enable_dns  = true
```

- [ ] Create `terraform.tfvars` for prod (optional)
- [ ] Create `terraform.tfvars` for staging (optional)
- [ ] Create `terraform.tfvars` for dev (optional)
- [ ] **IMPORTANT:** `terraform.tfvars` is in `.gitignore` - never commit it

---

## GitHub Actions Setup (REQUIRED - Primary Deployment Method)

**When:** Before first CI/CD run
**Where:** GitHub Repository Settings > Secrets and variables > Actions

This is the **recommended way to deploy**. All Terraform variables are passed automatically from GitHub Secrets - no local `terraform.tfvars` files needed.

### Required Secrets

Go to: **Repository → Settings → Secrets and variables → Actions → New repository secret**

| Secret Name | Description | How to Generate |
|-------------|-------------|-----------------|
| `SCW_ACCESS_KEY` | Scaleway API access key | From Scaleway Console > IAM > API Keys |
| `SCW_SECRET_KEY` | Scaleway API secret key | From Scaleway Console > IAM > API Keys |
| `SCW_PROJECT_ID` | Scaleway project ID | From Scaleway Console > Project Settings |
| `DB_ADMIN_PASSWORD` | Database admin password | `openssl rand -base64 24` |
| `DB_USER_PASSWORD` | Database user password | `openssl rand -base64 24` |
| `REDIS_PASSWORD` | Redis password | `openssl rand -base64 24` |
| `PASETO_ACCESS_KEY` | PASETO access key (32 bytes) | `openssl rand -base64 32` |
| `PASETO_REFRESH_KEY` | PASETO refresh key (32 bytes) | `openssl rand -base64 32` |
| `ADMIN_TOKEN` | Admin token (optional) | `openssl rand -hex 32` |

### Quick Setup Commands

Run these locally to generate all secrets, then copy-paste into GitHub:

```bash
echo "=== Copy these values to GitHub Secrets ==="
echo ""
echo "DB_ADMIN_PASSWORD:"
openssl rand -base64 24
echo ""
echo "DB_USER_PASSWORD:"
openssl rand -base64 24
echo ""
echo "REDIS_PASSWORD:"
openssl rand -base64 24
echo ""
echo "PASETO_ACCESS_KEY:"
openssl rand -base64 32
echo ""
echo "PASETO_REFRESH_KEY:"
openssl rand -base64 32
echo ""
echo "ADMIN_TOKEN:"
openssl rand -hex 32
```

### Optional Variables

Go to: **Repository → Settings → Secrets and variables → Actions → Variables tab → New repository variable**

| Variable Name | Description | Example |
|---------------|-------------|---------|
| `SLACK_WEBHOOK_URL` | Slack webhook for notifications | `https://hooks.slack.com/...` |

### Checklist

- [ ] Add `SCW_ACCESS_KEY` secret
- [ ] Add `SCW_SECRET_KEY` secret
- [ ] Add `SCW_PROJECT_ID` secret
- [ ] Add `DB_ADMIN_PASSWORD` secret
- [ ] Add `DB_USER_PASSWORD` secret
- [ ] Add `REDIS_PASSWORD` secret
- [ ] Add `PASETO_ACCESS_KEY` secret
- [ ] Add `PASETO_REFRESH_KEY` secret
- [ ] Add `ADMIN_TOKEN` secret (optional)
- [ ] Add `SLACK_WEBHOOK_URL` variable (optional)

---

## First Deployment

### Option A: Deploy via GitHub Actions (Recommended)

**When:** After setting up GitHub Secrets
**Where:** GitHub

1. **Push to main branch** or go to Actions → "Scaleway Terraform CI/CD" → "Run workflow"
2. Select environment (start with `dev`)
3. The workflow will:
   - Build and push Docker image
   - Run Terraform plan and apply
   - Execute database migrations
   - Send notifications (if configured)

- [ ] Trigger workflow for dev environment
- [ ] Wait for completion (~15-20 minutes first time)
- [ ] Check workflow logs for any errors
- [ ] Verify deployment (see "Verify Deployment" below)

### Option B: Deploy Manually (Alternative)

**When:** If you prefer local control or need to debug
**Where:** Your local machine

```bash
# Navigate to dev environment first
cd terraform/environments/dev

# Initialize Terraform with backend config
terraform init \
  -backend-config="access_key=YOUR_SCW_ACCESS_KEY" \
  -backend-config="secret_key=YOUR_SCW_SECRET_KEY"

# Validate configuration
terraform validate

# Plan the deployment (pass variables via command line or TF_VAR_*)
export TF_VAR_project_id="your-project-id"
export TF_VAR_db_admin_password="your-db-admin-pass"
export TF_VAR_db_user_password="your-db-user-pass"
export TF_VAR_redis_password="your-redis-pass"
export TF_VAR_paseto_access_key="your-paseto-access"
export TF_VAR_paseto_refresh_key="your-paseto-refresh"
export TF_VAR_alert_contact_emails='["ops@example.com"]'

terraform plan
terraform apply
```

### Run Database Migrations (if deploying manually)

**When:** After Terraform apply, if not using CI/CD
**Where:** Local machine with psql access

```bash
# Get database URL from Terraform output
DATABASE_URL=$(terraform output -raw database_url)

# Run migrations
for f in ../../../migrations/*.sql; do
  echo "Running: $f"
  psql "$DATABASE_URL" -f "$f"
done
```

### Verify Deployment

```bash
# For dev (bastion IP since no load balancer)
BASTION_IP=$(terraform output -raw bastion_ip)
ssh root@$BASTION_IP
docker ps
docker logs ciel-api-1

# For staging/prod (via load balancer)
LB_IP=$(terraform output -raw load_balancer_ip)
curl -v http://$LB_IP/health

# Or if DNS is enabled
curl -v https://api.ciel-social.eu/health
```

- [ ] Verify containers are running
- [ ] Check application logs
- [ ] Test health endpoint

### Deploy All Environments

For staging and production, either:
- **CI/CD:** The workflow deploys all environments automatically (dev → staging → prod)
- **Manual:** Repeat the steps above in each environment directory

---

## Post-Deployment Steps

### Configure CDN (Manual)

**When:** After storage module is deployed
**Where:** Scaleway Console > Edge Services

1. Go to Edge Services in Scaleway Console
2. Create a new pipeline for your media bucket
3. Configure caching rules:
   - Cache `processed/*` prefix
   - Set appropriate TTL (e.g., 1 year for processed images)
4. (Optional) Add custom domain for CDN
5. Update `S3_PUBLIC_ENDPOINT` environment variable with CDN URL

- [ ] Configure Edge Services CDN
- [ ] Update CDN endpoint in Terraform or environment variables

### Set Up Monitoring Alerts

**When:** After observability module is deployed
**Where:** Scaleway Console > Cockpit

1. Access Grafana dashboard (URL in Terraform output)
2. Configure alert rules:
   - High CPU usage (>80% for 5 min)
   - High memory usage (>80% for 5 min)
   - Database connection errors
   - Queue depth too high (>1000 messages)
3. Set up notification channels (email, Slack)

- [ ] Configure Grafana alerts
- [ ] Set up notification channels

### DNS Verification

**When:** After DNS module is deployed
**Where:** Your terminal and browser

```bash
# Verify DNS records
dig api.ciel-social.eu
dig media.ciel-social.eu

# Test HTTPS
curl -v https://api.ciel-social.eu/health
```

- [ ] Verify DNS records are resolving
- [ ] Verify SSL certificates are valid
- [ ] Test all endpoints

---

## Ongoing Operations

### Deploying Updates

For routine deployments, use GitHub Actions:

1. Push to `main` branch, OR
2. Manually trigger workflow in GitHub Actions

The CI/CD pipeline will:
- Build and push Docker image
- Run Terraform plan and apply
- Execute database migrations
- Send notifications

### Manual Deployment

If you need to deploy manually:

```bash
cd terraform/environments/prod

# Refresh state and plan
terraform plan -var="container_image_tag=NEW_TAG"

# Apply changes
terraform apply -var="container_image_tag=NEW_TAG"
```

### Scaling

To scale the infrastructure, update `terraform.tfvars`:

```hcl
# Increase API instances
api_instance_count = 4
api_instance_type  = "DEV1-M"

# Add workers
worker_instance_count = 3

# Upgrade database
db_node_type = "DB-PRO2-S"
```

Then run `terraform apply`.

---

## Rollback Procedures

### Application Rollback

```bash
# Deploy previous Docker image tag
terraform apply -var="container_image_tag=PREVIOUS_TAG"
```

### Infrastructure Rollback

```bash
# Use Terraform state to rollback
terraform apply -target=module.compute

# Or restore from state backup
terraform state pull > backup.tfstate
# Make changes
terraform state push backup.tfstate
```

### Database Rollback

Database migrations are forward-only. For rollback:

1. Restore from backup (Scaleway provides automatic backups)
2. Or write a reverse migration SQL script

---

## Troubleshooting

### Common Issues

1. **Terraform init fails with S3 error**
   - Verify state bucket exists
   - Check access key and secret key

2. **Container won't start**
   - Check registry authentication
   - Verify image tag exists
   - Check cloud-init logs: `/var/log/cloud-init-output.log`

3. **Database connection fails**
   - Verify private network configuration
   - Check security groups
   - Ensure instance is in same private network as database

4. **DNS not resolving**
   - Wait for propagation (up to 48 hours)
   - Verify nameservers at registrar
   - Check Scaleway DNS zone configuration

### Getting Help

- Scaleway Documentation: https://www.scaleway.com/en/docs/
- Terraform Scaleway Provider: https://registry.terraform.io/providers/scaleway/scaleway/latest/docs
- GitHub Issues: https://github.com/your-repo/issues

---

## Security Reminders

1. **Never commit `terraform.tfvars` to version control**
2. **Rotate secrets regularly** (every 90 days recommended)
3. **Use separate credentials per environment**
4. **Enable MFA on your Scaleway account**
5. **Review IAM policies periodically**
6. **Keep Terraform and provider versions updated**
7. **Admin-only endpoints require `X-Admin-Token` header** (token stored in Secret Manager)
