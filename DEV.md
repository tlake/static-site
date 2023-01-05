# Dev Notes

## New Clone

When this repo is cloned anew, theme submodules will need to be pulled in as well.

- `git submodule init`
- `git submodule update`

## Making Changes

Changes are made within the `src/` directory, usually within `src/content/`.
Use `hugo serve` from within `src/` (or `hugo serve --source=src` from the repo root) to run a dev server on `localhost:1313`, and commit changes as appropriate.

Some layouts and templates have debug information available.
Debug mode is enabled by setting the `HUGO_ENV` environment variable to `debug`, like so:

```bash
HUGO_ENV=debug hugo serve
```

Different files are distinguished from each other by front matter, and there is often common templating for files of a given archetype.
To that end, when creating new files, it's recommended to let Hugo create the file instead of creating it by hand and copying and pasting the format from another file.
This can be done through use of the `-k` flag:

```bash
hugo -k [archetype] [filepath]/[filename]
```

Some common examples:

```bash
# from src/ dir

hugo new -k dnd-post content/dnd/posts/filename.md
hugo new -k dnd-location content/dnd/locations/filename.md
```

Consult the `src/archetypes/` dir for a list of available archetypes.

## Deploying

GitHub Actions are leveraged to automatically publish and deploy the site.
Pushes to `master` trigger this publishing process, and the finished website is automatically pushed to the `gh-pages` branch and served from there.
Consult the `.github/workflows/github-pages.yml` file for details.
