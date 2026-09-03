# Getting started

## Requirements

- Docker.
- [mise](https://mise.jdx.dev), then `make setup` (`mise install` plus `pre-commit install`).
  Every tool version used here, Node, OpenTofu, Terragrunt, Helm, kind, kubectl, k6, and the
  linters used in CI, is pinned in `mise.toml`.
- Host memory: 8 GB minimum; the chaos scenarios were run on 7.6 GB with `VUS=10`.
- inotify limits high enough for kind and kube-proxy. The Linux and WSL2 default of 128
  instances is too low and kind fails with "too many open files". Set:

  ```bash
  sudo sysctl -w fs.inotify.max_user_instances=512
  sudo sysctl -w fs.inotify.max_user_watches=1048576
  ```

- Ports 80 and 443 free on the host. kind maps them to the Gateway nodePorts.
- `make hosts` writes to `/etc/hosts` and asks for `sudo`.

## What make up does

`make up` runs four targets in order.

| Step | Command | What it creates | Time on a 7.6 GB host |
| --- | --- | --- | --- |
| `make infra` | `terragrunt stack run apply` | kind cluster (1 control plane, 3 workers labelled zone-a/b/c); Gateway API CRDs, NGINX Gateway Fabric, cert-manager with a local CA, kube-prometheus-stack, Loki, Alloy, metrics-server; MySQL Operator and a 3-instance InnoDB Cluster with 2 routers; the `posts` database and its two users | 12 to 20 min, most of it the InnoDB Cluster reaching ONLINE |
| `make build` | `docker build` | `skizay/posts-api:dev` | 1 min |
| `make kind-load` | `kind load docker-image` | the image on the three worker nodes | 1 min |
| `make deploy` | `scripts/helm/deploy-app.sh` | Helm release `posts-api` in namespace `posts-api`: migrate Job, Deployment, HPA, PDB, NetworkPolicy, HTTPRoute, ServiceMonitor, alerts, dashboard | 1 to 2 min |

From scratch on a 7.6 GB WSL2 host, on Kubernetes v1.34.0, this took 17 minutes. The times in
the table split that run and are approximate.

Two inputs replace the cluster instead of updating it: `node_image` in
`infra/environments/common/cluster.yaml`, and the `extra_port_mappings` blocks in
`infra/modules/kind-cluster/main.tf`. The kind provider cannot change either in place, so a plan
that touches them destroys the cluster and everything on it. The next apply then takes the full
17 minutes.

## After make up

```bash
make hosts    # posts.local.test and grafana.local.test in /etc/hosts, asks for sudo
make test     # k6 smoke test, 12 checks
make grafana  # prints the Grafana admin password
```

The API is at `https://posts.local.test` and Grafana at `https://grafana.local.test`. Both use the
local CA certificate, so a browser warns on first visit.

## Using your own image

`IMAGE=<user>/posts-api make up` builds, loads and deploys under that name instead of
`skizay/posts-api`.

To pull a released image from the private Docker Hub repository rather than building locally:

```bash
DOCKERHUB_USERNAME=<user> DOCKERHUB_TOKEN=<token> scripts/registry/create-pull-secret.sh
make deploy REGISTRY=private TAG=0.2.1
```

That pulls `<IMAGE>-private:<tag>` with the `dockerhub` pull secret.
[Operations](operations.md#private-registry) covers the secret and why the tag has to be explicit.

## First-run problems

| Symptom | Cause | Fix |
| --- | --- | --- |
| kind fails with `too many open files` | inotify limits at the distribution default | The two `sysctl` commands above, then `make up` again |
| `bind: address already in use` on 80 or 443 | another process holds the port | `sudo ss -ltnp \| grep -E ':80\|:443'`, stop it, then `make up` again |
| `make up` fails during refresh with `cluster not found` | `.state` left behind by an older `make down` that did not clean it up | `make down` again, which removes `.state` and `.terragrunt-stack`, then `make up` |
| InnoDBCluster stays OFFLINE after a host reboot | every MySQL pod restarted at once, so group replication has no quorum to elect from | [Recovering from a full outage](operations.md#recovering-from-a-full-outage) |
| No DNS in WSL2 after `wsl --shutdown` | the generated `/etc/resolv.conf` points at a stale gateway | Put `nameserver 1.1.1.1` in `/etc/resolv.conf` |
