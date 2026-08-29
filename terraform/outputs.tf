output "apps01" {
  description = "Connection information for the API VM"
  value = {
    id      = proxmox_virtual_environment_vm.apps01.vm_id
    name    = proxmox_virtual_environment_vm.apps01.name
    address = split("/", var.apps_vm.address)[0]
    ssh     = "ssh senthil@${split("/", var.apps_vm.address)[0]}"
  }
}

