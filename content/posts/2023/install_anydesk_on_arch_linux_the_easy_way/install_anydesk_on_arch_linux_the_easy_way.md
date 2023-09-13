---
title: "Install AnyDesk on Arch Linux the easy way"
description: "Install AnyDesk on Arch Linux the easy way"
author: Florian
publishDate: 2023-09-13T18:10:00+02:00
tags:
  - 'Linux'
  - 'Arch Linux'
---

## Introduction
> TL;DR
> Install AnyDesk from AUR with YAY on Arch Linux

On my mom's old Laptop, I replaced the old MX Linux OS with Arch Linux with Gnome GUI.

For remote support, I got good experience with [AnyDesk](https://anydesk.com/en). It got a free license version with unlimited working time (not like TeamViewer, where you get kicked out with the free version after any time).
\
\
First we got to install, [YAY](https://github.com/Jguer/yay) (Yet another Yogurt). If you already got it set up, you can skip this step.
\
\
### Why to use YAY?
There are a few ways to get AnyDesk working on Arch Linux.\
First I liked to use [Flatpak](https://github.com/flatpak/flatpak) because of easier switching distribution in the future, but unfortunately the package got marked as "end-of-life" because of lack of maintainers.\
Then you can install the package manually, but it's hard to keep it up to date.\
So I ended using [AUR](https://aur.archlinux.org/) (Archlinux User Repository) because there provided the current version of AnyDesk, and it's easy to keep the package up to date in the future.


## Install YAY
```bash
sudo pacman -S --needed git base-devel
# Run as non-root user
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si
```


## Install and setup AnyDesk
```bash
# Run as non-root user
yay -S anydesk-bin

# If wayland is used
sudo vim /etc/gdm/custom.conf
[daemon]
WaylandEnable = false

# Enable auto login
AutomaticLoginEnable = true
AutomaticLogin = $username

sudo systemctl enable anydesk
sudo reboot
```

I hope this short note could help you.

## References
- [YAY repository](https://github.com/Jguer/yay), github.com.
- [YAY AUR Package Details](https://aur.archlinux.org/packages/yay), aur.archlinux.org.
- [3 Tested Ways to Fix AnyDesk Display Server Not Supported](https://www.anyviewer.com/how-to/anydesk-display-server-not-supported-2578.html), anyviewer.com.
- [AnyDesk website](https://anydesk.com/en), anydesk.com.
- [Flathub AnyDesk Flatpak](https://github.com/flathub/com.anydesk.Anydesk/blob/master/flathub.json), github.com.
