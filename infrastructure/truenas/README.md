# TrueNAS

## Configuring TrueNAS reporting
Reporting > Exporters > Add
- Type: GRAPHIE
- Destination IP:
- Destination Port:
- Namespace: truenas

## Custom reporting scripts
1. Copy scripts from the `scripts` directory to the TrueNAS server at `/mnt/<pool>/scripts/`
2. Make the scripts executable:
```bash
chmod +x /mnt/<pool>/scripts/*.sh
```
3. Set up a cron job in the TrueNAS UI.
- Advanced Settings > Cron Jobs > Add
- Command: `/mnt/<pool>/scripts/send_zpool_metrics.sh`
- Schedule: Every Minute (or as desired)
- User: root
