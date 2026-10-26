# GitHub Actions identities. No long-lived keys: workflows exchange a short-lived
# OIDC token for role credentials.
#
#   plan role   one role, read-only. Assumable from pull_request workflows of
#               this repository only. Can read state and take the lock, can
#               assume the read-only terraform-plan role in target accounts.
#               Cannot change infrastructure or state.
#   apply roles one per environment. Assumable ONLY by jobs that run in the
#               matching GitHub Environment, whose required reviewers and
#               deployment-branch rule (main only) gate it. Configure both on
#               every Environment; the sub claim alone does not encode the branch.
#
# Known risk, by design of any PR-plan pipeline: anyone who can open a pull
# request from a branch in this repository can change the Terraform or the
# workflow and run arbitrary code with the plan role. Mitigations here: the role
# is read-only, data-plane reads are denied in target accounts, fork PRs receive
# no OIDC token, and lock-table writes are limited to this stack's keys. Keep
# write access to the repository small and protect .github/ with CODEOWNERS.

data "aws_caller_identity" "current" {}

# thumbprint_list is optional from AWS provider 5.81 (IAM validates GitHub's
# certificate against its own trusted CAs), hence the version floor in versions.tf.
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

locals {
  oidc_arn  = aws_iam_openid_connect_provider.github.arn
  state_arn = aws_s3_bucket.state.arn
  lock_arn  = aws_dynamodb_table.locks.arn
  # The S3 backend's lock items are keyed "<bucket>/<key>" (and "<bucket>/<key>-md5").
  lock_key_base = "${aws_s3_bucket.state.bucket}/${var.state_key_prefix}"
  target_arn    = { for env, acct in var.environments : env => "arn:aws:iam::${acct}:role" }
}

# --- plan role -----------------------------------------------------------------

data "aws_iam_policy_document" "plan_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [local.oidc_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    # Pull requests in this repository only. A scheduled drift check on main
    # would add "repo:<repo>:ref:refs/heads/main" here.
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repository}:pull_request"]
    }
  }
}

data "aws_iam_policy_document" "plan" {
  # Read state objects, nothing else in the bucket.
  statement {
    sid       = "ReadState"
    actions   = ["s3:GetObject"]
    resources = ["${local.state_arn}/${var.state_key_prefix}/*"]
  }
  statement {
    sid       = "ListStateBucket"
    actions   = ["s3:ListBucket"]
    resources = [local.state_arn]
  }
  # `terraform plan` takes the state lock, so it needs item-level write on the
  # lock table (no table admin). This is the one write a plan role must have.
  statement {
    sid       = "TakeStateLock"
    actions   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem"]
    resources = [local.lock_arn]
    condition {
      test     = "ForAllValues:StringLike"
      variable = "dynamodb:LeadingKeys"
      values   = ["${local.lock_key_base}/*"]
    }
  }
  statement {
    sid       = "AssumeReadOnlyTargetRoles"
    actions   = ["sts:AssumeRole"]
    resources = [for env, base in local.target_arn : "${base}/${var.target_plan_role_name}"]
  }
}

resource "aws_iam_role" "plan" {
  name                 = "github-terraform-plan"
  assume_role_policy   = data.aws_iam_policy_document.plan_trust.json
  max_session_duration = 3600
}

resource "aws_iam_role_policy" "plan" {
  name   = "plan"
  role   = aws_iam_role.plan.id
  policy = data.aws_iam_policy_document.plan.json
}

# --- apply roles (one per environment) -------------------------------------------

data "aws_iam_policy_document" "apply_trust" {
  for_each = var.environments

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [local.oidc_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    # Exact match on the GitHub Environment, so a branch or PR cannot assume it.
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repository}:environment:${each.key}"]
    }
  }
}

data "aws_iam_policy_document" "apply" {
  for_each = var.environments

  # Read-write on this environment's state object only.
  statement {
    sid       = "ReadWriteOwnState"
    actions   = ["s3:GetObject", "s3:PutObject"]
    resources = ["${local.state_arn}/${var.state_key_prefix}/${each.key}/*"]
  }
  statement {
    sid       = "ListStateBucket"
    actions   = ["s3:ListBucket"]
    resources = [local.state_arn]
  }
  # Lock and digest items of this environment's state only.
  statement {
    sid       = "StateLock"
    actions   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem"]
    resources = [local.lock_arn]
    condition {
      test     = "ForAllValues:StringLike"
      variable = "dynamodb:LeadingKeys"
      values   = ["${local.lock_key_base}/${each.key}/*"]
    }
  }
  # Only this environment's account, only the apply role.
  statement {
    sid       = "AssumeOwnApplyRole"
    actions   = ["sts:AssumeRole"]
    resources = ["${local.target_arn[each.key]}/${var.target_apply_role_name}"]
  }
}

resource "aws_iam_role" "apply" {
  for_each = var.environments

  name               = "github-terraform-apply-${each.key}"
  assume_role_policy = data.aws_iam_policy_document.apply_trust[each.key].json
}

resource "aws_iam_role_policy" "apply" {
  for_each = var.environments

  name   = "apply"
  role   = aws_iam_role.apply[each.key].id
  policy = data.aws_iam_policy_document.apply[each.key].json
}
