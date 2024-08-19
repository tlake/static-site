---

date: 2024-08-19
tags:
  - mariadb
  - microk8s
  - nfs
  - postgres
  - raspberry pi
  - sqlite
  - traefik
  - traefik v3
title: "Microk8s Cluster: Databases and NFS Storage"
toc: true
url: /blog/microk8s-cluster-databases-and-nfs-storage

---

## File lock requirements

With the NFS k8s storage class working and Traefik up and running, it was time to try and stand up some application containers on the new thicket (my microk8s cluster running on four Raspberry Pis).
I was able to get the whoami container up and routed to, but I ran into issues with actualbudget, and then vaultwarden, where the startup process to initialize the sqlite database would hang for a long time and then error with a message about the database being busy.
After some digging I found [this stackoverflow question](https://stackoverflow.com/questions/9907429/locking-sqlite-file-on-nfs-filesystem-possible) about trying to use sqlite over NFS, and an answer to that question links to [the sqlite docs](https://www.sqlite.org/faq.html#q5) which say:

> **(5) Can multiple applications or multiple instances of the same application access a single database file at the same time?**
>
> Multiple processes can have the same database open at the same time. Multiple processes can be doing a SELECT at the same time. But only one process can be making changes to the database at any moment in time, however.
>
> SQLite uses reader/writer locks to control access to the database. (Under Win95/98/ME which lacks support for reader/writer locks, a probabilistic simulation is used instead.) But use caution: this locking mechanism might not work correctly if the database file is kept on an NFS filesystem. This is because fcntl() file locking is broken on many NFS implementations. You should avoid putting SQLite database files on NFS if multiple processes might try to access the file at the same time. On Windows, Microsoft's documentation says that locking may not work under FAT filesystems if you are not running the Share.exe daemon. People who have a lot of experience with Windows tell me that file locking of network files is very buggy and is not dependable. If what they say is true, sharing an SQLite database between two or more Windows machines might cause unexpected problems.
> 
> We are aware of no other embedded SQL database engine that supports as much concurrency as SQLite. SQLite allows multiple processes to have the database file open at once, and for multiple processes to read the database at once. When any process wants to write, it must lock the entire database file for the duration of its update. But that normally only takes a few milliseconds. Other processes just wait on the writer to finish then continue about their business. Other embedded SQL database engines typically only allow a single process to connect to the database at once.
>
> However, client/server database engines (such as PostgreSQL, MySQL, or Oracle) usually support a higher level of concurrency and allow multiple processes to be writing to the same database at the same time. This is possible in a client/server database because there is always a single well-controlled server process available to coordinate access. If your application has a need for a lot of concurrency, then you should consider using a client/server database. But experience suggests that most applications need much less concurrency than their designers imagine.
>
> When SQLite tries to access a file that is locked by another process, the default behavior is to return SQLITE_BUSY. You can adjust this behavior from C code using the sqlite3_busy_handler() or sqlite3_busy_timeout() API functions.

### Vaultwarden

The vaultwarden container can be configured to use several different database backends.
I learned that mariadb has the same file lock problems as sqlite, but postgres was successfully able to start up and run!

[These vaultwarden docs](https://github.com/dani-garcia/vaultwarden/wiki/Using-the-PostgreSQL-Backend) were able to get me through configuring the container, as well as migrating my data from the old sqlite database running on docker swarm to the new postgres database.

#### Migrating

Starting with the previous sqlite-backed container and a fresh new postgres-backed container, both running:

- Stop the sqlite-backed container
- [Install pgloader](https://pgloader.readthedocs.io/en/latest/install.html) (I built from source on MacOS)
- [Disable WAL on the sqlite database](https://github.com/dani-garcia/vaultwarden/wiki/Running-without-WAL-enabled#1-disable-wal-on-old-db) (in my case, the sqlite database was small enough that I copied it out of the docker volume to a local directory):
    - `sqlite3 db.sqlite3`
    - `sqlite> PRAGMA journal_mode=delete;`
    - `.quit`
- Forward the new postgres-backed container's postgres port to the local machine:
    - `k -n vaultwarden port-forward service/postgres 5432`
- Create a `vaultwarden.load` file:
    - ```
      load database
           from sqlite://path/to/db.sqlite3 
           into postgresql://yourpgsqluser:yourpgsqlpassword@localhost:5432/yourpgsqldatabase
           WITH data only, include no drop, reset sequences
           EXCLUDING TABLE NAMES LIKE '__diesel_schema_migrations'
           ALTER SCHEMA 'bitwarden' RENAME TO 'public'
      ;
      ```
- Run `pgloader vaultwarden.load` to do the migration

### Actualbudget

It seems like the actualbudget container doesn't have the functionality to change the underlying database, so I'm stuck with sqlite for now.
In order to get it to run on the thicket, I needed to change the PersistentVolumeClaim's storage class from `nfs-client` to `microk8s-hostpath`:

```yaml
# persistent-volumes.yaml

kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: "data"
spec:
  storageClassName: "microk8s-hostpath"
  accessModes:
    - ReadWriteOncePod
  resources:
    requests:
      storage: "10Mi"
```

I'll need to work out a separate solution to back up this data.

## `no_root_squash`

I also encountered some file permission issues with the postgres container, and the quickest fix was setting `no_root_squash` in the fs export configuration.
This allows a client mounting the NFS share to assume root privileges, which is dangerous, but the shares are at least locked down to IP so it's Safe Enough™ for now.

```
# file '/etc/exports' on the NAS machine

# only the thicket nodes IPs are allowed to mount the share with `no_root_squash`:
/nas/data/thicket-k8s-data *(ro,sync,subtree_check) 192.168.0.131(rw,sync,subtree_check,no_root_squash) 192.168.0.132(rw,sync,subtree_check,no_root_squash) 192.168.0.133(rw,sync,subtree_check,no_root_squash) 192.168.0.134(rw,sync,subtree_check,no_root_squash)
```

(remember to run `exportfs -a` after editing `/etc/exports`)

There's likely a better way to handle permissions for the postgres container, but I haven't spent enough time to figure it out yet.

