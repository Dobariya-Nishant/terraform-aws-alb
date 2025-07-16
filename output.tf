output "id" {
  description = "ID of the load balancer"
  value       = aws_lb.this.id
}

output "sg_id" {
  description = "Security group ID attached to the load balancer"
  value       = aws_security_group.this.id
}

output "target_groups" {
  description = "ID of the load balancer"
  value       = aws_lb_target_group.this
}