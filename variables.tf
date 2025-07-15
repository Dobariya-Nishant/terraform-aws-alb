# =============================
# 🧱 Core Project Configuration
# =============================

variable "project_name" {
  description = "Name of the overall project. Used for consistent naming and tagging across all resources."
  type        = string
}

variable "name" {
  description = "Base name used as an identifier for all resources (e.g., key name, launch template name, etc.)."
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g., dev, staging, prod). Used for tagging and naming consistency."
  type        = string
}

# =============
# 🌐 Networking
# =============

variable "vpc_id" {
  description = "The VPC ID where resources like EC2, ALB, and security groups will be deployed."
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs to launch the ALB and associated resources into. Typically across multiple AZs."
  type        = list(string)
}

# =======================
# 🔐 Security Group Rules
# =======================

variable "enable_public_https" {
  description = "Enable ingress on port 443 (HTTPS) from the public internet."
  type        = bool
  default     = false
}

variable "enable_public_http" {
  description = "Enable ingress on port 80 (HTTP) from the public internet."
  type        = bool
  default     = false
}

# =========================
# ⚖️ Load Balancer Settings
# =========================

variable "enable_cross_zone_load_balancing" {
  description = "Enables/disables cross-zone load balancing on the ALB to distribute traffic evenly across AZs."
  type        = bool
  default     = false
}

variable "internal" {
  description = "Determines if the ALB is internal (private) or internet-facing (public). Set to true for internal."
  type        = bool
  default     = true
}

# ==============================
# 🎯 Target Group Configurations
# ==============================

variable "target_groups" {
  description = <<-EOT
    Map of target group definitions. Each entry configures how traffic is forwarded 
    to the backend resources (EC2, IPs, or Lambda). Includes optional health checks, 
    deregistration behavior, and client IP preservation.
  EOT

  type = map(object({
    name                          = optional(string) # Custom name (optional)
    target_type                   = optional(string) # instance | ip | lambda
    port                          = number           # Port ALB forwards traffic to
    protocol                      = string           # HTTP | HTTPS
    connection_termination        = optional(bool)   # Whether to close connection after response
    preserve_client_ip            = optional(string) # Preserve source IP (valid for NLB only)
    deregistration_delay          = optional(string) # Delay before deregistering targets
    load_balancing_algorithm_type = optional(string) # round_robin or least_outstanding_requests

    health_check = optional(object({
      enabled             = bool             # Whether to enable health check
      port                = number           # Port to use for health checks
      path                = optional(string) # Endpoint path (e.g., /health)
      interval            = optional(number) # Interval in seconds
      healthy_threshold   = optional(number) # Required successes to mark healthy
      unhealthy_threshold = optional(number) # Required failures to mark unhealthy
      timeout             = optional(number) # Timeout in seconds for health check
    }))
  }))
}

# ==========================
# 🎧 Listener + Rule Configs
# ==========================

variable "listeners" {
  description = <<-EOT
    Map of ALB listener configurations. Each listener defines protocol/port + 
    forwarding behavior to a target group. Also includes optional HTTPS cert ARN 
    and path-based routing rules.
  EOT

  type = map(object({
    port            = number           # Listener port (usually 80 or 443)
    target_type     = optional(string) # instance | ip | lambda (inherits from target group)
    protocol        = string           # HTTP | HTTPS
    certificate_arn = optional(string) # Required for HTTPS
    forward = object({
      target_group_key = string # Reference to the default target group
    })
    rules = list(object({
      path_pattern     = list(string) # Path matchers (e.g., /api/*)
      priority         = number       # Priority of the rule (unique per listener)
      target_group_key = string       # Target group key to forward to on match
    }))
  }))
}
