output "alb_dns_name" {
  description = "Public DNS name of the load balancer"
  value       = aws_lb.main.dns_name
}

output "vpc_id" {
  value = aws_vpc.main.id
}

output "rds_endpoint" {
  description = "RDS connection endpoint"
  value       = aws_db_instance.main.address
  sensitive   = true
}
