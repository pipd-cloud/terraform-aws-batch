locals {
  enabled                   = module.this.enabled
  task_role_arn             = try(var.task_role_arn[0], tostring(var.task_role_arn), "")
  create_task_role          = local.enabled && length(var.task_role_arn) == 0
  task_exec_role_arn        = try(var.task_exec_role_arn[0], tostring(var.task_exec_role_arn), "")
  create_exec_role          = local.enabled && length(var.task_exec_role_arn) == 0
  create_security_group     = local.enabled && var.security_group_enabled
  volumes                   = concat(var.efs_volumes, var.bind_mount_volumes)
  task_policy_arns_map      = merge({ for i, a in var.task_policy_arns : format("_#%v_", i) => a }, var.task_policy_arns_map)
  task_exec_policy_arns_map = merge({ for i, a in var.task_exec_policy_arns : format("_#%v_", i) => a }, var.task_exec_policy_arns_map)
  use_fargate               = var.batch_compute_env_resource == "FARGATE" || var.batch_compute_env_resource == "FARGATE_SPOT"
  # create_update_policy      = var.enable_update_policy
  # include_launch_template   = !local.use_fargate && (var.launch_template_id != null || var.launch_template_name != null)
  # include_ec2_configuration = !local.use_fargate && (var.image_id_override != null || var.image_type != null)
}

resource "aws_batch_compute_environment" "this" {
  count = local.enabled ? 1 : 0
  name  = module.batch_label.id
  type  = var.batch_compute_env_managed ? "MANAGED" : "UNMANAGED"
  state = var.batch_compute_env_enabled ? "ENABLED" : "DISABLED"
  tags  = module.batch_label.tags
  compute_resources {
    subnets            = var.subnet_ids
    security_group_ids = concat(var.security_group_ids, local.create_security_group ? [aws_security_group.batch[0].id] : [])
    type               = var.batch_compute_env_resource
    max_vcpus          = var.batch_compute_env_max_vcpus
    # min_vcpus           = local.use_fargate ? var.min_vcpus : null
    # desired_vcpus       = local.use_fargate ? var.desired_vcpus : null
    # ec2_key_pair        = local.use_fargate ? var.ec2_key_pair : null
    # allocation_strategy = local.use_fargate ? var.allocation_strategy : null
    # bid_percentage      = local.use_fargate ? var.bid_percentage : null
    # instance_role       = local.use_fargate ? var.instance_role : null
    # instance_type       = local.use_fargate ? var.instance_type : null
    # dynamic "launch_template" {
    #   for_each = local.include_launch_template ? [1] : []
    #   content {
    #     launch_template_id   = var.launch_template_id
    #     launch_template_name = var.launch_template_name
    #     version              = var.launch_template_version
    #   }
    # }
    # dynamic "ec2_configuration" {
    #   for_each = local.include_ec2_configuration ? [1] : []
    #   content {
    #     image_id_override = var.image_id_override
    #     image_type        = var.image_type
    #   }
    # }
    # placement_group     = var.placement_group
    # spot_iam_fleet_role = var.spot_iam_fleet_role
  }
  # service_role             = TODO
  # dynamic "update_policy" {
  #   for_each = local.include_update_policy ? [1] : []
  #   content {
  #     job_execution_timeout_minutes = var.job_execution_timeout_minutes # 60
  #     terminate_jobs_on_update      = var.terminate_jobs_on_update      # false
  #   }
  # }
}

resource "aws_batch_job_queue" "this" {
  count    = local.enabled ? 1 : 0
  name     = module.batch_label.id
  priority = 1
  state    = "ENABLED"
  # scheduling_policy_arn = TODO
  compute_environment_order {
    order               = 1
    compute_environment = aws_batch_compute_environment.this[0].arn
  }
  tags = module.batch_label.tags
}

resource "aws_batch_job_definition" "this" {
  count                      = local.enabled ? 1 : 0
  name                       = module.batch_label.id
  type                       = "container"
  tags                       = module.batch_label.tags
  parameters                 = var.batch_job_parameters
  deregister_on_new_revision = var.batch_job_deregister_on_new_revision
  ecs_properties = jsonencode({
    taskProperties = [
      merge(
        {
          containers           = jsondecode(var.container_definition_json),
          enableExecuteCommand = var.exec_enabled
          executionRoleArn     = length(local.task_exec_role_arn) > 0 ? local.task_exec_role_arn : one(aws_iam_role.ecs_exec[*]["arn"])
          networkConfiguration = {
            assignPublicIp = tostring(var.assign_public_ip)
          }
          taskRoleArn = length(local.task_role_arn) > 0 ? local.task_role_arn : one(aws_iam_role.ecs_task[*]["arn"])
          volumes = [for v in local.volumes :
            merge(
              { name = v.name },
              lookup(v, "host_path", null) != null ? { host = { sourcePath = v.host_path } } : {},
              lookup(v, "efs_volume_configuration", null) != null ? {
                efsVolumeConfiguration = merge(
                  {
                    fileSystemId          = v.efs_volume_configuration.file_system_id
                    rootDirectory         = v.efs_volume_configuration.root_directory
                    transitEncryption     = v.efs_volume_configuration.transit_encryption
                    transitEncryptionPort = v.efs_volume_configuration.transit_encryption_port
                  },
                  lookup(v.efs_volume_configuration, "authorization_config", null) != null ? {
                    authorizationConfig = {
                      accessPointId = v.efs_volume_configuration.authorization_config.access_point_id
                      iam           = v.efs_volume_configuration.authorization_config.iam
                    }
                  } : {}
                )
              } : {}
            )
          ]
        },
        local.use_fargate ? merge(
          { platformVersion = var.platform_version },
          var.ephemeral_storage_size > 0 ? { ephemeralStorage = { sizeInGiB = var.ephemeral_storage_size } } : {},
        ) : {},
        var.pid_mode != null ? { pidMode = var.pid_mode } : {},
        var.ipc_mode != null ? { ipcMode = var.ipc_mode } : {},
        var.runtime_platform != null ? { runtimePlatform = var.runtime_platform } : {},
      )
    ]
  })
}

