# Mirroring third-party container images

This directory contains helper scripts and documentation for mirroring (caching/exporting) large third-party container images that are commonly used alongside vLLM.

## Important note about committing images to git

In general you should **not** commit `docker save` tarballs into the vLLM git repository:

- GitHub enforces strict file size limits (100MB per file), and container images are typically multiple GB.
- Large binaries dramatically bloat clone/fetch times.

If you need to avoid contacting an external registry repeatedly:

- On a single machine, Docker will reuse the locally cached image layers after the first `docker pull`.
- For offline/air-gapped use, export/import with `docker save` / `docker load` (see the per-image README files).
- For sharing across machines/teams, mirror the image to an internal registry (or GHCR) or attach the tarball to a Release/artifact store.
