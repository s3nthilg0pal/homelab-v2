# Homelab infrastructure

Terraform provisions Proxmox VMs. Cloud-init creates the initial user and SSH
access. Ansible configures Debian, Docker, and the API containers.

The existing PostgreSQL VM (`192.168.0.89`) is deliberately not managed here.
This prevents an accidental Terraform destroy from removing the databases.

## One-time prerequisites

1. Create the `terraform@pve!provider` API token in Proxmox.
2. Install the tools declared in `mise.toml`:

   ```bash
   mise install
   ```

3. Create an SSH key if one does not exist:

   ```bash
   ssh-keygen -t ed25519 -a 100
   ```

4. Copy the Terraform variable example:

   ```bash
   cp terraform/terraform.tfvars.example terraform/terraform.tfvars
   ```

5. Confirm `proxmox_node_name` in `terraform.tfvars` matches the node name in
   the Proxmox UI. Common values are `pve`, `pve1`, or the installed hostname.

6. Load the Proxmox token without writing it to Terraform files:

   ```bash
   read -rsp "Proxmox API token: " PROXMOX_VE_API_TOKEN
   echo
   export PROXMOX_VE_API_TOKEN
   ```

   Paste the complete value in this form:

   ```text
   terraform@pve!provider=TOKEN-SECRET
   ```

## Provision `apps01`

Review the plan carefully. Terraform is allowed to create and destroy the VM it
manages.

```bash
cd terraform
terraform init
terraform fmt -check
terraform validate
terraform plan -out=apps01.tfplan
terraform apply apps01.tfplan
```

Wait for cloud-init and SSH:

```bash
ssh senthil@192.168.0.90
```

## Configure secrets

Install the required Ansible collection:

```bash
ansible-galaxy collection install -r ansible/requirements.yml
```

Create the encrypted Vault file from the documented example:

```bash
cp ansible/group_vars/all/vault.yml.example /tmp/homelab-vault.yml
ansible-vault encrypt /tmp/homelab-vault.yml \
  --output ansible/group_vars/all/vault.yml
rm /tmp/homelab-vault.yml
```

Edit it later with:

```bash
ansible-vault edit ansible/group_vars/all/vault.yml
```

## Configure and deploy the API VM

```bash
cd ansible
ansible-playbook playbooks/apps.yml --ask-become-pass --ask-vault-pass
```

Check the result:

```bash
curl --fail http://192.168.0.90:8080/health
curl --fail http://192.168.0.90:8081/health
```

If Senthil API uses a health path other than `/health`, update the check to
match the application.

## Normal changes

Infrastructure change:

```bash
cd terraform
terraform plan
terraform apply
```

Guest or application change:

```bash
cd ansible
ansible-playbook playbooks/apps.yml --ask-become-pass --ask-vault-pass
```

Do not commit API tokens, Vault passwords, `.env` files, Terraform state, or
database dumps. Local Terraform state is sensitive and must be backed up to an
encrypted location before this becomes the only copy.
