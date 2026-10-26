# compute

ECS Fargate cluster and service in private subnets with a deployment circuit
breaker, a log group with explicit retention, an egress-only security group, and
separate execution and task roles. The task role receives only the policies in
`task_policy_arns`.

```hcl
module "compute" {
  source           = "./modules/compute"
  name             = "acme-platform-dev"
  vpc_id           = module.network.vpc_id
  subnet_ids       = module.network.private_subnet_ids
  container_image  = "public.ecr.aws/docker/library/nginx:stable"
  task_policy_arns = { data_rw = module.security_baseline.data_rw_policy_arn }
}
```

Outputs: `cluster_name`, `service_name`, `task_role_arn`, `security_group_id`.
No load balancer is included to keep the sample small.

Every IAM role it creates gets `permissions_boundary_arn` when set.
