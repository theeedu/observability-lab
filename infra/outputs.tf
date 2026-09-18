output "network_name" {
  description = "Nome da rede Docker provisionada."
  value       = docker_network.obs.name
}

output "network_id" {
  description = "ID da rede Docker provisionada."
  value       = docker_network.obs.id
}

output "volumes" {
  description = "Volumes persistentes provisionados."
  value       = [for v in docker_volume.state : v.name]
}
