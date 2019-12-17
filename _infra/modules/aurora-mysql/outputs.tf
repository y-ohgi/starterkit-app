output "endpoint" {
  description = "Aurora MySQLのエンドポイント"
  value       = aws_rds_cluster.this.endpoint
}

