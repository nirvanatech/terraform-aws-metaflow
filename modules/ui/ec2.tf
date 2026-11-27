resource "aws_security_group" "fargate_security_group" {
  name        = local.ui_backend_security_group_name
  description = "Security Group for Fargate which runs the UI Backend."
  vpc_id      = var.metaflow_vpc_id

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = -1
    security_groups = [aws_security_group.ui_lb_security_group.id]
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    self        = true
    description = "Internal communication"
  }

  # egress to anywhere
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # all
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all external communication"
  }

  tags = merge(
    var.standard_tags,
    {
      Metaflow = "true"
    }
  )
}

resource "aws_security_group" "ui_lb_security_group" {
  name        = local.alb_security_group_name
  description = "Security Group for ALB"
  vpc_id      = var.metaflow_vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.ui_allow_list
    description = "Allow public HTTPS"
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    self        = true
    description = "Internal communication"
  }

  # egress to anywhere
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # all
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all external communication"
  }

  tags = merge(
    var.standard_tags,
    {
      Metaflow = "true"
    }
  )
}

resource "aws_lb" "this" {
  name               = "${var.resource_prefix}alb${var.resource_suffix}"
  internal           = var.alb_internal
  load_balancer_type = "application"
  subnets            = [var.subnet1_id, var.subnet2_id]
  security_groups = [
    aws_security_group.ui_lb_security_group.id
  ]

  tags = var.standard_tags
}

resource "aws_lb_target_group" "ui_backend" {
  name        = format("%.32s", "${var.resource_prefix}ui-backend${var.resource_suffix}")
  port        = 8083
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.metaflow_vpc_id

  health_check {
    protocol            = "HTTP"
    port                = 8083
    path                = "/api/ping"
    interval            = 10
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = var.standard_tags
}

resource "aws_lb_target_group" "ui_static" {
  name        = format("%.32s", "${var.resource_prefix}ui-static${var.resource_suffix}")
  port        = 3000
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.metaflow_vpc_id
  tags        = var.standard_tags
}


resource "aws_lb_listener" "this" {
  load_balancer_arn = aws_lb.this.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"

  certificate_arn = var.certificate_arn

  dynamic "default_action" {
    for_each = (var.cognito_user_pool_arn != "" && !local.ui_source_ip_gated) ? [""] : []
    content {
      type = "authenticate-cognito"

      authenticate_cognito {
        on_unauthenticated_request = "authenticate"
        scope                      = "openid"
        user_pool_arn              = var.cognito_user_pool_arn
        user_pool_client_id        = var.cognito_user_pool_client_id
        user_pool_domain           = var.cognito_user_pool_domain
      }
    }
  }

  dynamic "default_action" {
    for_each = local.ui_source_ip_gated ? [] : [""]
    content {
      type             = "forward"
      target_group_arn = aws_lb_target_group.ui_static.id
      order            = 100
    }
  }

  dynamic "default_action" {
    for_each = local.ui_source_ip_gated ? [""] : []
    content {
      type = "fixed-response"

      fixed_response {
        content_type = "text/plain"
        message_body = "Forbidden"
        status_code  = "403"
      }
    }
  }
}

resource "aws_lb_listener_rule" "ui_backend" {
  listener_arn = aws_lb_listener.this.arn
  priority     = 1

  dynamic "action" {
    for_each = (var.cognito_user_pool_arn != "") ? [""] : []
    content {
      type = "authenticate-cognito"

      authenticate_cognito {
        on_unauthenticated_request = "authenticate"
        scope                      = "openid"

        user_pool_arn       = var.cognito_user_pool_arn
        user_pool_client_id = var.cognito_user_pool_client_id
        user_pool_domain    = var.cognito_user_pool_domain
      }
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ui_backend.arn
  }

  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }

  dynamic "condition" {
    for_each = local.ui_source_ip_gated ? [""] : []
    content {
      source_ip {
        values = var.ui_source_ip_allow_list
      }
    }
  }
}

# Only created when source-IP gating is on: the listener default action is then
# a 403, so the static frontend needs its own rule.
resource "aws_lb_listener_rule" "ui_static" {
  count = local.ui_source_ip_gated ? 1 : 0

  listener_arn = aws_lb_listener.this.arn
  priority     = 2

  dynamic "action" {
    for_each = (var.cognito_user_pool_arn != "") ? [""] : []
    content {
      type = "authenticate-cognito"

      authenticate_cognito {
        on_unauthenticated_request = "authenticate"
        scope                      = "openid"

        user_pool_arn       = var.cognito_user_pool_arn
        user_pool_client_id = var.cognito_user_pool_client_id
        user_pool_domain    = var.cognito_user_pool_domain
      }
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ui_static.arn
  }

  condition {
    source_ip {
      values = var.ui_source_ip_allow_list
    }
  }
}
