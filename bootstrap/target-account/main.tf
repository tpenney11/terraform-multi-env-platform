# Run once per target account. Creates the two roles Terraform assumes there:
#   terraform-plan   AWS ReadOnlyAccess minus data-plane reads. Trusts the CI plan role.
#   terraform-apply  Scoped write access. Trusts the CI apply role(s).
# plus terraform-workload-boundary, the permissions boundary every IAM role the
# apply role creates must carry, so creating a role can never grant more than
# the workloads need.
# Trust is limited to specific role ARNs in the tooling account, not the account root.
#
# Example for the shared prod account:
#   terraform apply -var tooling_account_id=<tooling> \
#     -var 'apply_principal_names=["github-terraform-apply-prod-us-east-1","github-terraform-apply-prod-us-west-2","github-terraform-apply-prod-eu-central-1"]'

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "region" {
  description = "Region for the provider (IAM is global; any region works)."
  type        = string
  default     = "us-east-1"
}

variable "org" {
  description = "Organisation prefix; the apply role may only manage IAM objects named <org>-*."
  type        = string
  default     = "acme"
}

variable "tooling_account_id" {
  description = "Account hosting the CI roles (bootstrap output tooling_account_id)."
  type        = string
  default     = "444444444444"
}

variable "plan_principal_names" {
  description = "CI plan role names allowed to assume terraform-plan."
  type        = list(string)
  default     = ["github-terraform-plan"]
}

variable "apply_principal_names" {
  description = "CI apply role names allowed to assume terraform-apply in this account (the environments deployed here)."
  type        = list(string)
  default     = ["github-terraform-apply-dev"]
}

provider "aws" {
  region = var.region
}

locals {
  tooling_role = "arn:aws:iam::${var.tooling_account_id}:role"
  boundary_arn = aws_iam_policy.workload_boundary.arn
}

# --- permissions boundary for workload roles -----------------------------------
# The ceiling for every role the apply role creates (ECS task and execution
# roles, the flow-log role). Its name deliberately lacks the org prefix, so the
# apply role, which may only manage <org>-* policies, cannot edit it. Extend it
# when a workload needs a new service.

data "aws_iam_policy_document" "workload_boundary" {
  statement {
    sid = "WorkloadCeiling"
    actions = [
      # flow logs, and the awslogs driver via the task execution role
      "logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogStreams",
      # image pulls (task execution role)
      "ecr:GetAuthorizationToken", "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer", "ecr:BatchGetImage",
      # application data access (task role; the identity policy scopes the bucket and key)
      "s3:ListBucket", "s3:GetObject", "s3:GetObjectVersion", "s3:PutObject",
      "s3:AbortMultipartUpload", "kms:Decrypt", "kms:GenerateDataKey",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "workload_boundary" {
  name        = "terraform-workload-boundary"
  description = "Permissions boundary required on every IAM role created by terraform-apply."
  policy      = data.aws_iam_policy_document.workload_boundary.json
}

data "aws_iam_policy_document" "plan_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = [for n in var.plan_principal_names : "${local.tooling_role}/${n}"]
    }
  }
}

data "aws_iam_policy_document" "apply_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = [for n in var.apply_principal_names : "${local.tooling_role}/${n}"]
    }
  }
}

resource "aws_iam_role" "plan" {
  name               = "terraform-plan"
  assume_role_policy = data.aws_iam_policy_document.plan_trust.json
}

