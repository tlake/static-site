# Dev Notes

## New Clone

When this repo is cloned anew, theme submodules will need to be pulled in as well.

- `git submodule init`
- `git submodule update`

## Making Changes

Changes are made within the `src/` directory, usually within `src/content/`.
Use `hugo server` to run a dev server on `localhost:1313`, and commit changes as appropriate.

## Deploying

Once changes have been made and committed, run the `deploy.sh` script.
This will configure the environment and build the site's HTML and XML with `hugo -v` in accordance with the `config.toml` settings.
The built site resides in `docs/`, and once the site has been rebuilt, the script automatically commits those changes and then pushes to master.
Then, GitHub will automatically serve those changes, and the live site will be updated in a minute or so.
