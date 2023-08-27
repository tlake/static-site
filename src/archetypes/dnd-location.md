---

date: {{ default now .Site.Params.Date | time.Format "2006-01-02" }}
dnd/ref/characters:
dnd/ref/locations:
  - {{ default .Name .Site.Params.Name | title }}
tags:
title: {{ default .Name .Site.Params.Name | title }}

---

## Map

![location.png](/images/dnd/location.png)

## Key Info

