# ===================================
# 🏗️  Application Load Balancer (ALB)
# ===================================

resource "aws_lb" "this" {
  name               = local.name
  internal           = !var.internal                # Controls if the ALB is public or internal
  load_balancer_type = "application"                # ALB operates at Layer 7 (HTTP/HTTPS)
  security_groups    = [aws_security_group.this.id] # Attach associated security group
  subnets            = var.subnet_ids               # Deploy ALB across specified subnets

  enable_cross_zone_load_balancing = var.enable_cross_zone_load_balancing

  tags = merge(
    local.common_tags,
    {
      Name = local.name
    }
  )
}

# ====================================
# 🎯 Target Groups (for ALB Listeners)
# ====================================

resource "aws_lb_target_group" "this" {
  for_each = var.target_groups

  name                          = lookup(each.value, "name", "${local.name}-tg-${each.key}")
  port                          = each.value.port
  protocol                      = each.value.protocol # Only HTTP or HTTPS for ALB
  vpc_id                        = var.vpc_id
  target_type                   = each.value.target_type # instance, ip, or lambda
  load_balancing_algorithm_type = each.value.load_balancing_algorithm_type

  # Optional attributes
  connection_termination = lookup(each.value, "connection_termination", null)
  preserve_client_ip     = lookup(each.value, "preserve_client_ip", null)
  deregistration_delay   = lookup(each.value, "deregistration_delay", null)

  # Optional health check block
  dynamic "health_check" {
    for_each = lookup(each.value, "health_check", {}) != {} ? [1] : []
    content {
      enabled             = each.value.health_check.enabled
      interval            = each.value.health_check.interval
      path                = each.value.health_check.path
      port                = each.value.health_check.port
      healthy_threshold   = each.value.health_check.healthy_threshold
      unhealthy_threshold = each.value.health_check.unhealthy_threshold
      timeout             = each.value.health_check.timeout
    }
  }

  tags = merge(
    local.common_tags,
    {
      Name = lookup(each.value, "name", "${local.name}-tg-${each.key}")
    }
  )
}

# ==========================================
# 📜 ALB Listener Rules (Path-based Routing)
# ==========================================

resource "aws_lb_listener_rule" "this" {
  for_each = {
    for idx, rule in local.listener_rules : "${rule.listener_key}-${rule.priority}" => rule
  }

  listener_arn = each.value.listener_arn
  priority     = each.value.priority

  # Forward requests to matching target group
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this[each.value.target_group_key].arn
  }

  # Match based on path pattern
  condition {
    path_pattern {
      values = each.value.path_pattern
    }
  }
}

# ================================
# 🎧 ALB Listeners (Port 80 / 443)
# ================================

resource "aws_lb_listener" "this" {
  for_each = var.listeners

  load_balancer_arn = aws_lb.this.arn
  port              = each.value.port     # Usually 80 or 443
  protocol          = each.value.protocol # HTTP or HTTPS

  # Optional for HTTPS
  certificate_arn = lookup(each.value, "certificate_arn", null)

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this[each.value.forward.target_group_key].arn
  }

  tags = merge(
    local.common_tags,
    {
      Name = each.key
    }
  )
}

# =========================
# 🔐 Security Group for ALB
# =========================

resource "aws_security_group" "this" {
  name   = local.name
  vpc_id = var.vpc_id

  tags = merge(
    local.common_tags,
    {
      Name = local.name
    }
  )
}

# ========================================
# 🌐 Ingress Rules for ALB (Public Access)
# ========================================

# Allow HTTP (port 80) from anywhere — optional
resource "aws_security_group_rule" "public_http" {
  count = var.enable_public_http ? 1 : 0

  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow HTTP"
  security_group_id = aws_security_group.this.id
}

# Allow HTTPS (port 443) from anywhere — optional
resource "aws_security_group_rule" "public_https" {
  count = var.enable_public_https ? 1 : 0

  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow HTTPS"
  security_group_id = aws_security_group.this.id
}

# ======================
# 📤 Egress Rule for ALB
# ======================

# Allow all outbound traffic
resource "aws_security_group_rule" "egress" {
  description       = "Allow all outbound traffic"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.this.id
}
