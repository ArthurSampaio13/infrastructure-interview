# Design decisions

## MySQL 8 InnoDB Cluster instead of MariaDB 5.5

The database is MySQL 8 under the official MySQL Operator, replacing the original MariaDB 5.5.
MariaDB 5.5 is out of support and has no first-class Kubernetes operator. The operator gives
group replication, automatic primary election, and a router the app points at without knowing
which instance is primary, which is what "highly available across zones" requires.

## Migrations instead of `synchronize`

Schema changes ship as TypeORM migrations, not `synchronize: true`. `synchronize` diffs the
entities against the live schema and applies the result directly, which is fine for a prototype
and unsafe once there is data. Migrations are explicit, reviewable, and run once per deploy as a
Helm hook, so a rollout never carries an untracked schema change along with it.

## Gateway API and NGINX Gateway Fabric instead of ingress-nginx

Routing uses the Gateway API, implemented by NGINX Gateway Fabric. ingress-nginx is in
maintenance mode with no further feature development, and the Gateway API is where routing
configuration is headed. The chart ships an `HTTPRoute` and needs no
ingress-controller-specific annotations.

## NetworkPolicy declared, kindnet kept

The chart declares a NetworkPolicy and the local cluster keeps kindnet, which accepts the object
without enforcing it. Cilium does enforce it, and an earlier version of this repo ran Cilium; its
four agents added about 600 MiB of resident memory to a host already near its limit, and the
chaos scenarios started failing on memory pressure rather than on what they were meant to test.
The policy stays because it costs nothing here and is enforced on any cluster whose CNI supports
it (GKE Dataplane V2, Calico, Cilium). To check enforcement on such a cluster, run a curl pod in
`default` against `posts-api.posts-api:3000` and expect it to fail, then one in `gateway` and
expect HTTP 200.

## cert-manager with a local CA, not an ACME issuer

cert-manager issues the `*.local.test` certificate from a CA created on cluster bootstrap. A kind
cluster has no public DNS record to prove ownership of, so an ACME issuer has nothing to
validate. A real environment swaps the `ClusterIssuer` for Let's Encrypt or another ACME issuer,
and nothing else in the chart or the Gateway configuration changes.

## OpenTofu and Terragrunt for the platform, plain Helm for the app

The platform (cluster, addons, database) is provisioned with OpenTofu and Terragrunt; the app
deploys with plain Helm. The platform changes rarely and benefits from state and plan/apply
review, while the app changes on every commit and needs an ordinary `helm upgrade` path,
including from CI. An app deploy never waits on a `tofu plan`, and a platform change never gets
bundled into an app release.

OpenTofu rather than Terraform: HashiCorp relicensed Terraform under the BSL in 2023, and
OpenTofu is the Linux Foundation fork that stayed open source. It is a drop-in replacement for
the code here and resolves the same providers from the same registry.

## Distroless, non-root, cosign-signed image

The runtime image is distroless, runs as a non-root user, and is signed with cosign on release.
No shell, no package manager and no root user shrinks what an attacker gets out of a container
escape or a dependency compromise. The signature gives anyone pulling the image a way to verify
it came from this pipeline.

## App modernization (Node 22, TypeORM 0.3, TypeScript 5)

The app moved to current majors of Node, TypeORM and TypeScript. The original targeted an EOL
Node line and an old TypeORM major with a callback-heavy API. Current majors also unblock
distroless images, which only ship supported runtimes.

## Cost

Nothing here bills, and the same choices are what keep a real bill down. `e2e.yaml` is
`workflow_dispatch` only, so a kind cluster is not built on every push and the expensive job runs
when someone asks for it. Prometheus keeps 24h of data, which is enough to read a chaos run and
small enough to fit the single node it runs on. Every workload declares requests and limits, so
the scheduler packs nodes instead of guessing, and the HPA is capped (`maxReplicas` 6 locally) so
a traffic spike cannot scale the bill without a ceiling. Observability runs as a single-node
stack with a single-binary Loki rather than a distributed one, which is the right trade at this
size and the first thing to revisit at a larger one.

## What was left out on purpose

Authentication, rate limiting and a unit test suite are not in `app/`. None of them change how
the infrastructure around the app has to behave, and the brief for this exercise is the
infrastructure, not the API. Pagination is in, because an unbounded list endpoint is an
availability problem. Tests cover correctness end to end instead: the k6 smoke test hits every
route and every documented error path, and the chaos scenarios run the app under real failures. There is also no cloud environment; the decisions above call out where a cloud
deployment would differ, most obviously an ACME issuer instead of a local CA.
