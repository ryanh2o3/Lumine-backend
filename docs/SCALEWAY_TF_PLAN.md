# Ciel Backend - Scaleway Infrastructure Plan

## Architecture Overview

The infrastructure uses a **combined single-instance** model for compute with an **event-driven serverless container** for media processing. This minimizes cost at low traffic while providing a clear scaling path.

```
                    ┌──────────────────────────┐
                    │   Scaleway SQS (MNQ)     │
                    │   ciel-media-jobs queue   │
                    └─────────┬────────────────┘
                              │ SQS Trigger (POST)
                              ▼
┌───────────────┐   ┌──────────────────────┐
│  Clients      │   │ Serverless Container │
│  (iOS/Android)├──►│  media-processor     │
│               │   │  APP_MODE=           │
└───────┬───────┘   │  serverless-worker   │
        │           └──────────┬───────────┘
        ▼                      │
┌───────────────────┐          │
│ Combined Instance │          │
│  (DEV1-M)         │          │
│  ┌─────────────┐  │          │
│  │ Ciel API    │  │          │
│  │ APP_MODE=api│  │          │
│  └─────────────┘  │          │
│  ┌─────────────┐  │          │
│  │ Redis 7     │  │          │
│  └─────────────┘  │          │
└─────────┬─────────┘          │
          │                    │
          ▼                    ▼
┌──────────────────────────────────┐
│  Managed PostgreSQL (DB-DEV-S)   │
│  Private Network                 │
└──────────────────────────────────┘
          │
┌──────────────────────────────────┐
│  Object Storage (S3)             │
│  ciel-media-dev bucket           │
└──────────────────────────────────┘
```

### How It Works

1. **Combined Instance** runs both the Ciel API (`APP_MODE=api`) and Redis in Docker containers on a single DEV1-M machine. The API handles all HTTP traffic and enqueues media processing jobs to SQS.

2. **Serverless Container** receives SQS messages via Scaleway's native trigger. Each message is POSTed as the request body. The container runs `APP_MODE=serverless-worker`, which only needs DB + S3 (no Redis, no PASETO keys). It scales to zero when idle and auto-scales up to `max_scale` under load.

3. **Managed PostgreSQL** sits on the private network. Both the combined instance and serverless container connect to it.

4. **Object Storage** holds uploaded media (originals + processed variants). Both the API (for presigned URLs) and worker (for image processing) access it.

---

## Module Structure

```
terraform/
├── modules/
│   ├── networking/    # VPC, Private Network, Security Groups, Public Gateway, Bastion, LB
│   ├── compute/       # Container Registry, Combined/API/Worker instances, Serverless Container
│   ├── database/      # Managed PostgreSQL, read replicas
│   ├── cache/         # Redis (self-hosted instance or managed) — disabled in combined mode
│   ├── storage/       # Object Storage bucket, IAM credentials, CDN
│   ├── messaging/     # MNQ SQS queue + DLQ
│   ├── secrets/       # Scaleway Secret Manager
│   ├── observability/ # Cockpit monitoring
│   └── dns/           # Domain DNS records
├── environments/
│   ├── dev/           # Single combined instance + serverless worker
│   ├── staging/       # (future) Same as dev or split mode
│   └── prod/          # (future) Multi-instance + LB + managed Redis
```

---

## Dev Environment Configuration

The dev environment (`terraform/environments/dev/main.tf`) uses these key settings:

| Module | Setting | Value |
|--------|---------|-------|
| **networking** | `enable_load_balancer` | `false` |
| **networking** | `enable_bastion` | `true` |
| **networking** | `enable_public_gateway` | `true` |
| **database** | `db_node_type` | `DB-DEV-S` |
| **database** | `enable_ha` | `false` |
| **cache** | `enabled` | `false` (Redis runs on combined instance) |
| **compute** | `enable_combined_mode` | `true` |
| **compute** | `combined_instance_type` | `DEV1-M` |
| **compute** | `api_instance_count` | `0` |
| **compute** | `worker_instance_count` | `0` |
| **compute** | `enable_serverless_worker` | `true` |
| **compute** | `serverless_worker_min_scale` | `0` (scale to zero) |
| **compute** | `serverless_worker_max_scale` | `3` |
| **storage** | `enable_cdn` | `false` |
| **observability** | `enable_alerts` | `false` |

