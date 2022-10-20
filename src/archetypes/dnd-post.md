---
date: {{ now.Format "2006-01-02" }}
description: Description Placeholder
dnd/ref/characters:
dnd/ref/locations:
summary: >
  Summary Placeholder
title: {{ .Name | title }}
url: /dnd/posts/{{- time.Format "2006" .Date -}}/{{- time.Format "01" .Date -}}/{{- .Name | urlize }}
---

Content Placeholder
