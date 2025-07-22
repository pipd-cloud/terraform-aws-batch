variable "container_definition_json" {
  type        = string
  description = <<-EOT
    A string containing a JSON-encoded array of container definitions
    (`"[{ "name": "container1", ... }, { "name": "container2", ... }]"`).
    See [API_ContainerDefinition](https://docs.aws.amazon.com/AmazonECS/latest/APIReference/API_ContainerDefinition.html),
    [cloudposse/terraform-aws-ecs-container-definition](https://github.com/cloudposse/terraform-aws-ecs-container-definition), or
    [ecs_task_definition#container_definitions](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition#container_definitions)
    EOT
}

variable "vpc_id" {
  type        = string
  description = "The VPC ID where resources are created"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnet IDs used in Service `network_configuration` if `var.network_mode = \"awsvpc\"`"
  default     = null
}

variable "security_group_enabled" {
  type        = bool
  description = "Whether to create a security group for the service."
  default     = true
}

variable "security_group_description" {
  type        = string
  default     = "Allow ALL egress from ECS service"
  description = <<-EOT
    The description to assign to the service security group.
    Warning: Changing the description causes the security group to be replaced.
    EOT
}

variable "enable_all_egress_rule" {
  type        = bool
  description = "A flag to enable/disable adding the all ports egress rule to the service security group"
  default     = true
}

variable "enable_icmp_rule" {
  type        = bool
  description = "Specifies whether to enable ICMP on the service security group"
  default     = false
}

variable "security_group_ids" {
  description = "Security group IDs to allow in Service `network_configuration` if `var.network_mode = \"awsvpc\"`"
  type        = list(string)
  default     = []
  validation {
    condition     = length(var.security_group_ids) > 0
    error_message = "You must provide at least one security group ID in `security_group_ids`."
  }
}

variable "platform_version" {
  type        = string
  default     = "LATEST"
  description = <<-EOT
    The platform version on which to run your service. Only applicable for `launch_type` set to `FARGATE`.
    More information about Fargate platform versions can be found in the AWS ECS User Guide.
    EOT
}

variable "task_exec_role_arn" {
  type        = any
  description = <<-EOT
    A `list(string)` of zero or one ARNs of IAM roles that allows the
    ECS/Fargate agent to make calls to the ECS API on your behalf.
    If the list is empty, a role will be created for you.
    DEPRECATED: you can also pass a `string` with the ARN, but that
    string must be known a "plan" time.
    EOT
  default     = []
}

variable "task_exec_policy_arns" {
  type        = list(string)
  description = <<-EOT
    A list of IAM Policy ARNs to attach to the generated task execution role.
    Changes to the list will have ripple effects, so use `task_exec_policy_arns_map` if possible.
    EOT
  default     = []
}

variable "task_exec_policy_arns_map" {
  type        = map(string)
  description = <<-EOT
    A map of name to IAM Policy ARNs to attach to the generated task execution role.
    The names are arbitrary, but must be known at plan time. The purpose of the name
    is so that changes to one ARN do not cause a ripple effect on the other ARNs.
    If you cannot provide unique names known at plan time, use `task_exec_policy_arns` instead.
    EOT
  default     = {}
}

variable "task_role_arn" {
  type        = any
  description = <<-EOT
    A `list(string)` of zero or one ARNs of IAM roles that allows
    your Amazon ECS container task to make calls to other AWS services.
    If the list is empty, a role will be created for you.
    DEPRECATED: you can also pass a `string` with the ARN, but that
    string must be known a "plan" time.
    EOT
  default     = []
}

variable "task_policy_arns" {
  type        = list(string)
  description = <<-EOT
    A list of IAM Policy ARNs to attach to the generated task role.
    Changes to the list will have ripple effects, so use `task_policy_arns_map` if possible.
    EOT

  default = []
}

variable "task_policy_arns_map" {
  type        = map(string)
  description = <<-EOT
    A map of name to IAM Policy ARNs to attach to the generated task role.
    The names are arbitrary, but must be known at plan time. The purpose of the name
    is so that changes to one ARN do not cause a ripple effect on the other ARNs.
    If you cannot provide unique names known at plan time, use `task_policy_arns` instead.
    EOT
  default     = {}
}

variable "runtime_platform" {
  type        = map(string)
  description = <<-EOT
    A map of runtime platform configuration options to use for the task definition.
    The map can include the following keys:
    - `cpuArchitecture`: The CPU architecture to use for tasks in the task definition. Valid values are `X86_64` and `ARM64`.
    - `operatingSystemFamily`: The operating system family to use for tasks in the task definition. Valid values are `LINUX` and `WINDOWS`.
    EOT
  default     = null
}

variable "efs_volumes" {
  type = list(object({
    host_path = string
    name      = string
    efs_volume_configuration = list(object({
      file_system_id          = string
      root_directory          = string
      transit_encryption      = string
      transit_encryption_port = string
      authorization_config = list(object({
        access_point_id = string
        iam             = string
      }))
    }))
  }))

  description = "Task EFS volume definitions as list of configuration objects. You can define multiple EFS volumes on the same task definition, but a single volume can only have one `efs_volume_configuration`."
  default     = []
}

variable "bind_mount_volumes" {
  type = list(object({
    host_path = optional(string)
    name      = string
  }))
  description = "Task bind mount volume definitions as list of configuration objects. You can define multiple bind mount volumes on the same task definition. Requires `name` and optionally `host_path`"
  default     = []
}

variable "assign_public_ip" {
  type        = bool
  description = "Assign a public IP address to the ENI (Fargate launch type only). Valid values are `true` or `false`. Default `false`"
  default     = false
}

variable "permissions_boundary" {
  type        = string
  description = "A permissions boundary ARN to apply to the 3 roles that are created."
  default     = ""
}

variable "exec_enabled" {
  type        = bool
  description = "Specifies whether to enable Amazon ECS Exec for the tasks within the service"
  default     = false
}

variable "ephemeral_storage_size" {
  type        = number
  description = "The number of GBs to provision for ephemeral storage on Fargate tasks. Must be greater than or equal to 21 and less than or equal to 200"
  default     = 0

  validation {
    condition     = var.ephemeral_storage_size == 0 || (var.ephemeral_storage_size >= 21 && var.ephemeral_storage_size <= 200)
    error_message = "The ephemeral_storage_size value must be inclusively between 21 and 200."
  }
}

variable "role_tags_enabled" {
  type        = bool
  description = "Whether or not to create tags on ECS roles"
  default     = true
}


variable "ipc_mode" {
  type        = string
  description = <<-EOT
    The IPC resource namespace to be used for the containers in the task.
    The valid values are `host`, `task`, and `none`. If `host` is specified,
    then all containers within the tasks that specified the `host` IPC mode on
    the same container instance share the same IPC resources with the host
    Amazon EC2 instance. If `task` is specified, all containers within the
    specified task share the same IPC resources. If `none` is specified, then
    IPC resources within the containers of a task are private and not shared
    with other containers in a task or on the container instance. If no value
    is specified, then the IPC resource namespace sharing depends on the
    Docker daemon setting on the container instance. For more information, see
    IPC settings in the Docker documentation."
    EOT
  default     = null
  validation {
    condition     = var.ipc_mode == null || contains(["host", "task", "none"], coalesce(var.ipc_mode, "null"))
    error_message = "The ipc_mode value must be one of host, task, or none."
  }
}

variable "pid_mode" {
  type        = string
  description = <<-EOT
    The process namespace to use for the containers in the task. The valid
    values are `host` and `task`. If `host` is specified, then all containers
    within the tasks that specified the `host` PID mode on the same container
    instance share the same process namespace with the host Amazon EC2 instanc
    . If `task` is specified, all containers within the specified task share
    the same process namespace. If no value is specified, then the process
    namespace sharing depends on the Docker daemon setting on the container
    instance. For more information, see PID settings in the Docker documentation.
    EOT
  default     = null
  validation {
    condition     = var.pid_mode == null || contains(["host", "task"], coalesce(var.pid_mode, "null"))
    error_message = "The pid_mode value must be one of host or task."
  }
}

variable "batch_compute_env_resource" {
  description = "The type of compute resource to use for the Batch compute environment. Valid values are EC2, SPOT, FARGATE, and FARGATE_SPOT."
  type        = string
  default     = "FARGATE"
}

variable "batch_compute_env_managed" {
  description = "Whether to create a managed or unmanaged Batch compute environment. Defaults to true (managed)."
  type        = bool
  default     = true
}

variable "batch_compute_env_enabled" {
  description = "Whether the Batch compute environment should be enabled. Defaults to true."
  type        = bool
  default     = true
}

variable "batch_compute_env_max_vcpus" {
  description = "The maximum number of vCPUs for the Batch compute environment. Defaults to 16."
  type        = number
  default     = 16
}

variable "batch_job_parameters" {
  description = "A map of default job parameters to pass to the Batch job definition. The keys are the parameter names and the values are the parameter values."
  type        = map(string)
  default     = {}
}

variable "batch_job_deregister_on_new_revision" {
  description = "Whether to deregister the previous revision of the Batch job definition when a new revision is created. Defaults to true."
  type        = bool
  default     = true
}
