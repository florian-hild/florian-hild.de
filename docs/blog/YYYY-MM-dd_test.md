---
title: "Running docker inside an unprivileged LXC container on Proxmox"
comments: True
date_published: 2021-03-25
---

**TL;DR** This is a brief description of the setup process for running docker in
unprivileged LXC containers on proxmox. There are two primary sources,
one is <cite>a post on Reddit[^1]</cite> and <cite>a more general discussion[^2]</cite> on
linuxcontainers.org.

-----

??? "**Motivation**"
    Docker containers can be useful, even though Proxmox LXC containers offer the same set
    of functions.

    For example, I prefer Docker over LXC, where official pre-defined `docker-compose.yml`s
    exist and are suggested in documentations.

    However, there is some confusion about running Docker inside Proxmox.

    Several sources
    suggest that Docker can only be run inside a full VM, or a privileged LXC container,
    with full access to the host system.

    Usually, this will be the wrong approach.

    Full VMs in Proxmox consume reserved system resources such as CPU, Memory etc.
    An unprivileged LXC container, however, will share available resources with
    all other containers on the host.

    This means, if the total available Memory on the
    <abbr title="The host machine (e.g. Proxmox)">Hypervisor</abbr>
    is 32 GB, it is entirely possible to create several LXC containers and make
    32 GB of memory available to each of them. The total available memory will be shared.

??? "When to not use Docker in unprivileged LXC"
    Full VMs are officially recommended for Docker, over running inside unprivileged containers.
    One of the main reasons is that VMs are fully virtualized, whereas LXC containers simply
    run all processes using the host (the hypervisor). Unprivileged containers use a combination
    of app-armor rules and uid-mapping to prevent any malicious access to the host, but if you
    are doing serious production work or you know that your Docker tools may be insecure,
    use a VM instead of LXC.

??? note "Docker on native LXC?"
    If you came here, looking for a way to get Docker to run on native LXC
    (without Proxmox), this guide will not work. See a blog post that
    describes the major differences here. [^8]

This guide has been verified to work with Proxmox 5.4 to 7.2-3,
for both Ubuntu 21.10 and Debian 11 LXC Templates. If you are
using a different setup, <abbr title="Your Mileage May Vary">YMMV</abbr>.

-----

<!--more-->

## Prepare Proxmox

<br>

On Proxmox, the `overlay` and `aufs`\* Kernel modules must be enabled
to support Docker-LXC-Nesting.


    echo -e "overlay\naufs" >> /etc/modules-load.d/modules.conf


Reboot Proxmox and verify that the modules are active:

    lsmod | grep -E 'overlay|aufs'

!!! Note "\* Note"
    Starting with Proxmox 7, the `aufs` module seems deprecated and is
    not needed anymore. It will not be loaded, even if it is added to
    `modules.conf` [^7]

## Create an unprivileged LXC container

<br>

