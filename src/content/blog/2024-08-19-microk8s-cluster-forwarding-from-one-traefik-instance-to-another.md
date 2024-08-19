---

date: 2024-08-19
tags:
  - microk8s
  - raspberry pi
  - traefik
  - traefik v3
title: "Microk8s Cluster: Forwarding From One Traefik Instance To Another"
toc: true
url: /blog/microk8s-cluster-forwarding-from-one-traefik-instance-to-another

---

## Starting state

- Docker swarm
    - Traefik (current front door)
        - Running on the primary/manager swarm node
        - Exposed via static IP
    - Current container applications
- Microk8s cluster (the "thicket")
    - Traefik (future front door)
        - Able to run on any node in the thicket
        - Exposed via k8s service allocating a static IP through metallb
    - New container applications
- Home router forwarding all incoming :80 and :443 traffic to the docker swarm's manager node's static IP address

## What I don't want

- Switching between routing **all** web traffic to _either_ the swarm traefik _or_ the thicket traefik
- Fully migrating every application before switching traffic as above, then troubleshooting every application at the same time

## What I do want

- Migrating applications one at a time from the docker swarm to the thicket
- Testing/troubleshooting a single migrated application without interrupting other applications
- Maintaining availability for applications not yet migrated

## The solution: a TCP router and service in the dynamic config file

Make sure the static config has the file provider enabled:

```yaml
# /etc/traefik/traefik.yaml

# ...

providers:
  file:
    directory: "/etc/dynamic-config"

# ...
```

Restart the traefik container after editing the static config for it to take effect.

Add the necessary configuration in a dynamic config file (solution originally found [on reddit](https://www.reddit.com/r/Traefik/comments/k79hjt/how_to_proxy_from_one_traefik_instance_to_another/).
This file can be named whatever, as long as it's yaml and as long as it's available in that dynamic directory defined just above.

```yaml
# /etc/dynamic-config/thicket-traefik.yaml

tcp:
  routers:
    thicket:
      rule: "HostSNI(`MY.EXAMPLE.HOST`)"
      service: "thicket"
      tls:
        passthrough: "true"

  services:
    thicket:
      loadBalancer:
        servers:
          - address: "NEW.TRAEFIK.IP.HERE:443"
```

If `providers.file.watch: true` is set and functioning properly in the static config, there's no need to reload traefik again at this step.

Now I can continue to extend that `HostSNI` rule for every migrated application, once it's configured and working in the thicket behind the new traefik instance.
Eventually, once everything is migrated over and the swarm traefik instance is doing nothing but forwarding to the thicket, it can be deprecated and I can configure my router to push all :80 and :443 traffic to the thicket traefik service's IP.

