# Remote state configuration for production environment
# Create the bucket manually before running terraform init

terraform {
  backend "s3" {
    bucket   = "ciel-terraform-state"
    key      = "prod/terraform.tfstate"
    region   = "fr-par"
    endpoint = "https://s3.fr-par.scw.cloud"

    # Skip validations since we're using Scaleway S3-compatible endpoint
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_metadata_api_check     = true
  }
}