module "batch_label" {
  source     = "cloudposse/label/null"
  version    = "~> 0.25.0"
  context    = module.this.context
  attributes = ["batch"]
}

module "task_label" {
  source     = "cloudposse/label/null"
  version    = "0.25.0"
  enabled    = local.create_task_role
  attributes = ["task"]

  context = module.this.context
}

module "exec_label" {
  source     = "cloudposse/label/null"
  version    = "0.25.0"
  enabled    = local.create_exec_role
  attributes = ["exec"]

  context = module.this.context
}

data "aws_iam_policy_document" "ecs_task" {
  count = local.create_task_role ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_task" {
  count = local.create_task_role ? 1 : 0

  name                 = module.task_label.id
  assume_role_policy   = one(data.aws_iam_policy_document.ecs_task[*]["json"])
  permissions_boundary = var.permissions_boundary == "" ? null : var.permissions_boundary
  tags                 = var.role_tags_enabled ? module.task_label.tags : null
}

resource "aws_iam_role_policy_attachment" "ecs_task" {
  for_each   = local.create_task_role ? local.task_policy_arns_map : {}
  policy_arn = each.value
  role       = one(aws_iam_role.ecs_task[*]["id"])
}

resource "aws_iam_role_policy" "ecs_ssm_exec" {
  count  = local.create_task_role && var.exec_enabled ? 1 : 0
  name   = module.task_label.id
  policy = one(data.aws_iam_policy_document.ecs_ssm_exec[*]["json"])
  role   = one(aws_iam_role.ecs_task[*]["id"])
}

# IAM role that the Amazon ECS container agent and the Docker daemon can assume
data "aws_iam_policy_document" "ecs_task_exec" {
  count = local.create_exec_role ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_exec" {
  count                = local.create_exec_role ? 1 : 0
  name                 = module.exec_label.id
  assume_role_policy   = one(data.aws_iam_policy_document.ecs_task_exec[*]["json"])
  permissions_boundary = var.permissions_boundary == "" ? null : var.permissions_boundary
  tags                 = var.role_tags_enabled ? module.exec_label.tags : null
}

data "aws_iam_policy_document" "ecs_exec" {
  count = local.create_exec_role ? 1 : 0

  statement {
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "ssm:GetParameters",
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
  }
}

resource "aws_iam_role_policy" "ecs_exec" {
  for_each = local.create_exec_role ? toset(["true"]) : toset([])
  name     = module.exec_label.id
  policy   = one(data.aws_iam_policy_document.ecs_exec[*]["json"])
  role     = one(aws_iam_role.ecs_exec[*]["id"])
}

resource "aws_iam_role_policy_attachment" "ecs_exec" {
  for_each   = local.create_exec_role ? local.task_exec_policy_arns_map : {}
  policy_arn = each.value
  role       = one(aws_iam_role.ecs_exec[*]["id"])
}

data "aws_iam_policy_document" "ecs_ssm_exec" {
  count = local.create_task_role && var.exec_enabled ? 1 : 0

  statement {
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel"
    ]
  }
}
# Service
## Security Groups
resource "aws_security_group" "batch" {
  count       = local.create_security_group ? 1 : 0
  vpc_id      = var.vpc_id
  name        = module.batch_label.id
  description = var.security_group_description
  tags        = module.batch_label.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "allow_all_egress" {
  count             = local.create_security_group && var.enable_all_egress_rule ? 1 : 0
  description       = "Allow all outbound traffic to any IPv4 address"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.batch[0].id
}

resource "aws_security_group_rule" "allow_icmp_ingress" {
  count             = local.create_security_group && var.enable_icmp_rule ? 1 : 0
  description       = "Allow ping command from anywhere, see https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/security-group-rules-reference.html#sg-rules-ping"
  type              = "ingress"
  from_port         = 8
  to_port           = 0
  protocol          = "icmp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.batch[0].id
}
