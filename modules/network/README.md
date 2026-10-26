# network

VPC, public and private subnets across `az_count` zones, optional NAT
(`enable_nat_gateway`, shared or per-AZ via `single_nat_gateway`), and VPC flow
logs to CloudWatch with an explicit retention.

```hcl
module "network" {
  source             = "./modules/network"
  name               = "acme-platform-dev"
  vpc_cidr           = "10.10.0.0/16"
  az_count           = 2
  enable_nat_gateway = false
}
```

Inputs are validated (`/16` CIDR, 2-4 AZs, supported log retention). Outputs:
`vpc_id`, `public_subnet_ids`, `private_subnet_ids`, `nat_gateway_ids`.
Tags come from the caller's provider `default_tags`.
Every IAM role it creates gets `permissions_boundary_arn` when set.
