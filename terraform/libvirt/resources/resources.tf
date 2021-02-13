variable "provider_uri" { default = "qemu:///system" }
variable "cluster_name" { default = "k8s" }
variable "libvirt_pool_path" { default = "/var/lib/libvirt/images" }
variable "network_cidr" {
  type = list
  default = ["192.168.100.0/24"]
}
variable "domain" {default = "k8s.lan"}

provider "libvirt" {
  uri = var.provider_uri
}

terraform {
 required_version = ">= 0.13"
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "0.6.3"
    }
  }
}

resource "libvirt_pool" "cluster" {
  name = var.cluster_name
  type = "dir"
  path = "${var.libvirt_pool_path}/${var.cluster_name}"
}

resource "libvirt_network" "k8s_network" {
  name = var.cluster_name
  mode = "nat"
  domain = var.domain
  addresses = var.network_cidr
  bridge = var.cluster_name
  dhcp {
    enabled = false
  }
  dns {
    enabled = true
  }
}