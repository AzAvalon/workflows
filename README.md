# workflows

Reusable GitHub Actions workflows. They run only on GitHub-hosted
runners `ubuntu-26.04` (x64) and `ubuntu-26.04-arm` (arm64). Images and
Helm charts go to Docker Hub. Nothing uses AWS.

The runner images already ship Rust, Docker with Buildx, Helm 4, kind,
kubectl, yq, jq and Git LFS, so the workflows install very little.

## Workflows

| Workflow                 | What it does                                                                 |
| ------------------------ | ---------------------------------------------------------------------------- |
| `_build_push_docker.yml` | Builds a bake target per platform on a native runner, pushes the tags to Docker Hub, signs with cosign. |
| `_publish_chart.yml`     | Packages a Helm chart and pushes it to Docker Hub as an OCI artifact.        |
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

Every workflow takes a `runner` input (default `ubuntu-26.04`) except
`_build_push_docker.yml`, which picks the runner from each platform.

## Docker images

Each platform builds on its own runner: `linux/amd64` on `ubuntu-26.04`,
`linux/arm64` on `ubuntu-26.04-arm`. No QEMU. Each build pushes every
bake target by digest, without tags. A final job joins the digests of
each target into one multi-platform image, pushes the tags written in
the bake file, and signs it with cosign. Build layers are cached in the
GitHub Actions cache, one scope per Dockerfile, target and platform.
Docker Hub images (base images, the BuildKit image) are pulled through
`mirror.gcr.io`, so builds don't use the Docker Hub pull quota; pushes
still go to Docker Hub. Use `mirror.gcr.io/library/...` for the service
containers of `_tests_app.yml` too.

The bake file decides the tags. The workflow exposes these variables to
it: `DOCKER_IMAGE` (`<docker-registry>/<service-name>`, registry default
`docker.io/hichamaz`), `DOCKER_TAG_PRIMARY`, `DOCKER_TAG_EXTRA`,
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
    with:
      service-name: my-service
      docker-tag: ${{ github.ref_name }}
      docker-push: true
      github-client-id: ${{ vars.CI_APP_CLIENT_ID }}
      dockerhub-username: ${{ vars.DOCKERHUB_USERNAME }}
    secrets:
      github-private-key: ${{ secrets.CI_APP_PRIVATE_KEY }}
      dockerhub-token: ${{ secrets.DOCKERHUB_TOKEN }}
```

## Secrets

- `dockerhub-token` secret with the `dockerhub-username` input: Docker
  Hub access token (Read & Write) and user. Required to push images and
  charts; optional elsewhere. The user is an input, not a secret, so it
  is not masked in logs and image names.
- `github-private-key` with the `github-client-id` input: a GitHub App.
  Every workflow except the chart ones requires it and never uses
  `GITHUB_TOKEN` for writes; the job token stays read-only. Each workflow
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

`tests.yml` calls each workflow on pull requests and on every push to
`develop`, on both runners where it matters. Develop pushes publish the
dummy image and chart as `develop.<sha>` / `0.0.0-develop.<sha>`. `tests.yml` and `release.yml` need:

- variable `CI_APP_CLIENT_ID` and secret `CI_APP_PRIVATE_KEY` (the App),
- variable `DOCKERHUB_USERNAME` and secret `DOCKERHUB_TOKEN` (push the
  dummy image and chart; only `tests.yml`).

In AzAvalon they are all set once at organization level.
