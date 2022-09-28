resource "aws_backup_plan" "rds_cont_backup" {
  name = "metaflow_rds_cont_backup_plan"

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
  name = "metaflow_rds_cont_backup_vault"
}

resource "aws_backup_selection" "rds_cont_backup" {
  iam_role_arn = aws_iam_role.rds_cont_backup.arn
  name         = "metaflow_rds_cont_backup_selection"
  plan_id      = aws_backup_plan.rds_cont_backup.id

  resources = [ aws_db_instance.this[0].arn ]
}

resource "aws_iam_role" "rds_cont_backup" {
  name               = "metaflow-rds-cont-backup-role"
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
