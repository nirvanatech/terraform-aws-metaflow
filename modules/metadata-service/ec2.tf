moved {
  from = aws_lb.alb[0]
  to   = aws_lb.alb
}

moved {
  from = aws_lb_target_group.alb_main[0]
  to   = aws_lb_target_group.alb_main
}

moved {
  from = aws_lb_target_group.alb_db_migrate[0]
  to   = aws_lb_target_group.alb_db_migrate
}

moved {
  from = aws_lb_listener.alb_main[0]
  to   = aws_lb_listener.alb_main
}

moved {
  from = aws_lb_listener.alb_db_migrate[0]
  to   = aws_lb_listener.alb_db_migrate
}

moved {
  from = aws_lb.apigw_nlb[0]
  to   = aws_lb.apigw_nlb
}

moved {
  from = aws_lb_target_group.apigw_metadata[0]
  to   = aws_lb_target_group.apigw_metadata
}

moved {
  from = aws_lb_target_group.apigw_db_migrate[0]
  to   = aws_lb_target_group.apigw_db_migrate
}

moved {
  from = aws_lb_listener.apigw_metadata[0]
  to   = aws_lb_listener.apigw_metadata
}

moved {
  from = aws_lb_listener.apigw_db_migrate[0]
  to   = aws_lb_listener.apigw_db_migrate
}

moved {
  from = aws_security_group.metadata_alb_security_group[0]
  to   = aws_security_group.metadata_alb_security_group
}

resource "aws_security_group" "metadata_service_security_group" {
  name        = local.metadata_service_security_group_name
  description = "Security Group for Fargate which runs the Metadata Service."
  vpc_id      = var.metaflow_vpc_id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = var.vpc_cidr_blocks
    description = "Allow API calls internally"
  }

  ingress {
    from_port   = 8082
    to_port     = 8082
    protocol    = "tcp"
    cidr_blocks = var.vpc_cidr_blocks
    description = "Allow API calls internally"
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

resource "aws_security_group" "metadata_alb_security_group" {
  name        = local.metadata_alb_security_group_name
  description = "Security Group for ALB which fronts the Metadata Service."
  vpc_id      = var.metaflow_vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.vpc_cidr_blocks
    description = "Allow API calls internally"
  }

  ingress {
    from_port   = 8082
    to_port     = 8082
    protocol    = "tcp"
    cidr_blocks = var.vpc_cidr_blocks
    description = "Allow API calls internally"
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

# Inject a ingress rule to RDS's sg to allow ingress only from port 5432
resource "aws_security_group_rule" "rds_sg_ingress" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.metadata_service_security_group.id
  security_group_id        = var.database_sg_id
}

resource "aws_lb" "alb" {
  name               = "${var.resource_prefix}metadata-alb${var.resource_suffix}"
  internal           = true
  load_balancer_type = "application"
  idle_timeout       = 180 # 3 minutes
  subnets            = [var.subnet1_id, var.subnet2_id]
  security_groups    = [aws_security_group.metadata_alb_security_group[0].id]

  tags = var.standard_tags
}

resource "aws_lb_target_group" "alb_main" {
  name                          = "${var.resource_prefix}alb-mdtg${var.resource_suffix}"
  port                          = 8080
  protocol                      = "HTTP"
  load_balancing_algorithm_type = "least_outstanding_requests"
  target_type                   = "ip"
  vpc_id                        = var.metaflow_vpc_id

  health_check {
    protocol = "HTTP"
    matcher  = "200,202"
    timeout  = 10
    path     = "/healthcheck"
  }

  tags = var.standard_tags

  depends_on = [aws_lb.alb]
}


resource "aws_lb_target_group" "alb_db_migrate" {
  name        = "${var.resource_prefix}alb-dbtg${var.resource_suffix}"
  port        = 8082
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.metaflow_vpc_id

  health_check {
    protocol = "HTTP"
    port     = 8080
    matcher  = "200,202"
    timeout  = 10
    path     = "/healthcheck"
  }

  tags = var.standard_tags

  depends_on = [aws_lb.alb]
}

resource "aws_lb_listener" "alb_main" {
  load_balancer_arn = aws_lb.alb[0].arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_main[0].arn
  }
}

resource "aws_lb_listener" "alb_db_migrate" {
  load_balancer_arn = aws_lb.alb[0].arn
  port              = "8082"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_db_migrate[0].arn
  }
}

resource "aws_lb" "apigw_nlb" {
  name               = "${var.resource_prefix}apigw-nlb${var.resource_suffix}"
  internal           = true
  load_balancer_type = "network"
  subnets            = [var.subnet1_id, var.subnet2_id]

  tags = var.standard_tags
}

resource "aws_lb_target_group" "apigw_metadata" {
  name        = "${var.resource_prefix}apigw-mdtg${var.resource_suffix}"
  port        = 80
  protocol    = "TCP"
  target_type = "alb"
  vpc_id      = var.metaflow_vpc_id

  health_check {
    protocol = "HTTP"
    matcher  = "200,202"
    timeout  = 10
    path     = "/healthcheck"
  }

  tags = var.standard_tags
}

resource "aws_lb_target_group_attachment" "apigw_metadata" {
  target_group_arn = aws_lb_target_group.apigw_metadata[0].arn
  target_id        = aws_lb.alb[0].arn
}

resource "aws_lb_target_group" "apigw_db_migrate" {
  name        = "${var.resource_prefix}apigw-dbtg${var.resource_suffix}"
  port        = 8082
  protocol    = "TCP"
  target_type = "alb"
  vpc_id      = var.metaflow_vpc_id

  health_check {
    protocol = "HTTP"
    port     = 80
    matcher  = "200,202"
    timeout  = 10
    path     = "/healthcheck"
  }

  tags = var.standard_tags
}

resource "aws_lb_target_group_attachment" "apigw_db_migrate" {
  target_group_arn = aws_lb_target_group.apigw_db_migrate[0].arn
  target_id        = aws_lb.alb[0].arn
}

resource "aws_lb_listener" "apigw_metadata" {
  load_balancer_arn = aws_lb.apigw_nlb[0].arn
  port              = "80"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.apigw_metadata[0].arn
  }
}

resource "aws_lb_listener" "apigw_db_migrate" {
  load_balancer_arn = aws_lb.apigw_nlb[0].arn
  port              = "8082"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.apigw_db_migrate[0].arn
  }
}
