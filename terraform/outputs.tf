output "public_ip" {
  description = "Public IPv4 address of the demo instance."
  value       = aws_instance.stack.public_ip
}

output "public_dns" {
  description = "Public DNS name of the demo instance."
  value       = aws_instance.stack.public_dns
}

output "grafana_url" {
  description = "Grafana URL (admin/admin until overridden in the cloned .env)."
  value       = "http://${aws_instance.stack.public_ip}:3000"
}

output "prometheus_url" {
  description = "Prometheus URL."
  value       = "http://${aws_instance.stack.public_ip}:9090"
}

output "alertmanager_url" {
  description = "Alertmanager URL."
  value       = "http://${aws_instance.stack.public_ip}:9093"
}

output "ssh_command" {
  description = "Convenience SSH command (assumes the matching private key is in your agent)."
  value       = "ssh ubuntu@${aws_instance.stack.public_ip}"
}
