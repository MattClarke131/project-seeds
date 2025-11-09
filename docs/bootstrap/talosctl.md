# Talosctl Configuration

## Step 1: Install Talosctl
Download and install the Talosctl CLI tool on your local machine. Follow the instructions at https://talos.dev/docs/v0.15/introduction/getting-started/#install-talosctl

## Step 2: Generate Talos Configuration
```bash
cd infrastructure/talos
talosctl gen config <cluster-name> https://10.0.10.10:6443
```
