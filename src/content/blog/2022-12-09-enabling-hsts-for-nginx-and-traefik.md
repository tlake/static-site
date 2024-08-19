---

date: 2022-12-09
tags:
  - docker
  - docker swarm
  - traefik
  - nginx
  - hsts
title: Enabling HSTS for NginX and Traefik
url: /blog/enabling-hsts-for-nginx-and-traefik

---

So, I have a small hodgepodge of a home lab consisting of my primary desktop PC ("artemicion"), an Udoo Bolt ("bolt"), and a Raspberry PI 4 ("mansionsyrup").
I've got them networked together in a Docker swarm, with mansionsyrup as the leader.
One of the biggest responsibilities of mansionsyrup is to run a Traefik container, which handles routing traffic across my other Docker containers, wherever in the swarm they may be running.

A housemate wanted to make their FoundryVTT instance accessible from the internet (much like my own Foundry instance is), but didn't want to connect their machine to the Docker swarm.
After a little bit of research that seemed to indicate that Traefik could not be configured to use both a static config file in parallel with dynamic label-based configuration (which ruled out writing a static route), I decided I could simply run an NginX container that proxied traffic to their machine, and use the labels on the NginX container to convince Traefik to route from their domain through to the NginX container (and from there to their machine running Foundry).

They chose and purchased a `.dev` domain, and after adding an A record pointing to our home IP, it was on me to configure Traefik and NginX.
Seemed simple.
I added some labels to the NginX container, wrote a quick little NginX config file to proxy traffic to their IP, and that was the end of it!

JK. It turns out that all `.dev` domains are on something called the HSTS preload list, which means that Chrome and Firefox, at least, will require some specific security headers, and for traffic to only move over HTTPS - no HTTP allowed.

HTTPS was a solved problem - I've set up Traefik already to automatically generate LetsEncrypt certificates for my containers.
The HSTS headers were new to me, though.
It took a few hours, but here's a summary of what ended up working for me.

**EDIT:** In a previous version of this post, I had been adding the STS headers to both the NginX container's labels as well as in the NginX config file's `location /` block.
I did this because after writing the container's middleware labels, my browsers still refused to connect to NginX, and [this HSTS header analyzer tool](https://geekflare.com/tools/hsts-test) still told me that the headers were missing.
I thought that perhaps servers behind Traefik also needed to configure these headers, so I added them to NginX as well, and then the site resolved properly.
However, I was an idiot - although I had written the correct middleware labels, I _hadn't_ associated the middleware with the container's Traefik router, so those headers weren't being applied at all.
After I correctly connected the HSTS middleware to the router, I was able to omit the HSTS configuration from the NginX file and the site was still HSTS compliant.

## Traefik Labels on the NginX Container's Compose File

```yaml
version: "3"

services:
  app:
    deploy:
      labels:
        traefik.enable: "true"

        # These are the HSTS headers I needed to add:
        traefik.http.middlewares.home-proxy.headers.browserxssfilter: "true"
        traefik.http.middlewares.home-proxy.headers.forcestsheader: "true"
        traefik.http.middlewares.home-proxy.headers.framedeny: "true"
        traefik.http.middlewares.home-proxy.headers.stsincludesubdomains: "true"
        traefik.http.middlewares.home-proxy.headers.stspreload: "true"
        traefik.http.middlewares.home-proxy.headers.stsseconds: "31536000"

        traefik.http.routers.home-proxy.entrypoints: "web, websecure"

        # And this is where I connect the middleware to the router
        # (this is the crucial step I originally missed)
        traefik.http.routers.home-proxy.middlewares: "home-proxy"

        traefik.http.routers.home-proxy.rule: "Host(`cooldomain.dev`)"
        traefik.http.routers.home-proxy.tls: "true"
        traefik.http.routers.home-proxy.tls.certresolver: "production"
        traefik.http.services.home-proxy.loadbalancer.server.port: 80

      mode: "replicated"
      replicas: 1
      restart_policy:
        condition: "any"
      placement:
        constraints:
          - "node.hostname == bolt"
    image: "nginx:stable-alpine"
    networks:
      - "home"
    ports:
      - "11080:80"
      - "11443:443"
    volumes:
      - "app_config:/etc/nginx/:ro"

networks:
  # This assumes that the "home" network is an already-existing
  # user-defined overlay network that Traefik routes across.
  home:
    external:
      name: "home"

volumes:
  app_config:
```