resource "aws_iam_role_policy_attachment" "plan_readonly" {
  role       = aws_iam_role.plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# ReadOnlyAccess also reads data, not just configuration. Plans only need
# configuration, and any pull request can run code with this role, so deny the
# data-plane reads explicitly.
data "aws_iam_policy_document" "plan_deny_data" {
  statement {
    sid    = "DenyDataPlaneReads"
    effect = "Deny"
    actions = [
      "s3:GetObject", "s3:GetObjectVersion",
      "dynamodb:GetItem", "dynamodb:BatchGetItem", "dynamodb:Query", "dynamodb:Scan",
      "ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath",
      "secretsmanager:GetSecretValue",
      "logs:GetLogEvents", "logs:FilterLogEvents", "logs:StartQuery",
      "sqs:ReceiveMessage", "kinesis:GetRecords",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "plan_deny_data" {
  name   = "deny-data-plane-reads"
  role   = aws_iam_role.plan.id
  policy = data.aws_iam_policy_document.plan_deny_data.json
}

resource "aws_iam_role" "apply" {
  name               = "terraform-apply"
  assume_role_policy = data.aws_iam_policy_document.apply_trust.json
}

# Scoped to the services this stack manages. Service-level wildcards are a
# starting point; narrow further (resource ARNs, conditions) as the stack settles.
data "aws_iam_policy_document" "apply" {
  statement {
    sid = "ManagedServices"
    actions = [
      "ec2:*",
      "ecs:*",
      "logs:*",
      "kms:*",
      "s3:*",
    ]
    resources = ["*"]
  }

  # IAM is where privilege escalation happens. Name scoping alone is not enough:
  # a role that may create <org>-* roles could create one with AdministratorAccess
  # and assume it. So every role the apply role creates or changes the
  # permissions of must carry the workload permissions boundary.
  statement {
    sid = "RolePermissionsOnlyWithBoundary"
    actions = [
      "iam:CreateRole", "iam:PutRolePermissionsBoundary",
      "iam:AttachRolePolicy", "iam:DetachRolePolicy",
      "iam:PutRolePolicy", "iam:DeleteRolePolicy",
    ]
    resources = ["arn:aws:iam::*:role/${var.org}-*"]
    condition {
      test     = "StringEquals"
      variable = "iam:PermissionsBoundary"
      values   = [local.boundary_arn]
    }
  }

  statement {
    sid = "RoleLifecycle"
    actions = [
      "iam:DeleteRole", "iam:UpdateRole", "iam:UpdateRoleDescription",
      "iam:UpdateAssumeRolePolicy", "iam:TagRole", "iam:UntagRole",
    ]
    resources = ["arn:aws:iam::*:role/${var.org}-*"]
  }

  # Customer-managed policies with the org prefix. The boundary policy has no
  # prefix, so it is out of reach.
  statement {
    sid = "ScopedPolicies"
    actions = [
      "iam:CreatePolicy", "iam:DeletePolicy", "iam:CreatePolicyVersion",
      "iam:DeletePolicyVersion", "iam:TagPolicy", "iam:UntagPolicy",
    ]
    resources = ["arn:aws:iam::*:policy/${var.org}-*"]
  }

  # Creating the first ECS cluster in an account creates the ECS service-linked role.
  statement {
    sid       = "EcsServiceLinkedRole"
    actions   = ["iam:CreateServiceLinkedRole"]
    resources = ["arn:aws:iam::*:role/aws-service-role/ecs.amazonaws.com/AWSServiceRoleForECS"]
    condition {
      test     = "StringEquals"
      variable = "iam:AWSServiceName"
      values   = ["ecs.amazonaws.com"]
    }
  }

  statement {
    sid       = "PassOnlyServiceRoles"
    actions   = ["iam:PassRole"]
    resources = ["arn:aws:iam::*:role/${var.org}-*"]
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com", "vpc-flow-logs.amazonaws.com"]
    }
  }

  statement {
    sid       = "ReadIamForRefresh"
    actions   = ["iam:Get*", "iam:List*"]
    resources = ["*"]
  }

  # Belt and braces: never strip a boundary or edit the boundary policy.
  statement {
    sid       = "NeverRemoveBoundaries"
    effect    = "Deny"
    actions   = ["iam:DeleteRolePermissionsBoundary"]
    resources = ["*"]
  }
  statement {
    sid    = "NeverEditBoundaryPolicy"
    effect = "Deny"
    actions = [
      "iam:CreatePolicyVersion", "iam:DeletePolicy", "iam:DeletePolicyVersion",
      "iam:SetDefaultPolicyVersion",
    ]
    resources = [local.boundary_arn]
  }
}

resource "aws_iam_role_policy" "apply" {
  name   = "scoped-apply"
  role   = aws_iam_role.apply.id
  policy = data.aws_iam_policy_document.apply.json
}

output "plan_role_arn" {
  description = "ARN of the read-only plan role in this account."
  value       = aws_iam_role.plan.arn
}

output "workload_boundary_arn" {
  description = "Permissions boundary the root configuration attaches to every IAM role it creates."
  value       = aws_iam_policy.workload_boundary.arn
}

output "apply_role_arn" {
  description = "ARN of the scoped apply role in this account."
  value       = aws_iam_role.apply.arn
}
