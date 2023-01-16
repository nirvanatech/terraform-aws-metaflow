/*
 A subnet is attached to an availability zone so for db redundancy and
 performance we need to define additional subnet(s) and aws_db_subnet_group
 is how we define this.
*/
resource "aws_db_subnet_group" "this" {
  name       = local.pg_subnet_group_name
  subnet_ids = [var.subnet1_id, var.subnet2_id]

  tags = merge(
    var.standard_tags,
    {
      Name     = local.pg_subnet_group_name
      Metaflow = "true"
    }
  )
}

/*
 Define a new firewall for our database instance.
*/
resource "aws_security_group" "rds_security_group" {
  name   = local.rds_security_group_name
  vpc_id = var.metaflow_vpc_id

  tags = var.standard_tags
}

# ingress only from port 5432
resource "aws_security_group_rule" "rds_sg_ingress" {
  type = "ingress"
  from_port = 5432
  to_port = 5432
  protocol = "tcp"
  source_security_group_id = var.metadata_service_security_group_id
  security_group_id = aws_security_group.rds_security_group.id
}

# egress to anywhere
resource "aws_security_group_rule" "rds_sg_egress" {
  type = "egress"
  from_port = 0
  to_port = 0
  protocol = "-1"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = aws_security_group.rds_security_group.id
}

resource "random_password" "this" {
  length  = 64
  special = true
  # redefines the `special` variable by removing the `@`
  # this documentation https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_Limits.html
  # shows that the `/`, `"`, `@` and ` ` cannot be used in the password
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "random_pet" "final_snapshot_id" {}

locals {
  use_aurora = length(regexall("^aurora-", var.db_engine)) > 0
}

resource "aws_rds_cluster" "this" {
  count              = local.use_aurora ? 1 : 0
  cluster_identifier = "${var.resource_prefix}${var.db_name}${var.resource_suffix}"
  kms_key_id         = aws_kms_key.rds.arn
  engine             = var.db_engine

  database_name        = var.db_name
  master_username      = var.db_username
  master_password      = random_password.this.result
  db_subnet_group_name = aws_db_subnet_group.this.id

  engine_version    = var.db_engine_version
  storage_encrypted = true

  final_snapshot_identifier = "${var.resource_prefix}${var.db_name}-final-snapshot${var.resource_suffix}-${random_pet.final_snapshot_id.id}" # Snapshot upon delete
  vpc_security_group_ids    = [aws_security_group.rds_security_group.id]

  tags = merge(
    var.standard_tags,
    {
      Name     = "${var.resource_prefix}${var.db_name}${var.resource_suffix}"
      Metaflow = "true"
    }
  )
}

resource "aws_rds_cluster_instance" "cluster_instances" {
  count              = local.use_aurora ? 1 : 0
  identifier         = "${var.resource_prefix}${var.db_name}${var.resource_suffix}-${count.index}"
  cluster_identifier = aws_rds_cluster.this[0].id
  instance_class     = var.db_instance_type
  engine             = aws_rds_cluster.this[0].engine
  engine_version     = aws_rds_cluster.this[0].engine_version
}

resource "aws_db_parameter_group" "db_metaflow" {
  name   = "${var.resource_prefix}${var.db_name}-parameters${var.resource_suffix}"
  family = "${var.db_engine}${var.db_engine_version}"

  # long-tail query logging for queries taking > 100 ms
  parameter {
    name  = "log_min_duration_statement"
    value = "100"
  }
}

/*
 Define rds db instance.
*/
resource "aws_db_instance" "this" {
  count                     = local.use_aurora ? 0 : 1
  publicly_accessible       = false
  allocated_storage         = 20    # Allocate 20GB
  storage_type              = "gp2" # general purpose SSD
  storage_encrypted         = true
  kms_key_id                = aws_kms_key.rds.arn
  engine                    = var.db_engine
  engine_version            = var.db_engine_version
  instance_class            = var.db_instance_type                                         # Hardware configuration
  identifier                = "${var.resource_prefix}${var.db_name}${var.resource_suffix}" # used for dns hostname needs to be customer unique in region
  name                      = var.db_name                                                  # unique id for CLI commands (name of DB table which is why we're not adding the prefix as no conflicts will occur and the API expects this table name)
  username                  = var.db_username
  password                  = random_password.this.result
  db_subnet_group_name      = aws_db_subnet_group.this.id
  max_allocated_storage     = 1000                                                                                                           # Upper limit of automatic scaled storage
  multi_az                  = true                                                                                                           # Multiple availability zone?
  final_snapshot_identifier = "${var.resource_prefix}${var.db_name}-final-snapshot${var.resource_suffix}-${random_pet.final_snapshot_id.id}" # Snapshot upon delete
  vpc_security_group_ids    = [aws_security_group.rds_security_group.id]

  # enable performance insights for debugging performance issues
  # note: only certain values are allowed for retention_period (check docs),
  # using retention period > 7 days will put us beyond the free tier.
  performance_insights_enabled          = true
  performance_insights_retention_period = 7
  # enable long tail query logging and export logs to CW so that they are not
  # deleted on expiry.
  parameter_group_name            = aws_db_parameter_group.db_metaflow.name
  enabled_cloudwatch_logs_exports = ["postgresql"]

  tags = merge(
    var.standard_tags,
    {
      Name     = "${var.resource_prefix}${var.db_name}${var.resource_suffix}"
      Metaflow = "true"
    }
  )
}
