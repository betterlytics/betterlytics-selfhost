# Releasing

Publishing a GitHub release in this repo builds the selfhost image from the [main repository](https://github.com/betterlytics/betterlytics) and pushes it to `ghcr.io/betterlytics/betterlytics-selfhost:<release tag>` for amd64 and arm64. `:latest` is never moved.

## Versions

These four must all be the same main-repo tag, for example `v1.5.1`:

- the release tag
- `BETTERLYTICS_REF`, the main-repo tag the image is built from
- `BETTERLYTICS_VERSION` in `base/.env.base`
- the image tag in `docker-compose.yml`

The image refuses to start when its version differs from `BETTERLYTICS_VERSION`, so a selfhost version always names the main-repo release it ships. `version-sync.yml` checks this on every push and pull request, and fails a release before anything is pushed.

A selfhost-only fix that does not change the image (compose, `setup.sh`, `base/`) is committed to the current version branch without a new release; installs pick it up with `git pull`. A fix that needs a new image needs a new main-repo tag first.

## Branches

There is one branch per selfhost version, named after it (`v1.5.1`). The newest is the default branch, and installs upgrade with `git pull origin <version>`.

## Steps

1. Create the branch `<version>` from the current default branch.
2. Set the version in `BETTERLYTICS_REF`, `base/.env.base` and `docker-compose.yml`, and push.
3. Publish a release with tag `<version>` targeting that branch, and check that the Publish workflow passes.
4. Make `<version>` the default branch, so new installs only see it once its image exists.
