---

date: {{ now.Format "2006-01-02" }}
description: Description Placeholder
dnd/ref/characters:
dnd/ref/locations:
summary: >
  Summary Placeholder
title: {{ default .Name .Site.Params.Name | title }}
url: /dnd/posts/{{- time.Format "2006" .Date -}}/{{- time.Format "01" .Date -}}/{{- time.Format "02" .Date -}}/{{- default .Name .Site.Params.Name | urlize }}

---

Content Placeholder

