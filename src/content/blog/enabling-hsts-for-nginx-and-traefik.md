---
date: 2022-12-09
title: Enabling HSTS for NginX and Traefik
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

## Traefik Labels on the NginX Container's Compose File

```yaml
version: "3"

services:
  app:
    deploy:
      labels:
        traefik.enable: "true"
        traefik.http.routers.home-proxy.entrypoints: "web, websecure"
        traefik.http.routers.home-proxy.rule: "Host(`cooldomain.dev`)"
        traefik.http.routers.home-proxy.tls: "true"
        traefik.http.routers.home-proxy.tls.certresolver: "production"
        traefik.http.services.home-proxy.loadbalancer.server.port: 80
		#
		# The following are the HSTS headers I needed to add:
		#
        traefik.frontend.headers.STSSeconds: "31536000"
        traefik.frontend.headers.STSIncludeSubdomains: "true"
        traefik.frontend.headers.STSPreload: "true"
        traefik.http.middlewares.hsts.headers.framedeny: "true"
        traefik.http.middlewares.hsts.headers.browserxssfilter: "true"
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

## NginX Config File

This file lives at `/etc/nginx/nginx.conf` in the NginX container.
Specifically, within that volume `app_config` on the host machine defined above which is mounted as `/etc/nginx` in the container.

```nginx
user  nginx;
worker_processes  auto;

error_log  /var/log/nginx/error.log notice;
pid        /var/run/nginx.pid;

events {
    worker_connections  1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile        on;
    keepalive_timeout  65;

    include /etc/nginx/conf.d/*.conf;

    server {
        listen 80 default_server;
        listen 443 default_server;

        # Sets the Max Upload size to 299 MB
        client_max_body_size 300M;

        # Proxy Requests to Foundry VTT
        location / {
            # Set proxy headers
            proxy_set_header Host $host;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;

            # These are important to support WebSockets
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "Upgrade";

            # Make sure to set your Foundry VTT port number
            proxy_pass http://HOUSEMATE_IP:30001;

			# HSTS Header
            add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
        }
    }
}
```

