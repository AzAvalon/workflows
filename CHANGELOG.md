## [0.2.0](https://github.com/AzAvalon/workflows/compare/0.1.2...0.2.0) (2026-11-15)

### Features

* add _pr_packages_cleanup.yml to delete the GHCR packages of a closed PR ([5162dcb](https://github.com/AzAvalon/workflows/commit/5162dcb137dd7100518fb68b6de790febc58bbf7))
* **chart:** publish charts to the GitHub Container Registry by default ([45666df](https://github.com/AzAvalon/workflows/commit/45666df38f5310451d4385f7f6a88b30b889326e))
* **docker:** push images to the GitHub Container Registry by default ([52b704f](https://github.com/AzAvalon/workflows/commit/52b704f7f41d468cb871424ff4a49cae38eb650a))

### Bug Fixes

* **cleanup:** delete a package whole when only the PR's versions are left ([a91615b](https://github.com/AzAvalon/workflows/commit/a91615badf69b02197e6f3f0209821d9bcdc7f8a)), closes [#18](https://github.com/AzAvalon/workflows/issues/18)
* **release:** give cargo-binstall a GitHub token ([2fe7b08](https://github.com/AzAvalon/workflows/commit/2fe7b08b41d81b04e89f94f55cd66e59ecc1f15d))

### Documentation

* describe GHCR publishing and PR package cleanup ([110e9a4](https://github.com/AzAvalon/workflows/commit/110e9a4c2b107710b393e93191289f3c238959bf))

## [0.1.2](https://github.com/AzAvalon/workflows/compare/0.1.1...0.1.2) (2026-11-14)

### Bug Fixes

* **chart:** check the kubeconform download against its checksum ([a35d684](https://github.com/AzAvalon/workflows/commit/a35d684449b8ca751d9dada0769c84b011b1fb60))
* **docker:** pull Docker Hub images through mirror.gcr.io ([325e49f](https://github.com/AzAvalon/workflows/commit/325e49fc1d93aa5a00777a6390862ad841840f12))

### Documentation

* add SonarCloud badges to the README ([6998891](https://github.com/AzAvalon/workflows/commit/69988910102337d30e8a1869414985568fa38698))

## [0.1.1](https://github.com/AzAvalon/workflows/compare/0.1.0...0.1.1) (2026-11-14)

### Bug Fixes

* **docker:** keep provenance out of the bake metadata ([55ed53b](https://github.com/AzAvalon/workflows/commit/55ed53b397ee495b4a3e20141548ae92a0074e60))
