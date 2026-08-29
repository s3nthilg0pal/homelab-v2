variable "proxmox_endpoint" {
  description = "Proxmox API endpoint, without /api2/json"
  type        = string
  default     = "https://192.168.0.95:8006/"
}

variable "proxmox_insecure" {
  description = "Allow the self-signed certificate used during bootstrap"
  type        = bool
  default     = true
}

variable "proxmox_node_name" {
  description = "Exact Proxmox node name shown in the UI"
  type        = string
  default     = "pve1"
}

variable "iso_datastore_id" {
  description = "Datastore that permits ISO/import content"
  type        = string
  default     = "local"
}

variable "vm_datastore_id" {
  description = "Datastore for VM disks and cloud-init"
  type        = string
  default     = "local-lvm"
}

variable "ssh_public_key_path" {
  description = "Public key installed into cloud-init guests"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "apps_vm" {
  description = "apps01 virtual-machine configuration"
  type = object({
    vm_id       = number
    name        = string
    address     = string
    gateway     = string
    dns_servers = list(string)
    cores       = number
    memory_mb   = number
    disk_gb     = number
  })

  default = {
    vm_id       = 101
    name        = "apps01"
    address     = "192.168.0.90/24"
    gateway     = "192.168.0.1"
    dns_servers = ["192.168.0.1"]
    cores       = 2
    memory_mb   = 3000
    disk_gb     = 32
  }
}

