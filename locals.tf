locals {
  name = "${var.name}-alb-${var.environment}"
  listener_rules = flatten([
    for listener_key, listener in var.listeners : [
      for rule in lookup(listener, "rules", []) : {
        listener_key     = listener_key
        listener_arn     = aws_lb_listener.this[listener_key].arn
        path_pattern     = rule.path_pattern
        priority         = rule.priority
        target_group_key = rule.target_group_key
      }
    ]
  ])

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}