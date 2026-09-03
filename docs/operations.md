# Operations

## Node maintenance

`make drain NODE=<name>` runs `kubectl drain` with `--ignore-daemonsets --delete-emptydir-data`,
which respects the PodDisruptionBudget. If another `posts-api` pod is already unavailable
(`maxUnavailable: 1`), the drain blocks instead of evicting. Run `kubectl uncordon <name>` when
the maintenance is done.

A zone drain can also take the entry point down. See [testing](testing.md#results).

## MySQL failover

Losing a single MySQL instance is self-healing. Group replication elects a new primary and the
router redirects traffic to it, with no operator action. This is what the MySQL primary kill chaos
scenario checks.

The MySQL Routers restart when the cluster loses quorum, which is what the chaos scenarios
provoke. They recover on their own once the cluster is ONLINE again.

The operator does not roll changes to `podSpec` resources or `mycnf` onto an existing InnoDB
Cluster; its log reports `sts_changed=False`. A fresh `make up` picks them up. On a running
cluster, patch the `mysql` StatefulSet template and let it roll one instance at a time.

## Recovering from a full outage

If every MySQL pod restarts at once, after a host reboot for example, group replication cannot
elect a primary: no member sees enough of the others to reach quorum. The InnoDB Cluster needs a
manual reboot from complete outage, run from a `mysqlsh` shell inside one of the MySQL pods:

```bash
PW=$(kubectl -n mysql get secret mysql-root -o jsonpath='{.data.rootPassword}' | base64 -d)
kubectl -n mysql exec -it mysql-0 -c mysql -- mysqlsh --js -uroot -p"$PW" \
  -e "dba.rebootClusterFromCompleteOutage()"
```

## Rotating the database passwords

The application and migration passwords are `random_password` resources in
`infra/modules/mysql-cluster`. Replacing one rewrites the Kubernetes secret and creates a new user
Job, `create-app-user-<8 hex>`, whose name carries a hash of both passwords. The Job runs
`ALTER USER`; the old Job is destroyed in the same apply.

```bash
cd infra/environments/local/.terragrunt-stack/mysql-cluster
terragrunt apply -replace=random_password.app -auto-approve --non-interactive
kubectl -n posts-api rollout restart deploy/posts-api
```

`-auto-approve` is required. With `--non-interactive` alone, tofu still asks for approval and the
run dies with `error asking for approval: EOF`.

The restart is only for `random_password.app`, because the app pods read the secret at start. For
`random_password.migration`, the next `helm upgrade` reads the new value and nothing needs
restarting. The root password (`random_password.root`) belongs to the operator's `mysql-root`
secret and is not rotated this way.

The Job takes about a minute. Confirm with `kubectl -n mysql get jobs` and then `make test`.

## Alerts

The chart ships three `PrometheusRule` alerts, visible in Alertmanager and Grafana.

| Alert | Fires when | Check first |
| --- | --- | --- |
| `PostsApiHighErrorRate` | 5xx rate over 1% of requests for 5 minutes | Recent deploys or migrations; app logs in Loki for the failing route |
| `PostsApiHighLatency` | p95 request latency over 500 ms for 5 minutes | MySQL router and InnoDB Cluster health; whether the HPA is scaling; node CPU |
| `PostsApiReplicasBelowPDB` | The PDB reports zero allowed disruptions for 2 minutes | `kubectl get pdb,pods -n posts-api`, node status per zone, recent rollout status |

The thresholds are looser than the k6 load-test SLO (p95 under 300 ms) on purpose. The SLO is what
the chaos scripts assert during a fault; the alerts are what a human gets paged on.

Alertmanager has no receiver. A real environment adds one under `alertmanager.config` in
`infra/modules/platform-addons/templates/kps.yaml.tftpl`.

## Private registry

`scripts/registry/create-pull-secret.sh` reads `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN` from the
environment and creates a `dockerhub` image pull secret in the `posts-api` namespace, with the
commands shown in [getting started](getting-started.md#using-your-own-image). The script applies
over an existing secret, so rotating the token is the same command again.

`make deploy REGISTRY=private` points the release at `<IMAGE>-private` and adds that secret to the
Deployment's `imagePullSecrets`. `TAG` has to be an explicit version, because `release.yaml` only
pushes released version tags to the private repository; the default `TAG=dev` exists only in the
local build path, which loads the image straight into the kind nodes.
