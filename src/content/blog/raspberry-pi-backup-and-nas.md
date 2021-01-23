---
draft: true
title: "Raspberry Pi: Backup and NAS"
date: 2019-12-07T10:07:06-08:00
toc: true,
tags: [
    "raspberry pi",
    "nas",
    "backup",
    "rsync",
    "private cloud",
    "privacy",
]
---

As part of an effort to take back some amount of control of my own data from the cloud giants (unfortunately I'm talking more about the Googles of the world and less about the gigantic humanoids situated near the top of the [Ordning](https://forgottenrealms.fandom.com/wiki/Ordning_(social_structure))), one of the first tasks I wanted to tackle was just a simple, redundant storage solution for my data.

## The Ingredients

- Raspberry Pi 4
  - good microSD card
  - case with fan
  - power cable with convenient on/off switch

- 2 x 10TB USB hard drives (independent power supplies)

## The Overview

The Raspberry Pi serves as the controller for two 10TB external hard drives connected via USB. One of these drives is a data drive, intended to be used and managed, and the other of these drives stores archival backup copies of the data drive. The Pi exposes the data drive as a NAS device via the NFS protocol on my local network. `cron` is used to schedule backups on a daily basis, and `rsync` is used to create the backups of the data drive with its `--link-dest` flag to minimize the storage footprint of individual backup archives by writing only the difference from the previous backup.

## The Process

### 1. Make the Pi Operational

Before we can do much of anything, we have to get the Raspberry Pi up and running. There are a world of tutorials easy found by searching around on the internet, so I'm only going to talk about some of the key points here.

For the operating system, I just downloaded the latest Raspbian Buster image from raspberrypi.org (update: Raspbian has become Raspberry Pi OS) and Balena Etcher, then used Etcher to flash the image onto a microSD card.

Before booting up the Pi for the first time, however, there are a couple of important things to do. First, I wrote a blank file called `ssh` into the `boot/` directory of the microSD card in order to enable SSH access from the get-go. This way I don't ever have to fuss with connecting a keyboard and display to the Pi - at least, as long as the Pi can automatically connect to my local network so I can look up its IP address from my router. I could connect it to the router manually with a cable, but I'd rather pre-configure the Pi with my Wi-Fi information so I don't even have to do that.

To make that happen, we need to create a second file to add to the microSD card: it's called `wpa_supplicant.conf`, and it will also live within `boot/`. We need to add some information to this file, however, and it will look something like this:

```bash
country=US
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1

network={
    ssid="WIFI_NAME_HERE"
        psk="WIFI_PASSWORD_HERE"
    key_mgmt=WPA-PSK
}
```

Of course, `WIFI_NAME_HERE` needs to be replaced with the name of your Wi-Fi network, and `WIFI_PASSWORD_HERE` needs to be replaced with the password used to connect to it.

With the `ssh` and `wpa_supplicant.conf` files in place, I can now insert the microSD card into the Pi and power the device on, and within a minute or so it should be up and on the network! I can find its local IP address from my router, and I can connect to it from another machine on the local network with `ssh pi@IP_ADDRESS_HERE` with the default password of `raspberry`.

### 2. Provision the Pi after First Boot

Now that I can SSH into my Pi, there are some more things I want and need to do to make the environment better to work in. These are things like setting the hostname (I use a Dwarf Fortress name generator for identifying my Raspberry Pis - this NAS-and-backup Pi is called "mansionsyrup" for example), setting the locale and timezone, updating the aptitude package manager, installing Git, and pulling down some of my own customized dotfiles (.bashrc, .bash_profile, etc) from a Git repository.

And because I experiment with my Pis a bunch, I've needed to do this whole from-zero process over a dozen times, so I've wrapped this provisioning process up into a little bash script called `first_boot.bash` which looks something like this:

```bash
#!/bin/bash

RPI_HOSTNAME="mansionsyrup"
set -e

function setHostname() {
        echo "SETTING HOSTNAME"

        echo "echo \"${RPI_HOSTNAME}\" | sudo tee /etc/hostname > /dev/null"
        echo "${RPI_HOSTNAME}" | sudo tee /etc/hostname > /dev/null

        echo "sudo sed -i \"s/raspberrypi\$/${RPI_HOSTNAME}/g\" /etc/hosts"
        sudo sed -i "s/raspberrypi\$/${RPI_HOSTNAME}/g" /etc/hosts

        echo "HOSTNAME SET. REBOOT NOW."
        exit 0
}

function configureLocale() {
        echo "CONFIGURING LOCALE"

        KEYMAP="us"
        LOCALE="en_US.UTF-8"
        TIMEZONE="America/Los_Angeles"

        echo "Setting locale..."

        awk '$0 && $0 !~ /^#/ {printf "# "}1' /etc/locale.gen | sudo tee /etc/locale.gen > /dev/null
        sudo sed -i "s/# ${LOCALE}/${LOCALE}/" /etc/locale.gen

        sudo locale-gen

        echo "LANG=en_US.UTF-8" | sudo tee /etc/default/locale > /dev/null
        echo "LC_ALL=en_US.UTF-8" | sudo tee -a /etc/default/locale > /dev/null
        echo "LANGUAGE=en_US.UTF-8" | sudo tee -a /etc/default/locale > /dev/null
        sudo update-locale

        echo "Setting keyboard..."

        sudo sed -i /etc/default/keyboard -e "s/^XKBLAYOUT.*/XKBLAYOUT=\"$KEYMAP\"/"
        sudo dpkg-reconfigure -f noninteractive keyboard-configuration
        sudo invoke-rc.d keyboard-setup start
        sudo setsid sh -c 'exec setupcon -k --force <> /dev/tty1 >&0 2>&1'
        sudo udevadm trigger --subsystem-match=input --action=change

        # Change timezone

        sudo echo "Setting timezone..."
        sudo rm /etc/localtime
        echo "${TIMEZONE}" | sudo tee /etc/timezone > /dev/null
        sudo dpkg-reconfigure -f noninteractive tzdata
}

function refreshApt() {
        echo "REFFRESHING APT"

        echo "sudo apt update"
        sudo apt update

        echo "sudo apt upgrade -y"
        sudo apt upgrade -y
}

function installGit() {
        echo "INSTALLING GIT"

        echo "sudo apt install -y git"
        sudo apt install -y git
}

function installDotfiles() {
        echo "INSTALLING DOTFILES"

        echo "git clone https://github.com/tlake/dotfiles ${HOME}/dotfiles"
        git clone https://github.com/tlake/dotfiles ${HOME}/dotfiles

        echo "cd ${HOME}/dotfiles"
        cd ${HOME}/dotfiles

        echo "chmod +x install"
        chmod +x install

        echo "./install -c raspbian_buster.conf.yaml"
        ./install -c raspbian_buster.conf.yaml

        echo "source ~/.bashrc"
        source ~/.bashrc

        echo "cd -"
        cd -
}

function run() {
        cat /etc/hostname | fgrep -q "${RPI_HOSTNAME}" || setHostname
        configureLocale
        refreshApt
        installGit
        installDotfiles
}

# print help if called with no args
if [[ $# -eq 0 ]]; then
        echo "To see the different functions this script has, inspect the script."
        echo "To run the full script, call it again with 'run' as its only argument."
        exit 0
fi

# check if the function exists
if declare -f "$1" > /dev/null; then
    # call arguments verbatim
    "$@"
else
    # show error
    echo "'$1' is not a valid function name." >&2
    exit 1
fi
```

The script is executed by running `./first_boot.bash run`, and it prompts for a reboot after setting the hostname. After that reboot, the script can just be run the same way again.

### 3. Set Up and Configure the Backup System

There are four components that make the NAS and backup system work:

- `autofs`, a tool for automatically mounting directories on an as-needed basis
- `nfs`, a protocol that allows a client machine to access files over the network
- `rsync`, the tool we'll use for making the backups
- `cron`, a scheduling tool

#### Autofs

First, I need to create a mount point for each of the two USB drives (I chose `/nas/data` and `/nas/backup`):

```bash
$: sudo mkdir -p /nas/data /nas/backup
```

`autofs` can be installed using apt:

```bash
$: sudo apt install --yes autofs
```

Then I need to configure it by adding a line for each of the two USB drives to the `/etc/auto.usb` file. Devices can be targeted by their label, so this probably a good time to connect the drives up to a computer for formatting (I used the `ext4` filesystem) and labelling (I named them `data` and `backup`, naturally). I also know I'll want these drives to be readable and writable when they're mounted, so the lines written into `/etc/auto.usb` should look like these:

```text
data -fstype=ext4,rw :/dev/disk/by-label/data
backup -fstype=ext4,rw :/dev/disk/by-label/backup
```

`autofs`'s master configuration file needs to be told about this `auto.usb` file, so I need to add this line to `/etc/auto.master`:

```text
/nas /etc/auto.usb --timeout=0
```

Finally, I'll run the following command to restart the `autofs` service to register the new changes:

```bash
$: sudo systemctl restart autofs.service
```

and enable the service so that it starts up and runs automatically after the Pi boots up:

```bash
$: sudo systemctl enable autofs.service
```

Now I can access `/nas/data/` or `/nas/backup/` from the Pi and if the USB drives aren't already mounted, `autofs` will automatically mount them for me.

#### NFS

The next step is to expose the data drive over the network as an NFS share. To start, I install the NFS server for the Pi to use:

```bash
$: sudo apt install --yes nfs-kernel-server
```

Then I can define the export of the data drive within the `/etc/exports` file. There are several options that I'll want to supply:
- `rw`, because I want the drive to be readable and writable
- `sync`, because I want the NFS server to reply to requests only after changes have been committed to stable storage
- `no_subtree_check`, because I value the small reliability increase of safeguarding against filename changes upon an open file over the small security increase of `subtree_check`
- `root_squash`, because a client root user should not be the same as the root user on the Pi

The line added to `/etc/exports`, then, looks like this:

```text
/nas/data *(rw,sync,no_subtree_check,root_squash)
```

And I run the following command to update the system's export table file:

```bash
$: sudo exportfs -a
```

Finally, as with the `autofs` service, I want to restart the `nfs-kernel-server` service and enable it upon boot:

```bash
$: sudo systemctl restart nfs-kernel-server
$: sudo systemctl enable nfs-kernel-server
```

Now, from other machines on my network, I can mount and access the data drive over the network with a command that looks like this:

```bash
$: sudo mount mansionsyrup:/nas/data /nas/data
```

provided that the following two things are true for these other machines:

1. An IP-address-to-hostname mapping has been created for "mansionsyrup" in the other machine's `/etc/hosts` file.
2. The other machine has created the `/nas/data` directory to allow a device to be mounted there.

#### Backup

The heart of the backup system is a tool called `rsync`, and the command that does all the heavy lifting is as follows:

```bash
rsync -ah --stats --log-file=${LOGFILE} --link-dest ${LASTDAYPATH} ${DATADIR} ${TODAYPATH}
```

Information on the `rsync` command is probably best discovered in its [man page](https://linux.die.net/man/1/rsync), but let's take a bit of a closer look at this command.

- `-a, --archive`: a shorthand flag that recurses into subdirectories and backs up most of everything.
- `-h, --human-readable`: use kind-to-human numbers.
- `--stats`: display some transfer stats, useful when logging output.
- `--log-file=${LOGFILE}`: write the output of rsync to the file specified in the `LOGFILE` var.
- `--link-dest ${LASTDAYPATH}`: compare the files to be copied to those in the `LASTDAYPATH` var; by setting `LASTDAYPATH` to the most recent backup, rsync will only copy files that are new or different from the previous backup.
- `${DATADIR}`: the location of the directory that we want to recursively backup, defined in the `DATADIR` var.
- `${TODAYPATH}`: the location to which the backup files will be copied, defined in the `TODAYPATH` var.

I've wrapped up my backup process into a series of bash scripts. The heart script, the one that runs the above command, is named `daily_backup.bash`, defines the necessary variables, and automatically timestamps the new backup. It looks like this:

```bash
#!/bin/bash

TODAY=$(date +%Y-%m-%d)

LOGPATH=/var/tmp/nas_backup_logs/${TODAY}
LOGNAME=rsync_backup
LOGFILE=${LOGPATH}/${LOGNAME}

DATADIR=/nas/data
BACKUPDIR=/nas/backup

LASTDAYPATH=${BACKUPDIR}/$(ls ${BACKUPDIR} | tail -n 1)
TODAYPATH=${BACKUPDIR}/${TODAY}

if [[ ! -e ${TODAYPATH} ]] ; then
    mkdir -p ${TODAYPATH}
fi

rsync -ah --stats --log-file=${LOGFILE} --link-dest ${LASTDAYPATH} ${DATADIR} ${TODAYPATH}
```

I also want a way to prune certain old backups, and found some bash kicking around the internet that suited my needs. That's wrapped up in another `delete_old_backups.bash` script, and makes use of some cool natural language processing inherent in the `date` command to filter backups and target ones that are appropriate for deletion.

#### Cron
