resource "aws_backup_plan" "rds_cont_backup" {
  name = "${var.resource_prefix}rds_cont_backup_plan${var.resource_suffix}"

  rule {
    rule_name                = "metaflow_rds_cont_backup_rule"
    target_vault_name        = aws_backup_vault.rds_cont_backup.name
    schedule                 = "cron(0 * ? * * *)"
    enable_continuous_backup = true
    lifecycle {
      delete_after = 30
    }
  }
}

resource "aws_backup_vault" "rds_cont_backup" {
  name = "${var.resource_prefix}rds_cont_backup_vault${var.resource_suffix}"
}

resource "aws_backup_selection" "rds_cont_backup" {
  iam_role_arn = aws_iam_role.rds_cont_backup.arn
  name         = "${var.resource_prefix}rds_cont_backup_selection${var.resource_suffix}"
  plan_id      = aws_backup_plan.rds_cont_backup.id

  resources = [aws_db_instance.this[0].arn]
}

resource "aws_iam_role" "rds_cont_backup" {
  name               = "${var.resource_prefix}rds-cont-backup-role${var.resource_suffix}"
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": ["sts:AssumeRole"],
      "Effect": "allow",
      "Principal": {
        "Service": ["backup.amazonaws.com"]
      }
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "rds_cont_backup" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
  role       = aws_iam_role.rds_cont_backup.name
}
