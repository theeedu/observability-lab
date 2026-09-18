variable "project_name" {
  description = "Prefixo/nome do projeto, usado para nomear recursos."
  type        = string
  default     = "observability-lab"
}

variable "network_driver" {
  description = "Driver da rede Docker."
  type        = string
  default     = "bridge"
}

variable "persistent_volumes" {
  description = "Volumes persistentes provisionados para os serviços de estado."
  type        = list(string)
  default     = ["prometheus-data", "grafana-data", "loki-data"]
}
