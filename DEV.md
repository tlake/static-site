# Dev Notes

## New Clone

When this repo is cloned anew, theme submodules will need to be pulled in as well.

- `git submodule init`
- `git submodule update`

## Making Changes

Changes are made within the `src/` directory, usually within `src/content/`.
Use `hugo serve` from within `src/` (or `hugo serve --source=src` from the repo root) to run a dev server on `localhost:1313`, and commit changes as appropriate.

## Deploying

GitHub Actions are leveraged to automatically publish and deploy the site.
Pushes to `master` trigger this publishing process, and the finished website is automatically pushed to the `gh-pages` branch and served from there.
Consult the `.github/workflows/github-pages.yml` file for details.