---

## Cost Analysis

### Dev / MVP (current configuration)

| Component | Resource | Monthly Cost |
|-----------|----------|-------------|
| Combined Instance | 1x DEV1-M (3 vCPU, 4GB RAM) | ~€19 |
| Database | DB-DEV-S | ~€17 |
| Object Storage | ~50GB | ~€0.75 |
| Messaging (SQS) | First 1M requests free | €0 |
| Serverless Worker | Scale-to-zero, free tier covers light use | ~€0 |
| Secrets Manager | ~10 secrets | ~€0.40 |
| Public Gateway | VPC-GW-S | ~€5 |
| Bastion | DEV1-S (optional, can disable) | ~€6 |
| **Total** | | **~€48/month** |

> Scaleway free tiers: 400K GB-s + 200K vCPU-s/month for Serverless Containers, 75GB Object Storage, 1M SQS requests/month.

---

## Scaling Scenarios

Each scenario lists the exact Terraform variable changes. Apply them in `terraform.tfvars` or via `TF_VAR_*` environment variables, then `terraform apply`.

### Scenario 1: Upgrade Combined Instance (more CPU/RAM)

**When:** API response times degrade under load, Redis memory pressure.

```hcl
# In dev/main.tf or override via tfvars
combined_instance_type      = "DEV1-L"     # was DEV1-M — 4 vCPU, 8GB
embedded_redis_maxmemory_mb = 1024         # was 512
```

**Cost delta:** +€19/mo (DEV1-L is ~€38/mo vs DEV1-M at ~€19/mo)

---

### Scenario 2: Split API and Redis to Separate Instances

**When:** Redis and API compete for resources, or you want independent scaling.

```hcl
# compute module
enable_combined_mode  = false
api_instance_count    = 1
api_instance_type     = "DEV1-S"   # or DEV1-M

# cache module
enabled              = true
use_managed_redis    = false       # Self-hosted Redis on DEV1-S
redis_instance_type  = "DEV1-S"
```

You also need to pass `redis_host` and `redis_port` to the compute module (the cache module outputs these).

**Cost delta:** ~+€6/mo (separate DEV1-S for Redis), but frees combined instance resources.

---

### Scenario 3: Add Load Balancer + Multiple API Instances

**When:** Single API instance can't handle request volume; you need horizontal scaling and zero-downtime deploys.

```hcl
# networking module
enable_load_balancer = true
lb_type              = "LB-GP-S"

# compute module
enable_combined_mode = false
api_instance_count   = 2           # or 3, 4...
api_instance_type    = "DEV1-M"

# cache module
enabled             = true
use_managed_redis   = false
```

The compute module automatically registers instances with the load balancer backend.

**Cost delta:** +€12/mo (LB) + per-instance cost.

---

### Scenario 4: Upgrade to Managed Redis

**When:** You need HA Redis, TLS, or don't want to manage Redis yourself.

```hcl
# cache module
enabled              = true
use_managed_redis    = true
managed_redis_node_type = "RED1-micro"   # or RED1-S, RED1-M
```

**Cost delta:** ~+€35/mo for RED1-micro (replaces self-hosted DEV1-S).

---

### Scenario 5: Upgrade Database

**When:** DB connections maxed out, query latency increasing, need HA.

```hcl
# database module
db_node_type         = "DB-PRO2-XXS"   # was DB-DEV-S
enable_ha            = true
volume_size_in_gb    = 20
read_replica_count   = 1               # optional read replica
```

**Cost delta:** ~+€63/mo for DB-PRO2-XXS with HA.

---

### Scenario 6: Scale Serverless Worker

**When:** Media processing queue is backing up.

```hcl
# compute module
serverless_worker_cpu       = 2000     # was 1000 (2 vCPU)
serverless_worker_memory    = 1024     # was 512 (1GB)
serverless_worker_max_scale = 10       # was 3
```

