# Architecture

## Request path

A request arrives on host port 80 or 443, bound to 127.0.0.1 only. kind maps those to nodePorts
30080 and 30443 on the `zone-a` worker, so the request lands on that node's kube-proxy and is
forwarded to whichever zone answers it.

Both nodePorts belong to the NGINX Gateway Fabric data plane Service, which serves the Gateway
API `Gateway` (`gateway/gateway`). The HTTP listener accepts `HTTPRoute`s from its own namespace only and
redirects them to HTTPS. The HTTPS listener terminates TLS for `*.local.test` and accepts `HTTPRoute`s
from the `posts-api` and `monitoring` namespaces. The certificate comes from a local CA that
cert-manager builds on cluster bootstrap: a self-signed root, then a CA certificate, then a
`ClusterIssuer` backed by that CA. The nginx data plane runs two replicas spread across zones
with a PodDisruptionBudget of `maxUnavailable: 1`, so a node drain never takes both.

The diagram in the [README](../README.md#about) shows the same path.

## Cluster and zones

The kind cluster pins `kindest/node:v1.34.0` and runs one control-plane node and three workers,
each labelled a different `topology.kubernetes.io/zone` (`zone-a`, `zone-b`, `zone-c`). The chart
requires `kubeVersion >=1.30.0-0`.

A host port can be bound once, so the entry point sits on the `zone-a` worker alone and losing
that zone on this cluster also loses the entry point. The chaos scenarios drain `zone-b` by default
for that reason. In a cloud the load balancer in front of the nodes spans the zones and the rest
of the setup is unchanged.

## Application

The app runs as a Deployment with 3 replicas, spread across zones with a
`topologySpreadConstraint` (`maxSkew: 1`, `whenUnsatisfiable: DoNotSchedule`) and a preferred pod
anti-affinity by hostname. A PodDisruptionBudget allows one voluntary eviction at a time
(`maxUnavailable: 1`), which holds at 3 replicas and still holds when the HPA is at 6.
`unhealthyPodEvictionPolicy: AlwaysAllow` keeps a crash-looping pod from blocking node
maintenance.

A HorizontalPodAutoscaler scales on CPU between 3 and 10 replicas in the chart defaults; the
local values file caps `maxReplicas` at 6 to fit an 8 GB host. CPU is the signal because the app
is CPU-bound (JSON in, JSON out, a single Node.js thread) and metrics-server already collects it.
The 250m request is the number the target percentage is measured against; a 100m request would
have scaled out at 70m of actual use.

The zone spread uses `nodeTaintsPolicy: Honor`. A drained zone has an unschedulable taint on
every node, so it stops counting as a domain and the two remaining zones can still take new
replicas from the HPA. Without it a drained zone counts as a domain with zero pods and every
scale-up violates `maxSkew: 1`.

Schema migrations run as a Helm `pre-install`/`pre-upgrade` hook Job, so a `helm upgrade` always
applies pending migrations before the new Deployment rolls out. The Job declares the same
`resources` as the app and `activeDeadlineSeconds: 240`, so a migration that hangs fails the
release instead of holding it open.

The HPA lists pods by the Deployment selector (`app.kubernetes.io/name`,
`app.kubernetes.io/instance`). The migrate Job pod carries the same two labels, so during an
upgrade the HPA averages it in. The Job declares the same CPU request as the app, so the average
stays defined; the migrate pod lives for a few seconds and is gone before the next HPA sync.

A NetworkPolicy allows ingress only from the Gateway namespace (port 3000), the monitoring
namespace (port 9464) and the app's own namespace, and egress only to the MySQL router, DNS, and
itself. The local CNI, kindnet, does not enforce it
([why](design-decisions.md#networkpolicy-declared-kindnet-kept)).

The app reuses an inbound `x-request-id` only when it matches `^[\w.-]{1,128}$`, and generates a
UUID otherwise. The error handler logs body-parser failures and answers them like any other
error.

## Database

MySQL is an InnoDB Cluster managed by the official MySQL Operator: three server instances and two
MySQL Router instances in front of them. A topology spread constraint selecting
`component: mysqld` puts one server per zone; the routers spread with
`whenUnsatisfiable: ScheduleAnyway`, so both still schedule when a zone is drained. The app
never talks to a MySQL server directly. It connects to the router on port 6446, and the router
routes to whichever instance is currently primary.

## Observability

Metrics and alerts come from a kube-prometheus-stack (Prometheus, Alertmanager, Grafana), logs
from Loki and Alloy. Grafana is reachable at `https://grafana.local.test`. Prometheus keeps its
data on a 5 Gi PersistentVolumeClaim from kind's local-path StorageClass, which binds the pod to
the node holding the volume. Alloy runs as a DaemonSet and each instance tails only the pods on
its own node, selected with a `spec.nodeName` field selector.

The chart ships an app dashboard, loaded through the kube-prometheus-stack dashboard sidecar, and
three `PrometheusRule` alerts: `PostsApiHighErrorRate`, `PostsApiHighLatency` and
`PostsApiReplicasBelowPDB` (see [operations](operations.md)).

## Provisioning

The platform (kind cluster, Gateway/cert-manager/observability addons, MySQL cluster) is
provisioned with OpenTofu and Terragrunt: reusable modules under `infra/modules`, thin per-unit
wiring under `infra/units`, and one environment, `infra/environments/local`, that assembles the
units into a Terragrunt stack. The app deploys separately with plain Helm through
`scripts/helm/deploy-app.sh`.

## Image

The image is a multi-stage, distroless, non-root, multi-architecture build (`linux/amd64`,
`linux/arm64`), signed with cosign on release. CI scans it with Trivy on every build. A dated
`.trivyignore` covers CVEs that are only fixed in a base image Google has not republished yet,
with a comment saying why and when to drop each entry.

## API

| Method and path | Body or query | Success | Errors |
| --- | --- | --- | --- |
| `GET /posts` | `limit` 1..200 (default 50), `offset` >= 0 (default 0); newest first | 200, array of posts with categories | 400 invalid query |
| `GET /posts/{id}` | integer id | 200, one post with categories | 400 non-integer id, 404 unknown id |
| `POST /posts` | `{ "title": 1..255 chars, "text": non-empty, "categories": [{ "name": 1..255 chars }] }` (categories optional; each name creates a category row) | 201, the created post | 400 invalid body or malformed JSON, 413 body over 100 kB |

Every error body is `{ "error": "<reason>" }`; validation errors add `details`. The original app
returned 200 on create and had no pagination; both changed on purpose (see
[design decisions](design-decisions.md)).

Health endpoints live on port 9464: `/healthz` (process up), `/readyz` (a 2 s database ping; 503
while shutting down), `/metrics` (Prometheus format).
