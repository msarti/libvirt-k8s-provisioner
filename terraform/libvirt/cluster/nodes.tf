variable "provider_uri" { default = "qemu:///system" }
variable "pool" { default = "k8s" }
variable "network_name" { default = "default" }
variable "cloudimage_file" {
  type = string
  default = "none"
}

variable "netmask" { type = string}
variable "network" { type = string}
variable "broadcast" { type = string}
variable "gateway" { type = string}
variable "dns_nameservers" { type = string}


variable "masters" {
  type = list(
    object(
      {
        name = string
        disk_size = number
        memory = string
        ip_address = string
        vcpu = string
        network_iface = string
      }
    )
  )
  default = []
}


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

resource  "libvirt_volume" "base_volume" {
  name = "base_volume"
  source = var.cloudimage_file
  pool = var.pool
}

resource "libvirt_volume" "master" {
  name           = "${var.masters[count.index].name}.qcow2"
  base_volume_id = libvirt_volume.base_volume.id
  size = var.masters[count.index].disk_size
  count = length(var.masters)
  pool = var.pool
}

# configurazione cloudinit
data "template_file" "user_data" {
 template = file("${path.module}/cloud_init.cfg")
}
data "template_file" "master_meta_data" {
 count = length(var.masters)
 template = file("${path.module}/network_config.cfg")
 vars = {
   ip_address = var.masters[count.index].ip_address
   netmask = var.netmask
   network = var.network
   broadcast = var.broadcast
   gateway = var.gateway
   dns_nameservers = var.dns_nameservers
   network_iface = var.masters[count.index].network_iface
 }
}
resource "libvirt_cloudinit_disk" "master_commoninit" {
 count = length(var.masters)
 name = "${var.masters[count.index].name}-commoninit.iso"
 pool = var.pool
 user_data = data.template_file.user_data.rendered
 meta_data = data.template_file.master_meta_data[count.index].rendered
}

resource "libvirt_domain" "kube-master" {
   count = length(var.masters)

  name  = "master_${count.index}"
  memory = var.masters[count.index].memory
   vcpu = var.masters[count.index].vcpu
   cloudinit = libvirt_cloudinit_disk.master_commoninit[count.index].id
   dynamic "network_interface" {
     for_each = var.network_name != null ? [1] : []
     content {
        network_name = var.network_name
     }
   }

console {
   type = "pty"
   target_type = "serial"
   target_port = "0"
 }
disk {
   volume_id = libvirt_volume.master[count.index].id
 }
graphics {
   type = "spice"
   listen_type = "address"
   autoport = true
 }
}
