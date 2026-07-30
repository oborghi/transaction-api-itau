# ==========================================
# Service Discovery (Cloud Map)
# Usa Service Connect do ECS (proxy sidecar)
# Resolve DNS sem depender de Route 53 Resolver
# ==========================================

resource "aws_service_discovery_private_dns_namespace" "main" {
  name        = "${var.app_name}.internal"
  description = "Private DNS namespace for ${var.app_name} services (Service Connect)"
  vpc         = aws_vpc.main.id
}

resource "aws_service_discovery_service" "mongodb" {
  name = "mongodb"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}