output "ecs_exec_role_policy_id" {
  description = "The ECS service role policy ID, in the form of `role_name:role_policy_name`"
  value = one([
    for k, v in aws_iam_role_policy.ecs_exec : v.id
  ])
}

output "ecs_exec_role_policy_name" {
  description = "ECS service role name"
  value = one([
    for k, v in aws_iam_role_policy.ecs_exec : v.name
  ])
}

output "task_exec_role_name" {
  description = "ECS Task exec role name"
  value       = one(aws_iam_role.ecs_exec[*]["name"])
}

output "task_exec_role_arn" {
  description = "ECS Task exec role ARN"
  value       = length(local.task_exec_role_arn) > 0 ? local.task_exec_role_arn : one(aws_iam_role.ecs_exec[*]["arn"])
}

output "task_exec_role_id" {
  description = "ECS Task exec role id"
  value       = one(aws_iam_role.ecs_exec[*]["unique_id"])
}

output "task_role_name" {
  description = "ECS Task role name"
  value       = one(aws_iam_role.ecs_task[*]["name"])
}

output "task_role_arn" {
  description = "ECS Task role ARN"
  value       = length(local.task_role_arn) > 0 ? local.task_role_arn : one(aws_iam_role.ecs_task[*]["arn"])
}

output "task_role_id" {
  description = "ECS Task role id"
  value       = one(aws_iam_role.ecs_task[*]["unique_id"])
}

output "ecs_cluster_arn" {
  description = "ECS Cluster ARN"
  value       = one(aws_batch_compute_environment.this[*]["ecs_cluster_arn"])
}

output "batch_compute_environment_arn" {
  description = "Batch Compute Environment ARN"
  value       = one(aws_batch_compute_environment.this[*]["arn"])
}

output "batch_compute_queue_arn" {
  description = "Batch Compute Queue ARN"
  value       = one(aws_batch_job_queue.this[*]["arn"])
}

output "batch_job_definition_arn" {
  description = "Batch Job Definition ARN"
  value       = one(aws_batch_job_definition.this[*]["arn"])
}

output "batch_job_definition_arn_prefix" {
  description = "Batch Job Definition ARN prefix"
  value       = one(aws_batch_job_definition.this[*]["arn_prefix"])
}
