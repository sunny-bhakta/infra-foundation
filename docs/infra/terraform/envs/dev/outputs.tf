output "aws_account_id" {
  description = "AWS account ID used by Terraform."
  value       = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  description = "AWS region used by Terraform."
  value       = data.aws_region.current.region
}

output "vpc_id" {
  description = "ID of the dev VPC."
  value       = module.network.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets."
  value       = module.network.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of the private subnets."
  value       = module.network.private_subnet_ids
}

output "ecr_repository_name" {
  description = "Name of the ECR repository."
  value       = module.compute.ecr_repository_name
}

output "ecr_repository_url" {
  description = "URL of the ECR repository."
  value       = module.compute.ecr_repository_url
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster."
  value       = module.compute.ecs_cluster_name
}

output "ecs_service_name" {
  description = "Name of the ECS service."
  value       = module.compute.ecs_service_name
}

output "ecs_task_definition_arn" {
  description = "ARN of the ECS task definition."
  value       = module.compute.ecs_task_definition_arn
}