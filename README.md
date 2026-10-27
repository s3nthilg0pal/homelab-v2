# Homelab infrastructure

Terraform provisions Proxmox VMs. Cloud-init creates the initial user and SSH
access. Ansible configures Debian, Docker, and the API containers.

The existing PostgreSQL VM (`192.168.0.74`) is deliberately not managed here.
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

Install the local tools and required Ansible collections:

```bash
mise install
mise exec -- ansible-galaxy collection install \
  -r ansible/playbooks/collections/requirements.yml
```

Run deployment commands from a machine on the home network (or connected by
VPN) with SSH access to `senthil@192.168.0.90`. For example, verify SSH with:

```bash
ssh -i ~/.ssh/id_ed25519_homelab senthil@192.168.0.90
```

If your SSH key has a different filename, substitute its private-key path in
the commands below.

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

Guest configuration change:

```bash
cd ansible
mise exec -- ansible-playbook playbooks/apps.yml \
  --ask-become-pass --ask-vault-pass \
  -e "ansible_ssh_private_key_file=$HOME/.ssh/id_ed25519_homelab"
```

Application code changes must first be built and published to the image tag
configured in `ansible/group_vars/all/vars.yml`. For Gym, CI publishes
`ghcr.io/s3nthilg0pal/gym-api:main`. After that build succeeds, force the VM to
pull and restart the new image:

```bash
cd ansible
ANSIBLE_SSH_ARGS='-F /dev/null -o ControlMaster=auto -o ControlPersist=60s' \
  mise exec -- ansible-playbook playbooks/deploy_gym_image.yml \
  -i inventory/production.yml \
  -e "ansible_ssh_private_key_file=$HOME/.ssh/id_ed25519_homelab"
```

The force-pull command reuses the Gym environment already on the VM. The
`playbooks/gym.yml` playbook also updates the Gym environment from the encrypted
Vault file, so use it when changing VM configuration or Gym secrets. The
playbook's deploy handler runs when its Compose or environment template changes;
for code-only image updates, use `playbooks/deploy_gym_image.yml`.

## Run Gym deployments from Semaphore UI

Semaphore runs playbooks from a Git checkout. Add this repo as a Repository in
Semaphore, then create an Ansible task template with these settings:

| Setting | Value |
| --- | --- |
| Repository | This homelab repo, on the branch you deploy from |
| Playbook | `ansible/playbooks/deploy_gym_image.yml` |
| Working directory | `ansible` |
| Inventory | File: `ansible/inventory/production.yml` |
| Inventory user credential | SSH key for `senthil` that is authorized on `apps01` |
| Sudo credential | None if `senthil` can run sudo without a password |

No Vault password is needed for this image-only deployment. Semaphore reads the
collections dependency from `ansible/playbooks/collections/requirements.yml`.
For full app configuration via `playbooks/apps.yml`, store the Vault password
as a Semaphore Vault credential and attach it to that task template.

Semaphore's task templates pair a Git repository, playbook, inventory, and
credentials; see the [Ansible template guide](https://semaphoreui.com/docs/user-guide/task-templates/apps/ansible)
and [repository requirements guide](https://semaphoreui.com/docs/user-guide/repositories).

Do not commit API tokens, Vault passwords, `.env` files, Terraform state, or
database dumps. Local Terraform state is sensitive and must be backed up to an
encrypted location before this becomes the only copy.
