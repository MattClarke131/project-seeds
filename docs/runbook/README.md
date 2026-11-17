# Runbooks

Step-by-step procedures for operating the cluster and the hosts under it.

## Index

| Situation | Runbook |
| --- | --- |
| Before any risky change | [Preflight checklist](preflight-checklist.md) |
| Tailscale or Headscale is down | [Tailscale/Headscale Down](../tailscale-down.md) |
| Rebooting or updating TrueNAS | [Before rebooting/updating TrueNAS](../../infrastructure/truenas/README.md#before-rebootingupdating-truenas) |
| Major version bump on a stateful HelmRelease | [Preflight checklist](preflight-checklist.md), including its ZFS safety snapshots |
| Taking an etcd snapshot on demand | [`snapshot-now.sh`](../../infrastructure/kubernetes/etcd-backup/snapshot-now.sh) |

## Conventions

- **Start with preflight.** Every runbook begins with "Step 0: complete the [preflight checklist](preflight-checklist.md)."
- **Pair commands with results.** Every step gives a command and the result to expect.
- **Keep specific checks local.** Checks that apply to one procedure, such as pre-upgrade checks, stay in that procedure's runbook. The preflight checklist holds only the checks every change needs.
