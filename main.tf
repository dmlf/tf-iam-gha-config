data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com/.well-known/openid-configuration"
}
resource "aws_iam_openid_connect_provider" "github_actions" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]
}

locals {
  repositories = { 
    for repo in [
      for GH_OIDC_CONF in var.permission_config_files  : 
        yamldecode(file("${path.cwd}/config/${GH_OIDC_CONF}"))
    ] :
    keys(repo)[0] => values(repo)[0]
  }

  permission_yaml = yamldecode(file("${path.cwd}/config/permissions.yaml"))  
}


# Create roles 
# One role per repo, multiple trust policies statements per role (one per repo/branche tuple)

data "aws_iam_policy_document" "assume_role" {
  for_each = local.repositories.authorized-github-repositories

  statement { 
    sid = "AssumeRoleOIDC"

    actions = [
    "sts:AssumeRoleWithWebIdentity"
    ]

    principals {
        type        = "Federated"
        identifiers = [ aws_iam_openid_connect_provider.oidc_provider.arn ]
    }

    condition {
        test     = "StringLike"
        variable = "${aws_iam_openid_connect_provider.oidc_provider.url}:sub"
        values   =  [ for branch in try(each.value.branches, {}) : "repo:${each.value.organisation}/${each.value.repo-name}:ref:refs/heads/${branch}"]
    }
    condition {
        test     = "StringLike"
        variable = "${aws_iam_openid_connect_provider.oidc_provider.url}:sub"
        values   =  [ for tag in try(each.value.tags, {}) : "repo:${each.value.organisation}/${each.value.repo-name}:ref:refs/tags/${tag}"]
    }
  }
}

resource "aws_iam_role" "role" {
  for_each =  local.repositories.authorized-github-repositories
  name                  = "gha-${each.value.organisation}-${each.value.repo-name}" 
  assume_role_policy    = data.aws_iam_policy_document.assume_role[each.key].json
  managed_policy_arns   = distinct(flatten([
                                for repo_permission in each.value.permissions : [                          
                                    for arn in try(local.permission_yaml.permissions[repo_permission].managed_policy_arns, {} ) : arn
                                ]
                            ]))
  // This is gathering all policy statements from the permissions.yaml file for each permissions configured for each repo.    
  inline_policy {
     policy = jsonencode( { Statement = distinct(flatten([ 
                                for repo_permission in each.value.permissions : [
                                    for statement in try(local.permission_yaml.permissions[repo_permission].policy_statement.Statement, {} ) : statement
                                ]
                            ]))
     })
     name = "${each.value.organisation}-${each.value.repo-name}-inline-policy" 
   }
}