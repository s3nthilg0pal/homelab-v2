resource "proxmox_download_file" "debian_13_cloud" {
  content_type = "import"
  datastore_id = var.iso_datastore_id
  node_name    = var.proxmox_node_name
  file_name = "debian-13-genericcloud-amd64.qcow2"
  url       = "https://cloud.debian.org/images/cloud/trixie/latest/debian-13-genericcloud-amd64.qcow2"
}

resource "proxmox_virtual_environment_vm" "apps01" {
  name        = var.apps_vm.name
  description = "Docker API host managed by Terraform and Ansible"
  tags        = ["terraform", "ansible", "apps"]
  node_name   = var.proxmox_node_name
  vm_id       = var.apps_vm.vm_id

  started         = true
  on_boot         = true
  stop_on_destroy = true

  agent {
    enabled = true
    timeout = "15m"

    # The VM has a static address, so creation does not need to wait for the
    # guest agent to report an IP. Ansible installs and starts the agent later.
    wait_for_ip {
      disabled = true
    }
  }

  bios    = "ovmf"
  machine = "q35"

  efi_disk {
    datastore_id      = var.vm_datastore_id
    file_format       = "raw"
    type              = "4m"
    pre_enrolled_keys = true
  }

  cpu {
    cores = var.apps_vm.cores
    type  = "host"
  }

  memory {
    dedicated = var.apps_vm.memory_mb
    floating  = 2048
  }

  disk {
    datastore_id = var.vm_datastore_id
    file_format  = "raw"
    import_from  = proxmox_download_file.debian_13_cloud.id
    interface    = "scsi0"
    iothread     = true
    discard      = "on"
    ssd          = true
    size         = var.apps_vm.disk_gb
  }

  initialization {
    datastore_id = var.vm_datastore_id

    dns {
      domain  = "home.arpa"
      servers = var.apps_vm.dns_servers
    }

    ip_config {
      ipv4 {
        address = var.apps_vm.address
        gateway = var.apps_vm.gateway
      }
    }

    user_account {
      username = "senthil"
      keys     = [trimspace(file(pathexpand(var.ssh_public_key_path)))]
    }
  }

  network_device {
    bridge   = "vmbr0"
    firewall = true
    model    = "virtio"
  }

  operating_system {
    type = "l26"
  }

  scsi_hardware = "virtio-scsi-single"

  serial_device {}
}
