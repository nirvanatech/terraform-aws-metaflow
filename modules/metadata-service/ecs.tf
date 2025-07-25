resource "aws_ecs_cluster" "this" {
  name = local.ecs_cluster_name

  tags = merge(
    var.standard_tags,
    {
      Name     = local.ecs_cluster_name
      Metaflow = "true"
    }
  )
}

resource "aws_ecs_task_definition" "this" {
  family = "${var.resource_prefix}service${var.resource_suffix}" # Unique name for task definition

  container_definitions = <<EOF
[
  {
    "name": "${var.resource_prefix}service${var.resource_suffix}",
    "image": "${var.metadata_service_container_image}",
    "essential": true,
    "cpu": ${var.metadata_service_cpu},
    "memory": ${var.metadata_service_memory},
    "portMappings": [
      {
        "containerPort": 8080,
        "hostPort": 8080
      },
      {
        "containerPort": 8082,
        "hostPort": 8082
      }
    ],
    "environment": [
      {"name": "MF_METADATA_DB_POOL_MAX", "value": "${var.database_aio_pool_max}"},
      {"name": "MF_METADATA_DB_TIMEOUT", "value": "${var.database_aio_timeout}"},
      {"name": "MF_METADATA_DB_HOST", "value": "${replace(var.rds_master_instance_endpoint, ":5432", "")}"},
      {"name": "MF_METADATA_DB_NAME", "value": "${var.database_name}"},
      {"name": "MF_METADATA_DB_PORT", "value": "5432"},
      {"name": "MF_METADATA_DB_PSWD", "value": "${var.database_password}"},
      {"name": "MF_METADATA_DB_USER", "value": "${var.database_username}"}
    ],
    "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
            "awslogs-group": "${aws_cloudwatch_log_group.this.name}",
            "awslogs-region": "${data.aws_region.current.name}",
            "awslogs-stream-prefix": "metadata"
        }
    }
  }
]
EOF

  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  task_role_arn            = aws_iam_role.metadata_svc_ecs_task_role.arn
  execution_role_arn       = var.fargate_execution_role_arn
  cpu                      = var.metadata_service_cpu
  memory                   = var.metadata_service_memory

  tags = merge(
    var.standard_tags,
    {
      Metaflow = "true"
    }
  )
}

locals {
  alb_ports         = [8080, 8082]
  alb_target_groups = [aws_lb_target_group.alb_main.arn, aws_lb_target_group.alb_db_migrate.arn]
}

resource "aws_ecs_service" "this" {
  name            = "${var.resource_prefix}metadata-service${var.resource_suffix}"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    security_groups  = [aws_security_group.metadata_service_security_group.id]
    assign_public_ip = var.with_public_ip
    subnets          = [var.subnet1_id, var.subnet2_id]
  }

  dynamic "load_balancer" {
    for_each = local.alb_ports
    content {
      target_group_arn = local.alb_target_groups[load_balancer.key]
      container_name   = "${var.resource_prefix}service${var.resource_suffix}"
      container_port   = load_balancer.value
    }
  }

  lifecycle {
    ignore_changes = [desired_count]
  }

  tags           = var.standard_tags
  propagate_tags = "TASK_DEFINITION"
}