**Cost delta:** Minimal — serverless billing is per-invocation. Higher `max_scale` just allows more concurrency.

---

### Scenario 7: Enable CDN for Media

**When:** Media requests are high, want to reduce S3 egress and improve latency.

```hcl
# storage module
enable_cdn            = true
cors_allowed_origins  = ["https://yourdomain.com"]

# dns module (if using DNS)
enable_cdn_dns = true
cdn_subdomain  = "media"
```

> Edge Services CDN may require manual setup in Scaleway Console (Terraform provider support is limited).

---

### Scenario 8: Production-Ready (Full Split)

**When:** Moving to production with 10K+ users.

```hcl
# networking
enable_load_balancer = true
enable_bastion       = false          # or true for SSH debugging

# compute
enable_combined_mode    = false
api_instance_count      = 2
api_instance_type       = "DEV1-M"
enable_serverless_worker = true
serverless_worker_max_scale = 10

# database
db_node_type         = "DB-PRO2-XXS"
enable_ha            = true
volume_size_in_gb    = 20

# cache
enabled              = true
use_managed_redis    = true
managed_redis_node_type = "RED1-micro"

# storage
enable_cdn = true

# observability
enable_alerts = true
```

**Estimated cost:** ~€200-250/month

---

### Scenario 9: Kubernetes Migration (50K+ users)

**When:** You need rolling deployments, autoscaling, and service mesh capabilities.

- Scaleway Kapsule has a **free mutualized control plane**
- Use the same Docker image — just deploy via Kubernetes manifests instead of cloud-init
- The serverless worker stays as-is (no reason to move it to K8s)
- Migrate API + Redis into K8s pods on GP1-S or DEV1-L nodes

This is a larger migration that involves writing K8s manifests. The Terraform modules for database, storage, messaging, and secrets remain unchanged.

---

## Scaling Decision Matrix

| Symptom | Check | Action |
|---------|-------|--------|
| API P95 latency > 500ms | CPU on combined instance | Scenario 1 or 3 |
| Redis memory > 80% | `redis-cli INFO memory` | Scenario 1 or 2 |
| DB connections > 80% max | `pg_stat_activity` | Scenario 5 |
| Media queue depth > 1000 | SQS metrics in Cockpit | Scenario 6 |
| Need zero-downtime deploys | N/A | Scenario 3 |
| Going to production | N/A | Scenario 8 |
| > 50K active users | N/A | Scenario 9 |

---

## Environment Variables Mapping

Variables injected into containers via cloud-init (combined/API instances) or secret_environment_variables (serverless):

| App Variable | Source | Used By |
|-------------|--------|---------|
| `APP_MODE` | `api` or `serverless-worker` | Both |
| `DATABASE_URL` | `module.database.database_url` | Both |
| `REDIS_URL` | `redis://:<password>@redis:6379/` (combined) or managed endpoint | API only |
| `S3_ENDPOINT` | `module.storage.s3_endpoint` | Both |
| `S3_REGION` | `fr-par` | Both |
| `S3_BUCKET` | `module.storage.bucket_name` | Both |
| `S3_PUBLIC_ENDPOINT` | `module.storage.s3_public_endpoint` | API only |
| `QUEUE_ENDPOINT` | `module.messaging.queue_endpoint` | API only |
| `QUEUE_NAME` | `module.messaging.queue_name` | API only |
| `AWS_ACCESS_KEY_ID` | `module.storage.s3_access_key` (or SQS creds) | Both |
| `AWS_SECRET_ACCESS_KEY` | `module.storage.s3_secret_key` (or SQS creds) | Both |
| `PASETO_ACCESS_KEY` | From secrets module | API only |
| `PASETO_REFRESH_KEY` | From secrets module | API only |
| `HTTP_ADDR` | `0.0.0.0:8080` | Both |
| `RUST_LOG` | `debug,tower_http=debug` (dev) | Both |

> The serverless worker skips REDIS_URL, QUEUE_*, and PASETO_* — these are not required in `serverless-worker` mode.
