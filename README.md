# workflows

[![Quality Gate Status](https://sonarcloud.io/api/project_badges/measure?project=AzAvalon_workflows&metric=alert_status)](https://sonarcloud.io/summary/new_code?id=AzAvalon_workflows)
[![Security Rating](https://sonarcloud.io/api/project_badges/measure?project=AzAvalon_workflows&metric=security_rating)](https://sonarcloud.io/summary/new_code?id=AzAvalon_workflows)
[![Reliability Rating](https://sonarcloud.io/api/project_badges/measure?project=AzAvalon_workflows&metric=reliability_rating)](https://sonarcloud.io/summary/new_code?id=AzAvalon_workflows)
[![Maintainability Rating](https://sonarcloud.io/api/project_badges/measure?project=AzAvalon_workflows&metric=sqale_rating)](https://sonarcloud.io/summary/new_code?id=AzAvalon_workflows)

Reusable GitHub Actions workflows. They run only on GitHub-hosted
runners `ubuntu-26.04` (x64) and `ubuntu-26.04-arm` (arm64). Images and
Helm charts go to the GitHub Container Registry (`ghcr.io`) by default.
Nothing uses AWS.

The runner images already ship Rust, Docker with Buildx, Helm 4, kind,
kubectl, yq, jq and Git LFS, so the workflows install very little.

## Workflows

| Workflow                 | What it does                                                                 |
| ------------------------ | ---------------------------------------------------------------------------- |
| `_build_push_docker.yml` | Builds a bake target per platform on a native runner, pushes the tags to GHCR, signs with cosign. |
| `_publish_chart.yml`     | Packages a Helm chart and pushes it to GHCR as an OCI artifact.              |
| `_tests_chart.yml`       | `helm lint`, `helm template` and `kubeconform` on a chart.                    |
| `_integration_tests.yml` | Installs the chart in a kind cluster on the runner and waits until it is ready. |
| `_tests_app.yml`         | Runs `make` setup/test targets with optional service containers, uploads coverage and JUnit reports. |
| `_clippy.yml`            | Runs clippy `--fix` and rustfmt, opens an automatic PR with the changes.     |
| `_clippy_sonar.yml`      | Produces a clippy report for SonarCloud.                                      |
| `_sonarcloud.yml`        | Sends coverage and clippy reports to SonarCloud.                              |
| `_publish_cargo.yml`     | Publishes a crate to crates.io.                                               |
| `_pre_commit.yml`        | Checks the PR title and runs the pre-commit hooks with prek. Rust and Python versions are inputs. |
| `_release.yml`           | Runs semantic-release.                                                        |
| `_cache_cleanup.yml`     | Deletes old Actions caches of a branch.                                       |
| `_pr_cache_cleanup.yml`  | Deletes the Actions caches of a closed PR.                                    |
| `_pr_packages_cleanup.yml` | Deletes the GHCR images and charts of a closed PR.                          |

Every workflow takes a `runner` input (default `ubuntu-26.04`) except
`_build_push_docker.yml`, which picks the runner from each platform.

## Docker images

Each platform builds on its own runner: `linux/amd64` on `ubuntu-26.04`,
`linux/arm64` on `ubuntu-26.04-arm`. No QEMU. Each build pushes every
bake target by digest, without tags. A final job joins the digests of
each target into one multi-platform image, pushes the tags written in
the bake file, and signs it with cosign. Build layers are cached in the
GitHub Actions cache, one scope per Dockerfile, target and platform.
Images are pushed to `ghcr.io/<owner>` (lowercase) with the job's
`GITHUB_TOKEN`, so the caller grants `packages: write`. They carry the
`org.opencontainers.image.source` label, which links the GHCR package to
the repository. Docker Hub images (base images, the BuildKit image) are
pulled through `mirror.gcr.io`, so builds don't use the Docker Hub pull
quota. Use `mirror.gcr.io/library/...` for the service containers of
`_tests_app.yml` too. To push to Docker Hub instead, set
`docker-registry: docker.io/<user>` with `dockerhub-username` and the
`dockerhub-token` secret.

The bake file decides the tags. The workflow exposes these variables to
it: `DOCKER_IMAGE` (`<docker-registry>/<service-name>`, registry default
`ghcr.io/<owner>`), `DOCKER_TAG_PRIMARY`, `DOCKER_TAG_EXTRA`,
`DOCKERFILE`, `BAKE_CONTEXT`, and the `git-credentials` build secret
(the App token). Groups with several targets work; every target needs at
least one tag.

```yaml
jobs:
  docker:
    uses: AzAvalon/workflows/.github/workflows/_build_push_docker.yml@<sha>
    permissions:
      id-token: write # cosign
      contents: read
      packages: write # ghcr.io
    with:
      service-name: my-service
      docker-tag: ${{ github.ref_name }}
      docker-push: true
      github-client-id: ${{ vars.CI_APP_CLIENT_ID }}
    secrets:
      github-private-key: ${{ secrets.CI_APP_PRIVATE_KEY }}
```

A new GHCR package starts private. Make it public once in its package
settings if anyone outside the organization pulls it.

## Cleaning up PR packages

Images and charts pushed for a pull request (tags `pr-<N>.*`, chart
versions `0.0.0-pr.<N>.*`) are deleted when the PR closes, merged or not,
by calling `_pr_packages_cleanup.yml` on `pull_request: closed`.
Multi-platform images go with their platform images and cosign
signatures. A second pass deletes untagged images older than two hours
(`untagged-older-than`), such as platform images two deleted images
shared; younger ones may belong to a build still running. The calling
repository needs admin access to the packages,
which it has when its own workflows pushed them first. A package that holds
nothing but the PR's versions is deleted whole, since GitHub refuses to
delete the last version of a package. To retry a failed cleanup, run the
caller by hand with the PR number (`workflow_dispatch`, as
`pr-cleanup.yml` here does).

```yaml
on:
  pull_request:
    types: [closed]

jobs:
  packages:
    if: ${{ github.event.pull_request.head.repo.full_name == github.repository }}
    uses: AzAvalon/workflows/.github/workflows/_pr_packages_cleanup.yml@<sha>
    permissions:
      contents: read
      packages: write
    with:
      packages: my-service,charts/my-service
```

## Secrets

- No secret is needed for GHCR: the image, chart and cleanup workflows
  use the job's `GITHUB_TOKEN` with `packages: write`. GitHub Apps cannot
  write packages, so this is the one write the job token does.
- `dockerhub-token` secret with the `dockerhub-username` input: optional
  Docker Hub access token and user, to push to Docker Hub or to pull
  private Docker Hub images and charts. The user is an input, not a
  secret, so it is not masked in logs and image names.
- `github-private-key` with the `github-client-id` input: a GitHub App.
  Every workflow except the chart and cleanup ones requires it and never
  uses `GITHUB_TOKEN` for other writes. Each workflow
  asks the App only for the scopes it needs (for example `contents: read`
  for builds, `contents`/`issues`/`pull-requests: write` for releases).
- `cargo-registry-token`: crates.io token. Without it,
  `_publish_cargo.yml` uses crates.io trusted publishing, which must be
  set up on crates.io for the calling repository first.
- `sonar-token`: only for SonarCloud.

## GitHub App

One App can serve every workflow. Give it these repository permissions:
Contents, Pull requests, Issues and Actions (read and write), and install
it on the repositories that call the workflows. To let semantic-release
push to a protected `main`, add the App to the branch ruleset bypass list.

Tokens are minted for the calling repository only. Set
`github-app-repositories` (names, same owner, including the calling
repository) when a build needs other private repositories.

## Updates

Renovate keeps everything pinned up to date: action digests, pre-commit
hooks, the Dockerfile and Cargo dependencies, and the tool versions
written inside the workflows. A tool version in a workflow gets a
`# renovate: datasource=... depName=...` comment on the line above it;
the custom manager in `renovate.json` picks it up.

## Testing this repository

`tests.yml` calls each workflow on pull requests, on both runners where it
matters. `develop` only moves by fast-forward to a tested PR head, so pushes
to it do not run the checks again. `tests.yml` and `release.yml` need:

- variable `CI_APP_CLIENT_ID` and secret `CI_APP_PRIVATE_KEY` (the App),
  set once at organization level in AzAvalon.

The dummy image and chart go to `ghcr.io/azavalon/dummy-service` and
`ghcr.io/azavalon/charts/dummy-service`; `pr-cleanup.yml` deletes a PR's
versions when it closes.
