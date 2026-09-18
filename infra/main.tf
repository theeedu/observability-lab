# =========================================================================== #
# Infraestrutura do Observability Lab modelada como código (Terraform).
#
# Demonstra IaC de forma 100% local, sem nuvem: provisiona a rede e os volumes
# persistentes do lab usando o provider Docker. A orquestração dos containers
# em si é feita pelo Docker Compose — aqui mostramos a camada de infraestrutura
# declarativa (rede + estado persistente), separando responsabilidades.
# =========================================================================== #

# Rede dedicada do lab
resource "docker_network" "obs" {
  name   = "${var.project_name}-net"
  driver = var.network_driver
}

# Volumes persistentes para os serviços com estado (Prometheus, Grafana, Loki)
resource "docker_volume" "state" {
  for_each = toset(var.persistent_volumes)
  name     = "${var.project_name}-${each.value}"

  lifecycle {
    prevent_destroy = false
  }
}
