# Terraform path — single EC2 demo

A minimal, single-file Terraform module that provisions one EC2 instance, installs Docker + the Compose plugin, clones this repo, and runs the stack. Useful when you want to share a public URL with a reviewer rather than asking them to clone and run locally.

> **Demo only.** No remote backend, no multi-AZ, no autoscaling, no TLS, no separate environments. Default security group is open to the world (`0.0.0.0/0`) — restrict via `-var allowed_cidr=` for any real use.

## Prerequisites

- An AWS account and credentials available in your shell (`AWS_PROFILE` or env vars).
- An existing EC2 key pair in the chosen region (`-var key_name=...`).
- Terraform `>= 1.6`.

## Apply

```bash
cd terraform
terraform init
terraform apply \
  -var key_name=YOUR_EC2_KEYPAIR \
  -var allowed_cidr=$(curl -s ifconfig.me)/32   # lock to your IP
```

After ~3 minutes (image pulls + first Compose `up`):

```bash
$ terraform output
alertmanager_url = "http://54.x.x.x:9093"
grafana_url      = "http://54.x.x.x:3000"
prometheus_url   = "http://54.x.x.x:9090"
public_dns       = "ec2-54-x-x-x.us-west-2.compute.amazonaws.com"
public_ip        = "54.x.x.x"
ssh_command      = "ssh ubuntu@54.x.x.x"
```

Open the Grafana URL. Default credentials: `admin` / `admin`. Change them immediately.

## What user_data does

[`user_data.sh`](user_data.sh):

1. Installs Docker Engine + the Compose plugin from Docker's official apt repo (not the older `docker.io` package).
2. Clones this repo to `/opt/monitoring_stack`.
3. Copies `.env.example` → `.env`.
4. Runs `docker compose up -d --wait`.
5. Installs a `monitoring-stack.service` systemd unit so the stack survives reboots.

Logs land in `/var/log/user-data.log` on the instance — `ssh ubuntu@<ip>` and `sudo tail -f /var/log/user-data.log` to watch the bootstrap.

## Variables

| Name           | Default                                           | Description                                                    |
| -------------- | ------------------------------------------------- | -------------------------------------------------------------- |
| `region`       | `us-west-2`                                       | AWS region.                                                    |
| `instance_type`| `t3.small`                                        | Smallest instance that comfortably runs the full stack.        |
| `key_name`     | *(required)*                                      | Existing EC2 key pair name in `region`.                        |
| `allowed_cidr` | `0.0.0.0/0`                                       | CIDR allowed to reach SSH/Grafana/Prom/AM/app. **Restrict.**   |
| `repo_url`     | `https://github.com/yashyaadav/monitoring_stack.git` | Git URL to clone on the instance.                           |
| `repo_ref`     | `main`                                            | Branch or tag to check out.                                    |
| `name`         | `monitoring-stack-demo`                           | Name-tag prefix for the instance and SG.                       |

## Destroy

```bash
terraform destroy -var key_name=YOUR_EC2_KEYPAIR
```

## What's intentionally not here

- **Remote state.** Local state files only — gitignored.
- **`environments/dev|prod`, modules/.** Overkill for one instance.
- **TLS + auth proxy in front of Grafana.** A real deployment puts ALB + ACM + an auth proxy (e.g., oauth2-proxy) in front of Grafana. Skipped here so the demo stays inspectable.
- **VPC / subnet customization.** Uses the default VPC. If your account has no default VPC, this won't work — add `subnet_id` and `vpc_id` data sources.
