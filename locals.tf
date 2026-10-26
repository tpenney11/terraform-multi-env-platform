# Naming and tagging conventions, computed once and reused everywhere.
locals {
  name = "${var.org}-${var.project}-${var.environment}"

  permissions_boundary_arn = "arn:aws:iam::${var.target_account_id}:policy/${var.permissions_boundary_name}"

  # Applied to every taggable resource through the provider's default_tags,
  # so modules do not need to pass tags around and nothing can be forgotten.
  tags = {
    Environment = var.environment
    Owner       = var.owner
    CostCenter  = var.cost_center
    Project     = var.project
    ManagedBy   = "terraform"
  }
}
