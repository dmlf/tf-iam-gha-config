# Setup the IAM Roles to be configured for github actions OIDC authentication
module "repo_gh_oidc_setup" {
  source = "github.com/dmlf/tf-iam-gha-config?ref=0.1.0"
  
  permission_config_files = fileset("${path.module}/config", "gha_permissions_*")
  
}