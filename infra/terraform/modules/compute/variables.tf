variable "project_name" {
  description = "Project name used for resource naming."
  type        = string
}

variable "environment" {
  description = "Deployment environment."
  type        = string
}

variable "ecs_task_execution_role_arn" {
  description = "IAM role used by ECS to pull images and write logs."
  type        = string
}

variable "ecs_task_role_arn" {
  description = "IAM role used by the application running inside ECS."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs where ECS tasks will run."
  type        = list(string)
}

variable "ecs_security_group_id" {
  description = "Security group ID assigned to ECS tasks."
  type        = string
}

variable "container_image_tag" {
  description = "Immutable image tag to deploy from ECR (for example a Git SHA)."
  type        = string
  default     = "bootstrap"
}

variable "target_group_arn" {
  description = "ARN of the ALB target group."
  type        = string
}