output "grafana_url" {
  value = "http://localhost:3000"
}

output "prometheus_url" {
  value = "http://localhost:9090"
}

output "alertmanager_url" {
  value = "http://localhost:9093"
}

output "trainer_api_url" {
  value = "http://localhost:8080"
}

output "loki_url" {
  value = "http://localhost:3100"
}

output "tempo_url" {
  value = "http://localhost:3200"
}

output "deployment_mode" {
  value = "bare-metal-systemd"
}
