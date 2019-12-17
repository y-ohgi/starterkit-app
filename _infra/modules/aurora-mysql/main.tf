resource "aws_db_subnet_group" "this" {
  name       = var.name
  tags       = var.tags
  subnet_ids = var.subnets
}

resource "aws_rds_cluster" "this" {
  cluster_identifier = var.name

  # MEMO: 本番で使用する場合は"true"に変更して削除保護を有効にすることを推奨します
  deletion_protection = "false"
  engine              = "aurora"
  engine_mode         = "serverless"
  engine_version      = "5.6.10a"

  vpc_security_group_ids = var.security_groups
  db_subnet_group_name   = aws_db_subnet_group.this.id

  database_name   = var.database_name
  master_username = var.master_username
  master_password = var.master_password

  final_snapshot_identifier = var.name
  skip_final_snapshot       = false

  scaling_configuration {
    auto_pause               = true
    max_capacity             = 16
    min_capacity             = 1
    seconds_until_auto_pause = 300
    timeout_action           = "RollbackCapacityChange"
  }
}
