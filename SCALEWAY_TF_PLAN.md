Ciel Backend - Scaleway Terraform Infrastructure Plan │
│ │
│ Executive Summary │
│ │
│ Complete Terraform infrastructure plan for deploying the Ciel photo-sharing backend to Scaleway. Designed for ~€50-100/month │
│ starting budget with variable-driven scaling to 100K+ users. │
│ │
│ --- │
│ 1. Compute Strategy Recommendation │
│ │
│ Analysis of Options │
│ ┌─────────────────────┬───────────────────────────────────────────────┬─────────────────────────────────────────────┬────────────── │
│ ┐ │
│ │ Option │ Pros │ Cons │ Starting │
│ │ │
│ │ │ │ │ Cost │
│ │ │
│ ├─────────────────────┼───────────────────────────────────────────────┼─────────────────────────────────────────────┼────────────── │
│ ┤ │
│ │ Dedicated Instances │ Simple, predictable, full control, no │ Manual scaling, pay for idle │ ~€13/mo │
│ │ │
│ │ │ cold-starts │ │ │
│ │ │
│ ├─────────────────────┼───────────────────────────────────────────────┼─────────────────────────────────────────────┼────────────── │
│ ┤ │
│ │ Serverless │ Pay-per-use, auto-scaling │ Cold-starts, worker incompatible │ ~€30-60/mo │
│ │ │
│ │ Containers │ │ (long-polling) │ │
│ │ │
│ ├─────────────────────┼───────────────────────────────────────────────┼─────────────────────────────────────────────┼────────────── │
│ ┤ │
│ │ Kubernetes Kapsule │ Free control plane, standard K8s, easy │ Overkill for early stage, more complex │ ~€13-31/mo │
│ │ │
│ │ │ scaling │ │ │
│ │ │
│ └─────────────────────┴───────────────────────────────────────────────┴─────────────────────────────────────────────┴────────────── │
│ ┘ │
│ Recommendation │
│ │
│ Phase 1 (0-50K users): Dedicated Instances (DEV1-S/DEV1-M) │
│ - Simplest to deploy and debug │
│ - Predictable costs │
│ - Your worker runs as a long-polling loop - not serverless-compatible │
│ │
│ Phase 2 (50K+ users): Migrate to Kubernetes Kapsule │
│ - When horizontal scaling becomes critical │
│ - When you need rolling deployments │
│ - Same container image works in both │
│ │
│ Avoid Serverless Containers - Your worker's media_processor.rs runs a continuous polling loop, incompatible with serverless │
│ execution model. │
│ │
│ --- │
│ 2. Module Structure │
│ │
│ terraform/ │
│ ├── modules/ │
│ │ ├── networking/ # VPC, Private Networks, Security Groups, Load Balancer │
│ │ ├── compute/ # Instances, Container Registry, cloud-init │
│ │ ├── database/ # Managed PostgreSQL, read replicas │
│ │ ├── cache/ # Redis (self-hosted or managed) │
│ │ ├── storage/ # Object Storage, CDN, IAM │
│ │ ├── messaging/ # MNQ SQS queues │
│ │ ├── secrets/ # Secret Manager │
│ │ ├── observability/ # Cockpit, alerts │
│ │ └── dns/ # Domain records │
│ ├── environments/ │
│ │ ├── dev/ │
│ │ ├── staging/ │
│ │ └── prod/ │
│ └── shared/ │
│ ├── provider.tf │
│ └── versions.tf │
│ │
│ --- │
│ 3. Networking Module │
│ │
│ Resources │
│ │
│ - scaleway_vpc - Main VPC │
│ - scaleway_vpc_private_network - Private network (10.0.0.0/24) │
│ - scaleway_vpc_public_gateway - Outbound internet access (VPC-GW-S) │
│ - scaleway_lb - Load balancer for API instances (LB-GP-S) │
│ - scaleway_lb_backend - Health checks on /health │
│ - scaleway_lb_frontend - HTTPS termination (port 443) │
│ - scaleway_instance_security_group - API (allow 8080, SSH optional) │
│ - scaleway_instance_security_group - Worker (outbound only) │
│ │
│ Key Variables │
│ │
│ variable "enable_load_balancer" { default = true } │
│ variable "lb_type" { default = "LB-GP-S" } │
│ variable "enable_bastion" { default = false } │
│ variable "private_network_cidr" { default = "10.0.0.0/24" } │
│ │
│ --- │
│ 4. Compute Module │
│ │
│ Resources │
│ │
│ - scaleway_registry_namespace - Container registry for Docker images │
│ - scaleway_instance_server (API) - Runs with APP_MODE=api │
│ - scaleway_instance_server (Worker) - Runs with APP_MODE=worker │
│ - Cloud-init templates for Docker setup and container deployment │
│ │
│ Key Variables │
│ │
│ variable "api_instance_count" { default = 1 } │
│ variable "api_instance_type" { default = "DEV1-S" } │
│ variable "worker_instance_count" { default = 1 } │
│ variable "worker_instance_type" { default = "DEV1-S" } │
│ variable "container_image_tag" { default = "latest" } │
│ │
│ Cloud-Init Strategy │
│ │
│ Instances boot with Debian, install Docker, pull image from Scaleway Container Registry, and run via docker-compose with │
│ environment variables injected from Terraform outputs. │
│ │
│ --- │
│ 5. Database Module │
│ │
│ Resources │
│ │
│ - scaleway_rdb_instance - Managed PostgreSQL 16 │
│ - scaleway_rdb_database - ciel database │
│ - scaleway_rdb_user - Application user with limited privileges │
│ - scaleway_rdb_privilege - Grant permissions │
│ - scaleway_rdb_read_replica - For scaling reads (optional) │
│ │
│ Key Variables │
│ │
│ variable "db_node_type" { default = "DB-DEV-S" } # ~€17/mo │
│ variable "enable_ha" { default = false } │
│ variable "volume_size_in_gb" { default = 10 } │
│ variable "read_replica_count" { default = 0 } │
│ │
│ Outputs │
│ │
│ - database_url - Full connection string for app │
│ │
│ PostgreSQL Settings │
│ │
│ db_settings = { │
│ work_mem = "4MB" │
│ max_connections = "100" │
│ effective_cache_size = "768MB" │
│ } │
│ │
│ --- │
│ 6. Cache Module │
│ │
│ Option A: Self-Managed Redis (Cost-Optimized) - Recommended for Start │
│ │
│ - scaleway_instance_server - DEV1-S running Redis 7 │
│ - Cloud-init installs and configures Redis │
│ - Cost: ~€6.42/mo │
│ │
│ Option B: Managed Redis (Production) │
│ │
│ - scaleway_redis_cluster - RED1-micro or larger │
│ - Private network integration, TLS │
│ - Cost: ~€35+/mo │
│ │
│ Key Variables │
│ │
│ variable "use_managed_redis" { default = false } │
│ variable "redis_instance_type" { default = "DEV1-S" } │
│ variable "managed_redis_node_type" { default = "RED1-micro" } │
│ │
│ --- │
│ 7. Storage Module │
│ │
│ Resources │
│ │
│ - scaleway_object_bucket - Media storage bucket │
│ - scaleway_object_bucket_policy - CDN access policy │
│ - scaleway_iam_application - S3 access credentials │
│ - scaleway_iam_api_key - Access/secret key pair │
│ - scaleway_iam_policy - Read/Write/Delete permissions │
│ - Edge Services CDN pipeline (manual setup may be needed) │
│ │
│ Key Variables │
│ │
│ variable "cors_allowed_origins" { default = ["*"] } │
│ variable "enable_cdn" { default = true } │
│ variable "cdn_custom_domain" { default = null } │
│ variable "enable_glacier_transition" { default = false } │
│ │
│ Lifecycle Rules │
│ │
│ - Delete incomplete multipart uploads after 7 days │
│ - Optional: Transition old originals to Glacier after 90 days │
│ │
│ --- │
│ 8. Messaging Module (SQS-Compatible) │
│ │
│ Resources │
│ │
│ - scaleway_mnq_sqs - Enable SQS protocol │
│ - scaleway_mnq_sqs_credentials - Application credentials │
│ - scaleway_mnq_sqs_queue - ciel-media-jobs queue │
│ - scaleway_mnq_sqs_queue - Dead letter queue (optional) │
│ │
│ Key Variables │
│ │
│ variable "message_retention_seconds" { default = 345600 } # 4 days │
│ variable "visibility_timeout" { default = 300 } # 5 min for processing │
│ variable "receive_wait_time" { default = 10 } # Long polling │
│ variable "enable_dlq" { default = true } │
│ │
│ Outputs │
│ │
│ - queue_endpoint - https://sqs.mnq.fr-par.scaleway.com │
│ - queue_name - Queue name for QUEUE_NAME env var │
│ - sqs_access_key / sqs_secret_key - For AWS SDK │
│ │
│ --- │
│ 9. Secrets Module │
│ │
│ Resources │
│ │
│ - scaleway_secret + scaleway_secret_version for: │
│ - PASETO access key │
│ - PASETO refresh key │
│ - Admin token (optional) │
│ - Database credentials │
│ - Redis password │
│ - random_password - Generate secure passwords │
│ │
│ Key Secrets Required │
│ │
│ variable "paseto_access_key" { sensitive = true } # Base64 32-byte │
│ variable "paseto_refresh_key" { sensitive = true } # Base64 32-byte │
│ variable "admin_token" { sensitive = true } # Optional │
│ │
│ Generate PASETO Keys │
│ │
│ openssl rand -base64 32 # Run twice for access + refresh │
│ │
│ --- │
│ 10. Observability Module │
│ │
│ Resources │
│ │
│ - scaleway_cockpit - Enable monitoring │
│ - scaleway_cockpit_grafana_user - Dashboard access │
│ - scaleway_cockpit_alert_manager - Alert notifications │
│ │
│ Key Metrics to Monitor │
│ │
│ - API: Request latency P95, error rate, request rate │
│ - Database: Connection count, query latency, replication lag │
│ - Worker: Queue depth, processing time, failure rate │
│ - Infrastructure: CPU, memory, disk per instance │
│ │
│ --- │
│ 11. Environment Variables Mapping │
│ │
│ The following environment variables must be set from Terraform outputs: │
│ ┌───────────────────────┬─────────────────────────────────┐ │
│ │ App Variable │ Terraform Source │ │
│ ├───────────────────────┼─────────────────────────────────┤ │
│ │ DATABASE_URL │ module.database.database_url │ │
│ ├───────────────────────┼─────────────────────────────────┤ │
│ │ REDIS_URL │ module.cache.redis_url │ │
│ ├───────────────────────┼─────────────────────────────────┤ │
│ │ S3_ENDPOINT │ https://s3.fr-par.scw.cloud │ │
│ ├───────────────────────┼─────────────────────────────────┤ │
│ │ S3_REGION │ fr-par │ │
│ ├───────────────────────┼─────────────────────────────────┤ │
│ │ S3_BUCKET │ module.storage.bucket_name │ │
│ ├───────────────────────┼─────────────────────────────────┤ │
│ │ S3_PUBLIC_ENDPOINT │ module.storage.cdn_endpoint │ │
│ ├───────────────────────┼─────────────────────────────────┤ │
│ │ QUEUE_ENDPOINT │ module.messaging.queue_endpoint │ │
│ ├───────────────────────┼─────────────────────────────────┤ │
│ │ QUEUE_REGION │ fr-par │ │
│ ├───────────────────────┼─────────────────────────────────┤ │
│ │ QUEUE_NAME │ module.messaging.queue_name │ │
│ ├───────────────────────┼─────────────────────────────────┤ │
│ │ AWS_ACCESS_KEY_ID │ module.storage.s3_access_key │ │
│ ├───────────────────────┼─────────────────────────────────┤ │
│ │ AWS_SECRET_ACCESS_KEY │ module.storage.s3_secret_key │ │
│ ├───────────────────────┼─────────────────────────────────┤ │
│ │ PASETO_ACCESS_KEY │ From secrets input │ │
│ ├───────────────────────┼─────────────────────────────────┤ │
│ │ PASETO_REFRESH_KEY │ From secrets input │ │
│ ├───────────────────────┼─────────────────────────────────┤ │
│ │ APP_MODE │ api or worker │ │
│ ├───────────────────────┼─────────────────────────────────┤ │
│ │ HTTP_ADDR │ 0.0.0.0:8080 │ │
│ └───────────────────────┴─────────────────────────────────┘ │
│ --- │
│ 12. Cost Analysis │
│ │
│ Tier 1: MVP (0-10K users) - Target: ~€50-100/month │
│ ┌────────────────┬───────────────────────────┬──────────────┐ │
│ │ Component │ Resource │ Monthly Cost │ │
│ ├────────────────┼───────────────────────────┼──────────────┤ │
│ │ API Compute │ 1x DEV1-S │ €6.42 │ │
│ ├────────────────┼───────────────────────────┼──────────────┤ │
│ │ Worker Compute │ 1x DEV1-S │ €6.42 │ │
│ ├────────────────┼───────────────────────────┼──────────────┤ │
│ │ Database │ DB-DEV-S │ ~€17 │ │
│ ├────────────────┼───────────────────────────┼──────────────┤ │
│ │ Cache │ Self-managed Redis DEV1-S │ €6.42 │ │
│ ├────────────────┼───────────────────────────┼──────────────┤ │
│ │ Object Storage │ ~50GB │ ~€0.75 │ │
│ ├────────────────┼───────────────────────────┼──────────────┤ │
│ │ CDN │ Edge Services Starter │ €0.99 │ │
│ ├────────────────┼───────────────────────────┼──────────────┤ │
│ │ Load Balancer │ LB-GP-S │ ~€12 │ │
│ ├────────────────┼───────────────────────────┼──────────────┤ │
│ │ Messaging │ SQS (1M free) │ €0 │ │
│ ├────────────────┼───────────────────────────┼──────────────┤ │
│ │ Secrets │ 10 versions │ ~€0.40 │ │
│ ├────────────────┼───────────────────────────┼──────────────┤ │
│ │ Total │ │ ~€50/month │ │
│ └────────────────┴───────────────────────────┴──────────────┘ │
│ Tier 2: Growth (10K-50K users) - ~€200/month │
│ ┌──────────┬───────────────┬────────────┐ │
│ │ Change │ New Resource │ Cost Delta │ │
│ ├──────────┼───────────────┼────────────┤ │
│ │ API │ 2x DEV1-M │ +€22 │ │
│ ├──────────┼───────────────┼────────────┤ │
│ │ Worker │ 2x DEV1-S │ +€6 │ │
│ ├──────────┼───────────────┼────────────┤ │
│ │ Database │ DB-PRO2-XXS │ +€63 │ │
│ ├──────────┼───────────────┼────────────┤ │
│ │ Cache │ Managed Redis │ +€28 │ │
│ ├──────────┼───────────────┼────────────┤ │
│ │ LB │ LB-GP-M │ +€15 │ │
│ ├──────────┼───────────────┼────────────┤ │
│ │ CDN │ Professional │ +€12 │ │
│ └──────────┴───────────────┴────────────┘ │
│ Tier 3: Scale (50K-100K+ users) - ~€600-800/month │
│ │
│ - 4x DEV1-L or Kapsule cluster │
│ - DB-PRO2-S + Read Replica │
│ - Managed Redis RED1-M │
│ - Advanced CDN tier │
│ │
│ --- │
│ 13. Scaling via Variables │
│ │
│ Scale infrastructure by changing terraform.tfvars: │
│ │
│ # Horizontal API scaling │
│ api_instance_count = 2 │
│ api_instance_type = "DEV1-M" │
│ │
│ # More workers for media backlog │
│ worker_instance_count = 3 │
│ │
│ # Database upgrade │
│ db_node_type = "DB-PRO2-XXS" │
│ db_enable_ha = true │
│ db_read_replica_count = 1 │
│ │
│ # Switch to managed Redis │
│ use_managed_redis = true │
│ managed_redis_node_type = "RED1-M" │
│ │
│ Scaling Triggers │
│ ┌─────────────────┬────────────────┬─────────────────────────┐ │
│ │ Metric │ Threshold │ Action │ │
│ ├─────────────────┼────────────────┼─────────────────────────┤ │
│ │ API CPU │ >70% sustained │ Add instance or upgrade │ │
│ ├─────────────────┼────────────────┼─────────────────────────┤ │
│ │ API latency P95 │ >500ms │ Add instance, check DB │ │
│ ├─────────────────┼────────────────┼─────────────────────────┤ │
│ │ Queue depth │ >1000 messages │ Add worker │ │
│ ├─────────────────┼────────────────┼─────────────────────────┤ │
│ │ DB connections │ >80% max │ Upgrade or add replica │ │
│ ├─────────────────┼────────────────┼─────────────────────────┤ │
│ │ Redis memory │ >80% │ Upgrade tier │ │
│ └─────────────────┴────────────────┴─────────────────────────┘ │
│ --- │
│ 14. CI/CD Integration │
│ │
│ GitHub Actions Workflow │
│ │
│ 1. Build: Build Docker image, push to Scaleway Container Registry │
│ 2. Migrate: Run SQL migrations against database │
│ 3. Deploy: terraform apply with new image tag │
│ 4. Rollout: Restart instances to pull new image │
│ │
│ Required GitHub Secrets │
│ │
│ - SCW_ACCESS_KEY / SCW_SECRET_KEY │
│ - SCW_PROJECT_ID │
│ - PASETO_ACCESS_KEY / PASETO_REFRESH_KEY │
│ - DB_ADMIN_PASSWORD │
│ - DATABASE_URL (for migrations) │
│ │
│ --- │
│ 15. Remote State Configuration │
│ │
│ terraform { │
│ backend "s3" { │
│ bucket = "ciel-terraform-state" │
│ key = "prod/terraform.tfstate" │
│ region = "fr-par" │
│ endpoint = "https://s3.fr-par.scw.cloud" │
│ skip_credentials_validation = true │
│ skip_region_validation = true │
│ } │
│ } │
│ │
│ Create the state bucket manually before first terraform init. │
│ │
│ --- │
│ 16. Implementation Steps │
│ │
│ 1. Create Scaleway Project (manual) │
│ 2. Create state bucket for Terraform remote state │
│ 3. Generate PASETO keys: openssl rand -base64 32 (twice) │
│ 4. Create terraform.tfvars with secrets │
│ 5. Deploy dev environment first: terraform apply │
│ 6. Run database migrations: Apply SQL files from /migrations │
│ 7. Build and push container image to registry │
│ 8. Verify deployment: Check /health endpoint │
│ 9. Configure DNS: Point domain to load balancer IP │
│ 10. Enable CDN: Configure Edge Services for media bucket │
│ │
│ --- │
│ 17. Files to Create │
│ │
│ terraform/ │
│ ├── modules/ │
│ │ ├── networking/ │
│ │ │ ├── main.tf │
│ │ │ ├── variables.tf │
│ │ │ └── outputs.tf │
│ │ ├── compute/ │
│ │ │ ├── main.tf │
│ │ │ ├── variables.tf │
│ │ │ ├── outputs.tf │
│ │ │ ├── cloud-init-api.yaml │
│ │ │ └── cloud-init-worker.yaml │
│ │ ├── database/ │
│ │ │ ├── main.tf │
│ │ │ ├── variables.tf │
│ │ │ └── outputs.tf │
│ │ ├── cache/ │
│ │ │ ├── main.tf │
│ │ │ ├── variables.tf │
│ │ │ ├── outputs.tf │
│ │ │ └── cloud-init-redis.yaml │
│ │ ├── storage/ │
│ │ │ ├── main.tf │
│ │ │ ├── variables.tf │
│ │ │ └── outputs.tf │
│ │ ├── messaging/ │
│ │ │ ├── main.tf │
│ │ │ ├── variables.tf │
│ │ │ └── outputs.tf │
│ │ ├── secrets/ │
│ │ │ ├── main.tf │
│ │ │ ├── variables.tf │
│ │ │ └── outputs.tf │
│ │ └── observability/ │
│ │ ├── main.tf │
│ │ ├── variables.tf │
│ │ └── outputs.tf │
│ ├── environments/ │
│ │ ├── dev/ │
│ │ │ ├── main.tf │
│ │ │ ├── variables.tf │
│ │ │ ├── outputs.tf │
│ │ │ ├── backend.tf │
│ │ │ └── terraform.tfvars.example │
│ │ ├── staging/ │
│ │ │ └── (same structure) │
│ │ └── prod/ │
│ │ └── (same structure) │
│ └── .github/ │
│ └── workflows/ │
│ └── deploy.yml │
│ │
│ --- │
│ 18. Cost Optimization Notes │
│ │
│ 1. Self-managed Redis saves ~€28/mo vs managed (use for MVP) │
│ 2. DEV1-S instances are most cost-effective for low traffic │
│ 3. First 75GB storage free, 1TB CDN egress free │
│ 4. SQS first 1M requests free per month │
│ 5. VPC and Private Networks are free │
│ 6. Consider Reserved Instances for 30-50% savings at scale │
│ 7. Glacier transition for old original images saves storage costs │
│ │
│ --- │
│ 19. Potential Issues & Considerations │
│ │
│ 1. MNQ SQS endpoint format - Verify your queue.rs uses the correct Scaleway MNQ endpoint format │
│ 2. S3 credentials - Scaleway uses project-scoped IAM, not AWS IAM │
│ 3. Container Registry auth - Instances need scw CLI or registry credentials │
│ 4. Database migrations - Need a migration runner in CI/CD (not built into instances) │
│ 5. Edge Services Terraform - Provider support may be limited; some manual setup │
│ 6. Load balancer SSL - Need to provision Let's Encrypt certificate │
│ │
│ --- │
│ 20. Verification Plan │
│ │
│ After deployment: │
│ │
│ 1. Health check: curl https://api.yourdomain.com/health │
│ 2. Database connectivity: Check logs for successful pool creation │
│ 3. Redis connectivity: Verify rate limiting works │
│ 4. S3 uploads: Test presigned URL generation │
│ 5. Queue processing: Upload image, verify worker processes it │
│ 6. CDN delivery: Verify media URLs resolve through CDN │
│ 7. Monitoring: Check Cockpit dashboards populate │
│ │
│ --- │
│ Summary │
│ │
│ This plan provides a complete, modular Terraform configuration for Scaleway with: │
│ - ~€50/month starting cost (well under €100 budget) │
│ - Variable-driven scaling to 100K+ users │
│ - 8 reusable modules following Terraform best practices │
│ - 3 environments (dev, staging, prod) │
│ - CI/CD ready with GitHub Actions workflow │
│ - Full observability via Scaleway Cockpit
