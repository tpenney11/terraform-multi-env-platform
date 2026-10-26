# Root configuration. One code base, many environments: everything that varies
# arrives through variables (env/<env>.tfvars) and the backend (backend/<env>.hcl).

provider "aws" {
  region = var.region

  # Multi-account: authenticate with the CI/human identity, then assume a role
  # in the environment's own account. Plans use a read-only role, applies a
  # scoped write role (see bootstrap/).
  assume_role {
    role_arn     = "arn:aws:iam::${var.target_account_id}:role/${var.target_role_name}"
    session_name = "terraform-${var.environment}"
  }

  default_tags {
    tags = local.tags
  }
}

module "network" {
  source = "./modules/network"

  name                     = local.name
  vpc_cidr                 = var.vpc_cidr
  az_count                 = var.az_count
  enable_nat_gateway       = var.enable_nat_gateway
  single_nat_gateway       = var.single_nat_gateway
  flow_log_retention_days  = var.flow_log_retention_days
  permissions_boundary_arn = local.permissions_boundary_arn
}

module "security_baseline" {
  source = "./modules/security-baseline"

  name          = local.name
  bucket_name   = "${local.name}-data-${var.target_account_id}"
  force_destroy = var.force_destroy
}

module "compute" {
  source = "./modules/compute"

  name               = local.name
  vpc_id             = module.network.vpc_id
  subnet_ids         = module.network.private_subnet_ids
  container_image    = var.container_image
  container_port     = var.container_port
  cpu                = var.service_cpu
  memory             = var.service_memory
  desired_count      = var.service_desired_count
  log_retention_days = var.log_retention_days

  permissions_boundary_arn = local.permissions_boundary_arn

  # Least privilege: the task may read/write only the environment's data bucket.
  task_policy_arns = {
    data_rw = module.security_baseline.data_rw_policy_arn
  }

  environment_variables = {
    DATA_BUCKET = module.security_baseline.bucket_id
  }
}
