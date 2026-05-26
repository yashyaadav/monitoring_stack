variable "region" {
  description = "AWS region."
  type        = string
  default     = "us-west-2"
}

variable "instance_type" {
  description = "EC2 instance type. t3.small is the minimum that comfortably runs the full stack."
  type        = string
  default     = "t3.small"
}

variable "key_name" {
  description = "Name of an existing EC2 key pair in the chosen region for SSH access."
  type        = string
}

variable "allowed_cidr" {
  description = "CIDR allowed to reach SSH, Grafana, Prometheus, Alertmanager, and the sample app. Default is open — restrict for any real use."
  type        = string
  default     = "0.0.0.0/0"
}

variable "repo_url" {
  description = "Git repository URL the EC2 instance will clone and run."
  type        = string
  default     = "https://github.com/yashyaadav/monitoring_stack.git"
}

variable "repo_ref" {
  description = "Git ref (branch or tag) to check out."
  type        = string
  default     = "main"
}

variable "name" {
  description = "Name tag prefix for created resources."
  type        = string
  default     = "monitoring-stack-demo"
}
