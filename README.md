# static-site

## Dev Notes

### New Clone

When this repo is cloned anew, theme submodules will need to be pulled in as well.

- `git submodule init`
- `git submodule update`

### Making Changes

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

Additionally, depending on the archetype, some configuration can be passed as environment variables (like `HUGO_PARAMS_parameter_name_here` to `hugo new` in order to automatically populate the new file.
Perhaps most common is to pass the name of a new D&D post in order to automatically generate both the post's title and its URL at the time of creation:

```bash
HUGO_PARAMS_Name="my cool title" hugo new -k dnd-post content/dnd/posts/2023-01-07.md
```

Given a `dnd-post` archetype that includes the following templating in its front matter

```toml
---
title: {{ .Site.Params.Name | title }}
url: /dnd/posts/{{- time.Format "2006" .Date -}}/{{- time.Format "01" .Date -}}/{{- time.Format "02" .Date -}}/{{- .Site.Params.Name | urlize }}
---
```

the `hugo new` command above will generate the file `content/dnd/posts/2023-01-07.md` with front matter that looks like so:

```toml
---
title: My Cool Title
url: /dnd/posts/2023/01/07/my-cool-title
---
```

Available archetypes can be found within the `src/archetypes/` dir.

### Deploying

GitHub Actions are leveraged to automatically publish and deploy the site.
Pushes to `master` trigger this publishing process, and the finished website is automatically pushed to the `gh-pages` branch and served from there.
Consult the `.github/workflows/github-pages.yml` file for details.