Follow the [Proxmox docs](https://pve.proxmox.com/wiki/Unprivileged_LXC_containers)
to create an unprivileged LXC container, either through the web UI or using the shell.

??? "Example LXC settings"

    - Download Debian 11 Bullseye CT Template
    - Create new Directory Storage `storagedocker`
    - Create unprivileged LXC container:
        - hostname: `docker`
        - CT ID: `100`
        - add ssh public key
        - Root Disk: `storagedocker`
        - Disk Size: `60` GB
        - CPU: `2`
        - Memory: `4096`
        - Network:
            - `vmbr1` (Service Network)
            - IPv4/CIDR: `192.168.40.9/24`
            - Gateway: `192.168.40.1`
            - VLAN tag `40`
        - DNS:
            - Domain local.mytld.com
            - DNS: `192.168.40.1`

This LXC container config will be stored at:

```
/etc/pve/lxc/100.conf
```

Open this config and add:
```
features: keyctl=1,nesting=1
```

Alternatively, use the Proxmox gui to enable these options.

Afterwards, the `100.conf` will look similar to this:
```yaml
arch: amd64
cores: 2
features: keyctl=1,nesting=1
hostname: docker
memory: 4096
nameserver: 192.168.40.1
net0: name=eth0,bridge=vmbr1,firewall=1,gw=192.168.40.1,ip=192.168.40.9/24,tag=40,type=veth
ostype: debian
rootfs: storagedocker:100/vm-100-disk-0.raw,size=60G
searchdomain: local.mytld.com
startup: order=1
swap: 4096
unprivileged: 1
```

## Setup Docker in LXC

<br>

Now, login to the newly created LXC container via ssh.

Optionally install sudo:
```bash
apt install sudo
```

Set time zone. In unprivileged containers, use:
```bash
dpkg-reconfigure tzdata
```

Update all packages:
```
apt-get update && apt-get upgrade && apt-get dist-upgrade && apt-get autoremove
```

Install Docker. This is from [the docs](https://docs.docker.com/engine/install/debian/#install-using-the-repository)
for Debian.
```bash
sudo apt-get install \
    ca-certificates \
    curl \
    gnupg \
    lsb-release
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io
```

!!! note
    Always check the official instructions from the docs, for outdated code, before copy & paste.

Change the storage driver to overlay2.

```bash
echo -e '{\n  "storage-driver": "overlay2"\n}' >> /etc/docker/daemon.json
```

??? "Adjust Docker subnets"
    Keep an eye open if you have subnets in the `192.168.0.0` range.
    This range is among the list of subnets that docker may select for the
    default_network. See issue [#37823](https://github.com/moby/moby/issues/37823).

    It is possible to remove `192.168.0.0` from this list, by updating `daemon.json`, e.g.:
    ```json
    {
        "storage-driver": "overlay2",
        "bip": "193.168.1.5/24",
        "default-address-pools":
        [
            {"base":"172.17.0.0/16","size":24}
        ]
    }
    ```

Optionally install `docker-compose`. Follow [the docs](https://docs.docker.com/compose/install/#install-compose-on-linux-systems).

## Test Docker

<br>

Restart the LXC container and test Docker setup.

```bash
systemctl status docker
docker run hello-world
```

> Hello from Docker!

Yay!

## ZFS

For ZFS, a few additional steps are required to get Docker running inside unprivileged LXCs.

Docker requires root privileges to use ZFS. Since we are running Docker inside an unprivileged LXC,
file-system permissions are missing for Docker in `/var/lib/docker`.

There are two workarounds.

The first is to create a ZFS volume formatted as `ext4` or `xfs`, and changing ownership to the unprivileged root user,
which I am showing below. This approach was first described in <cite>a post on Reddit[^4]</cite>. See also [this Ansible playbook](https://github.com/alexpdp7/ansible-create-proxmox-host#docker-setup).

??? "Second option: fuse-overlayfs[^5]"

    This requires adding FUSE as advanced feature in the LXC and mounting `/dev/fuse`
    to the container. If you want to follow this road, have a look at this guide.[^6]

    I decided against fuse-overlayfs, since I am not familiar with this file system and
    there are [possible](https://discuss.linuxcontainers.org/t/security-of-fuse-overlayfs-with-lxc-unprivileged/10145/2)
    <abbr title="Interactions between fuse and the freezer cgroup can potentially cause I/O deadlocks.">issues</abbr>
    with performance and reliability.

**Prepare replacing `/var/lib/docker` with a ZFS volume mount**

In the container:
```
service docker stop
cp -au /var/lib/docker /var/lib/docker.bk
rm -rf /var/lib/docker/*
```

Shutdown the LXC.

On Proxmox, I am assuming ZFS is already set up. Check available mounts and zfs datasets:
```
zfs mount
zpool status -v
zfs list
```

- ZFS is hierarchically organized in datasets.
- My zfs pool is called `tank_ssd` (a ZFS Mirror consisting of SSDs).
- In `tank_ssd`, I created an encrypted and compressed ZFS dataset called `lxc`.

The command below will create a new ZFS volume stored in `tank_ssd/lxc/docker`.

```bash
zfs create -s -V 8G tank_ssd/lxc/docker
zfs get volsize,referenced tank_ssd/lxc/docker
```
```
> NAME                 PROPERTY    VALUE     SOURCE
> tank_ssd/lxc/docker  volsize     8G        local
> tank_ssd/lxc/docker  referenced  88K       -
```

ZFS volumes are comparable to partitions and can be
formatted with any file system. I prefer to use `XFS` over `ext4`,
but both will work.

Format as xfs:
```bash
mkfs.xfs /dev/zvol/tank_ssd/lxc/docker
```

In order for Docker to be able to write to this volume,
you either need to provide uid-mappings, or change the
ownership to the unprivileged root user (uid `100000`).

The latter can be done by mounting the volume into a temporary
location (on Proxmox) and changing permissions:
```bash
mkdir /tmp/zvol_tmp
mount /dev/zvol/tank_ssd/lxc/docker /tmp/zvol_tmp
chown -R 100000:100000 /tmp/zvol_tmp
df -Th /dev/zvol/tank_ssd/lxc/docker
```
```bash
> Filesystem     Type  Size  Used Avail Use% Mounted on
> /dev/zd64      xfs   8.0G   90M  8.0G   2% /tmp/zvol_tmp
```

!!! Note
    Even though this ZFS volume is formatted as XFS, all ZFS features
    are still available, such as snapshots, encryption, compression, or
    sparse provisioning (meaning that the volume will only
    occupy the space that is actually used).

Unmount:
```bash
umount /tmp/zvol_tmp
```

Add the mount point to your unprivileged LXC config.
```bash
nano /etc/pve/lxc/100.conf
mp0: /dev/zvol/tank_ssd/lxc/docker,mp=/var/lib/docker
```

Start the LXC and check the Docker service inside the container:
```bash
systemctl status docker
```
```bash
> ● docker.service - Docker Application Container Engine
>      Loaded: loaded (/lib/systemd/system/docker.service; enabled; vendor preset: enabled)
>      Active: active (running) since Sun 2022-01-02 10:14:39 CET; 30s ago
```

You will notice a warning in the Docker logs:

> Not using native diff for overlay2, this may cause degraded performance for building images: running in a user namespace

This is only relevant if you are building lots of Docker images (e.g. a Gitlab Runner). In this case, use a native VM if
you need the performance.

You will see similar warning on the Proxmox host.

??? "`dmesg -wHT`"
    ```
    [Sun Mar  6 14:14:46 2022] overlayfs: upper fs does not support RENAME_WHITEOUT.
    [Sun Mar  6 14:14:46 2022] overlayfs: upper fs missing required features.
    [Sun Mar  6 14:14:47 2022] overlayfs: fs on '/var/lib/docker/check-overlayfs-support065203116/lower2' does not support file handles, falling back to xino=off.
    [Sun Mar  6 14:17:12 2022] overlayfs: fs on '/var/lib/docker/overlay2/check-overlayfs-support656562844/lower2' does not support file handles, falling back to xino=off.
    ```

I haven't seen any negative consequences, even for more complex Docker images such as Gitlab or mailcow-dockerized.

In the container, check the storage driver that is used.
```bash
docker info | grep -A 7 "Storage Driver:"
```
```bash
> Storage Driver: overlay2
>  Backing Filesystem: xfs
>  Supports d_type: true
>  Native Overlay Diff: false
>  userxattr: true
> Logging Driver: json-file
> Cgroup Driver: systemd
> Cgroup Version: 2
```

## Conclusions

<br>

Now, what is neat about this setup is that it is entirely possible to have several
LXC containers that run separate Docker systems.

For example, I use the above Docker LXC for hosting stable services in the local
service network VLAN.

In another LXC container, I have Docker setup for experimental
containers, with quick access to `docker system prune --all && docker volume prune`.

The performance of this Docker-LXC-nesting is negligible, since all resources are
shared and running Docker containers do not consume resources, if they are not active.

## Caveats

### Backups

Having `/var/lib/docker` in a separate mount point (for LXC+ZFS) will
exclude all docker containers from the native Proxmox backup.

Of course, Proxmox Backups can be avoided with ZFS Snapshots. However,
for archiving purposes, I prefer having `tar.zst` files of all LXC containers.

A solution here is to move all persistent data to the LXC, so that anything in
`/var/lib/docker` (e.g. containers, volumes) does not need to be backed up.

There is a system for setting up Docker containers I have followed since
seeing it in the [Funkwhale-docs](https://docs.funkwhale.audio/installation/docker.html).

Based on this system, the example below will go a bit beyond what it absolutely needed,
but I have seen too many bad Docker container setups.

??? "**Example docker setup: Miniflux**"

    The Funkwhale Docker Setup is based on the idea that for each service,
    a specific user (with matching name) is created and added to the
    docker group.

    In the example here, this is applied to Miniflux, a great feedreader.

    Have a look at the Docker setup of [Miniflux](https://miniflux.app/).

    Create a user with the name `miniflux`, and a home folder with the same name in `/srv/`,
    and add it to the docker group.
    ```bash
    mkdir /srv/
    sudo useradd -r -s /sbin/nologin -m -d /srv/miniflux -U -G docker miniflux
    ```

    Login as the user.
    ```bash
    sudo -u miniflux -H bash
    cd /srv/miniflux
    ```

    Create two folders, one for the persistent data and one for the docker configuration:
    ```bash
    mkdir -p data/miniflux-db
    mkdir docker
    cd docker
    nano docker-compose.yml
    ```

    Use the [official](https://miniflux.app/docs/installation.html#docker) example docker-compose.yml for Miniflux,
    but change the volume (`miniflux-db`) to a mount point for the Postgres database (`/srv/miniflux/data/miniflux-db`).

    ??? "Example `docker-compose.yml`"
        ```yml
        version: '3'

        services:
        miniflux:
            image: miniflux/miniflux:latest
            restart: unless-stopped
            ports:
            - "127.0.0.1:18080:8080"
            depends_on:
            db:
                condition: service_healthy
            networks:
            - miniflux
            environment:
            - DATABASE_URL=postgres://${DB_USER:-miniflux}:${DB_SECRET:-eX4mP13p455w0Rd}@db/miniflux?sslmode=disable
            - CLEANUP_ARCHIVE_UNREAD_DAYS=2
            - CLEANUP_ARCHIVE_READ_DAYS=2
            - POLLING_FREQUENCY=180
            - BASE_URL=https://flux.forst.alexanderdunkel.com/
        db:
            image: postgres:13
            restart: unless-stopped
            environment:
            - POSTGRES_USER=${DB_USER:-miniflux}
            - POSTGRES_PASSWORD=${DB_SECRET:-eX4mP13p455w0Rd}
            volumes:
            - /srv/miniflux/data/miniflux-db:/var/lib/postgresql/data
            networks:
            - miniflux
            healthcheck:
            test: ["CMD", "pg_isready", "-U", "${DB_USER:-miniflux}"]
            interval: 10s
            start_period: 30s

        networks:
        miniflux:
            name: ${NETWORK_NAME:-miniflux-network}
        ```

        You see that I removed the volume part:
        ```
        volumes:
          miniflux-db:
        ```

    Startup the docker:
    ```bash
    cd ~/docker
    docker-compose up -d && docker-compose logs --follow --tail 100
    ```

    Now, there is no need to backup `/var/lib/docker` using this setup,
    since all persistent data is stored in `/srv/miniflux/data`. The
    docker volume mount only contains base OS images, which do not need
    to be backed up.

    A benefit of this setup is that you have everything together to
    restore individual services. The directory `/srv/miniflux/data` will
    be backed up with the standard Proxmox LXC backup to `tar.zst` and
    can be started with the corresponding `docker-compose.yml`, even if
    the docker system (`/var/lib/docker`) has been cleaned or pruned. In this case,
    docker will automatically pull missing images and startup the service
    with the persistent data from `/srv/miniflux/data`.

### Migrations

Special care and possibly manual work is necessary in case of Docker+ZFS for migrations (
e.g. between nodes, clusters etc.). Since I am running a single node Proxmox
Cluster, I have no information to provide here. Please add your experiences
in the comments.

### Special container permissions

Except for one case (see below),
I did not have any issues with this setup for over a year now, running
several unprivileged LXC containers with individual docker hosts alongside.

??? "Gitlab Docker: open /proc/sys/kernel/domainname: permission denied"

    Keep an eye out for Docker setups that require access to special system resources.
    The only time this happened to me was with the Gitlab docker, and <cite>it was easy to solve.[^3]</cite>

    Gitlab tried to modify the sysctl domainname, which is not allowed in unprivileged LXC containers.
    Removing `hostname` from the `docker-compose.yml` solved this issue.

??? "**Changelog**"

    2022-05-05

    - Confirm Proxmox 7.2 compatibility

    2022-05-04

    - Add note for deprecated `aufs` kernel module
    - Add note for migrations

    2022-03-06

    - Add instructions for ZFS
    - Test with Debian, Ubuntu
    - Update instructions for Proxmox 7.1
    - Update reference to fuse-overlayfs
    - add example docker setup for Miniflux

    2021-03-25 Initial post

[^1]: The core of this content appeared
      [in a post on reddit](https://www.reddit.com/r/Proxmox/comments/g3wozs/best_way_to_run_docker_in_proxmox/fnu3t51?utm_source=share&utm_medium=web2x&context=3),
      April 19, 2020.
[^2]: Setup of chore comes from [a general discussion](https://discuss.linuxcontainers.org/t/working-install-of-docker-ce-in-lxc-unprivileged-container-in-proxmox/3828)
      on linuxcontainers.org
[^3]: Gitlab domainname issue on unprivileged LXC [#743#issuecomment-860164507](https://github.com/docker/for-linux/issues/743#issuecomment-860164507)
[^4]: Docker in unprivileged LXC using a formatted ZFS subvolume [r/Proxmox](https://www.reddit.com/r/Proxmox/comments/lsrt28/easy_way_to_run_docker_in_an_unprivileged_lxc_on/)
[^5]: fuse-overlayfs [github.com/containers/fuse-overlayfs](https://github.com/containers/fuse-overlayfs)
[^6]: How to setup Docker with fuse-overlayfs in Proxmox LXC container [c-goes.github.io](https://c-goes.github.io/posts/proxmox-lxc-docker-fuse-overlayfs/)
[^7]: Deprecated aufs module [Proxmox Forums](https://forum.proxmox.com/threads/lxc-with-docker-have-issues-on-proxmox-7-aufs-failed-driver-not-supported.97851/)
[^8]: Docker on native LXC [jlu5.com Blog](https://jlu5.com/blog/docker-unprivileged-lxc-2021)