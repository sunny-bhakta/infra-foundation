output "ecs_task_execution_role_arn" {
  description = "ARN of the ECS task execution role."
  value       = module.iam.ecs_task_execution_role_arn
}

output "ecs_task_role_arn" {
  description = "ARN of the ECS task role."
  value       = module.iam.ecs_task_role_arn
}