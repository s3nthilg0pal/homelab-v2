provider "proxmox" {
  endpoint = var.proxmox_endpoint
  insecure = var.proxmox_insecure

  # Authentication is intentionally read from PROXMOX_VE_API_TOKEN.
  # Do not put the API token in this repository or Terraform variables.
}

