# CI and releases

## Continuous integration

`ci.yaml` runs on every pull request and every push to `develop` or `main`, as four independent
jobs.

| Job | Runs | Fails when |
| --- | --- | --- |
| `app` | `npm ci`, lint, format check, build, `docker build`, Trivy scan | lint, format check or build fails, or Trivy finds a fixable CRITICAL/HIGH CVE |
| `chart` | `helm lint`, `helm-docs` drift check, `helm template` piped into `kubeconform`, and on pull requests a `Chart.yaml` bump check | the rendered manifests fail schema validation, the generated README is stale, or `charts/` changed without a version bump |
| `infra` | `tofu fmt`, `terragrunt hcl fmt`, `terraform-docs` drift check and `tflint` per module, `terragrunt stack run validate` | formatting drifts, a tflint rule trips, or a module does not validate |
| `lint` | `pre-commit run --all-files`, `actionlint` | a pre-commit hook fails or a workflow file is invalid |

Each job has `timeout-minutes: 20`. A `concurrency` group keyed on the ref cancels superseded runs,
so a second push cancels the first.

`e2e.yaml` is `workflow_dispatch` only ([cost](design-decisions.md#cost)).

## Release

`release.yaml` runs on any `v*` tag, as one job with `timeout-minutes: 30` and a `concurrency`
group per ref. In order:

1. Compare the tag against `version` in `charts/posts-api/Chart.yaml`. A mismatch fails the job
   before anything is built.
2. Build `linux/amd64` alone, load it into the runner's Docker, and scan it with Trivy. Nothing
   has reached a registry at this point.
3. Build `linux/amd64,linux/arm64` and push to `docker.io/skizay/posts-api` (tagged `<version>`
   and `latest`) and `docker.io/skizay/posts-api-private` (tagged `<version>`).
4. Sign both repositories by digest with cosign in keyless mode.
5. Package the chart and push it to `oci://ghcr.io/arthursampaio13/charts`.
6. Create the GitHub release with generated notes.

The job needs the `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN` repository secrets. The chart push and
the GitHub release use the workflow's own `GITHUB_TOKEN`, and cosign signs with the job's OIDC
token (`id-token: write`), so there is no signing key to store.

Verify a published signature:

```bash
cosign verify \
  --certificate-identity-regexp 'github.com/ArthurSampaio13/infrastructure-interview' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  skizay/posts-api:<version>
```

## Cutting a version

1. Bump `version` and `appVersion` in `charts/posts-api/Chart.yaml` and `version` in
   `app/package.json`.
2. Commit as `chore: bump chart and app to X.Y.Z`.
3. Rebase `main` on `develop`.
4. `git tag vX.Y.Z && git push origin main vX.Y.Z`.

The chart is at `0.3.0` and unreleased, so the next tag is `v0.3.0`.

## Vulnerability scans

CI scans every image it builds, and the release scans before it pushes. Both run
`trivy image --severity CRITICAL,HIGH --ignore-unfixed --exit-code 1`, so a finding only breaks the
build when there is a fix to apply.

A CVE with a fix is an image or dependency update. A CVE with no fix in the base image goes into
`.trivyignore`, in the format the current entries use. Run the CI scan against a local build with
`trivy image --severity CRITICAL,HIGH --ignore-unfixed skizay/posts-api:dev`.

## Dependabot

`dependabot.yml` watches npm (`/app`), GitHub Actions, Docker (`/app`) and Terraform
(`/infra/modules/*`), weekly. npm, GitHub Actions and Terraform updates arrive grouped, one pull
request per ecosystem; Docker base-image bumps arrive one per image. Majors are ignored for npm and
Docker. A major goes in by hand, on its own branch, with `make lint` and `make test`.

## What a team would add

An `environment: release` on the release job with required reviewers, and a tag protection rule so
not everyone can push a `v*` tag.
