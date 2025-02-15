# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "3.0.1"
    }

    tls = {
      source  = "hashicorp/tls"
      version = "4.0.4"
    }

    enos = {
      source = "app.terraform.io/hashicorp-qti/enos"
    }
  }
}

variable "image_name" {
  description = "Name of Docker Image"
  type        = string
  default     = "docker.mirror.hashicorp.services/linuxserver/openssh-server:latest"
}
variable "network_name" {
  description = "Name of Docker Network"
  type        = string
}
variable "container_name" {
  description = "Name of Docker Container"
  type        = string
  default     = "openssh-server"
}
variable "target_user" {
  description = "SSH username for target"
  type        = string
  default     = "ubuntu"
}
variable "private_key_file_path" {
  description = "Local Path to key used to SSH onto created hosts"
  type        = string
}

data "tls_public_key" "host_key_openssh" {
  private_key_openssh = file(var.private_key_file_path)
}

resource "tls_private_key" "ca_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

data "tls_public_key" "ca_key" {
  private_key_openssh = tls_private_key.ca_key.private_key_openssh
}

locals {
  ssh_public_key = data.tls_public_key.host_key_openssh.public_key_openssh
  ca_public_key  = data.tls_public_key.ca_key.public_key_openssh
}

resource "docker_image" "openssh_server" {
  name         = var.image_name
  keep_locally = true
}

resource "docker_container" "openssh_server" {
  image = docker_image.openssh_server.image_id
  name  = var.container_name
  env = [
    "PUID=1000",
    "PGID=1000",
    "TZ=US/Eastern",
    "USER_NAME=${var.target_user}",
    "PUBLIC_KEY=${local.ssh_public_key}",
  ]
  networks_advanced {
    name = var.network_name
  }
  ports {
    internal = 2222
    external = 2222
  }
  volumes {
    host_path      = format("%s/%s", abspath(path.module), "/custom-cont-init.d")
    container_path = "/custom-cont-init.d"
  }
  upload {
    content_base64 = base64encode(tls_private_key.ca_key.private_key_openssh)
    file           = "/ca/ca-key"
  }
  upload {
    content_base64 = base64encode(local.ca_public_key)
    file           = "/ca/ca-key.pub"
  }
}

resource "enos_local_exec" "wait" {
  depends_on = [
    docker_container.openssh_server
  ]

  inline = ["timeout 20s bash -c 'until ssh -t -t -i ${var.private_key_file_path} -p 2222 -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o IdentitiesOnly=yes ${var.target_user}@localhost hostname; do sleep 2; done'"]
}

output "user" {
  value = var.target_user
}

output "address" {
  value = docker_container.openssh_server.network_data[0].ip_address
}

output "port" {
  value = "2222"
}

output "ca_key" {
  value = base64encode(tls_private_key.ca_key.private_key_openssh)
}
