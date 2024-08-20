---

date: 2024-08-20
tags:
  - microk8s
  - nfs
  - raspberry pi
  - raspberry thicket
  - rsync
  - sqlite
  - sqlite3
  - traefik
title: "Microk8s Cluster: SQLite Backups Using RSYNC"
toc: true
url: /blog/microk8s-cluster-sqlite-backups-using-rsync

---

## Problem statement

I have a NAS server running on a Raspberry Pi with automatic backups.
That Pi also acts as an NFS server, and the thicket (my Raspberry Pi microk8s cluster) uses the `nfs-client` storage driver to create persistent volume claims so that the thicket can take advantage of the automatic backups as well.

However, some workloads don't work with this setup: in particular, sqlite and mariadb databases utilize file locking in a manner unsupported by NFS volumes, so I can't take advantage of that automatic backup with any volumes used by these databases.
Instead, these volumes leverage the default `microk8s-hostpath` storage class and store their data on the thicket node(s) directly.

I need an alternative solution to backup these database workloads to my NAS drive.

## Enter rsync

We'll configure an additional container in my deployment running this [ogivuk/rsync-docker](https://github.com/ogivuk/rsync-docker) image, and leverage `cron` to periodically `rsync` data from the `microk8s-hostpath` volume to a new `nfs-client` volume.

I'll be using a deployment of actualbudget in the example below.

### The persistent volume claims

There are three volume claims we'll need to define:
- "data": which is used by the primary workload (actualbudget and its sqlite database)
  - this is the `microk8s-hostpath` volume that we need to back up
- "backup": the `nfs-client` volume where the rsync container will write the backup(s) to
- "rsync": where we'll put the cron script that will define the backup command and schedule

```yaml
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: "data"
spec:
  storageClassName: "microk8s-hostpath"
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: "10Mi"

---

kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: "backup"
spec:
  storageClassName: "nfs-client"
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      # since this is essentially a copy of "data" above,
      # it should be the same size.
      storage: "10Mi"

---

kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: "rsync"
spec:
  storageClassName: "nfs-client"
  accessModes:
    - ReadOnlyMany
  resources:
    requests:
      storage: "2Mi"
```

### The deployment

```yaml
kind: Deployment
apiVersion: apps/v1
metadata:
  name: "actualbudget"
  labels:
    app: "actualbudget"

spec:
  replicas: 1
  revisionHistoryLimit: 1
  selector:
    matchLabels:
      app: "actualbudget"
  template:
    metadata:
      labels:
        app: "actualbudget"
    spec:
      containers:
        - name: "actualbudget"
          env:
          image: "docker.io/actualbudget/actual-server:latest"
          ports:
            - name: "app"
              containerPort: 5006
          volumeMounts:
            - name: "data"
              mountPath: "/data"

        - name: "rsync"
          env:
            # define the name of the crontab file we'll supply:
            - name: "RSYNC_CRONTAB"
              value: "crontab"
            - name: "TZ"
              value: "America/Los_Angeles"
          image: "ogivuk/rsync:latest"
          volumeMounts:
            - name: "backup"
              mountPath: "/data/destination"

            # this is the application's volume, where the sqlite database
            # is stored. we'll mount it read-only just to make sure that
            # the rsync container doesn't accidentally modify it somehow.
            - name: "data"
              mountPath: "/data/source"
              readOnly: true

            - name: "rsync"
              mountPath: "/rsync"

      volumes:
        - name: "data"
          persistentVolumeClaim:
            claimName: "data"

        - name: "backup"
          persistentVolumeClaim:
            claimName: "backup"

        - name: "rsync"
          persistentVolumeClaim:
            claimName: "rsync"
```

### The crontab file

This file will need to be copied into the "rsync" volume that the rsync container will create.

We'll keep it simple, and just copy everything within `/data/source/` (this is the application's `microk8s-hostpath` volume) into `/data/destination/`.

```bash
50 * * * * rsync -a /data/source/* /data/destination/
```

Name it `crontab`, copy it into the `rsync` volume (after the pod is deployed at least once to create the volume in the first place), and then restart the pod.

## Conclusion

We can replicate this pattern for other workloads in other namespaces now!
If we have multiple applications/deployments in a single namespace, we need only deploy a single rsync container and we can mount multiple volumes and configure their backups with cron.
For deployments separated by namespaces, we'll need to replicate the rsync setup within each namespace, since volumes can't cross namespace boundaries.

