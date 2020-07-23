# Docker container images with "headless" VNC session and butterfly web console for Japanese

This repository contains a collection of Docker images with headless VNC environments and butterfly web console through reverse proxy(traefik).
This repository is based on [docker-headless-vnc-container](https://github.com/ConSol/docker-headless-vnc-container), but it supports CentOS 7 with xfce only.
Dockerfile "Dockerfile.centos.xfce.vnc" is only maintained.

Each Docker image is installed with the following components:

* Desktop environment [**Xfce4**](http://www.xfce.org)
* VNC-Server (default VNC port `5901`)
* [**noVNC**](https://github.com/novnc/noVNC) - HTML5 VNC client (port `6901`)
* [**butterfly**](https://github.com/paradoxxxzero/butterfly) - Terminal Emulator on browser (port `57575`)

* Browsers:
  * Chromium
  * Firefox
  * Edge
  
![Docker VNC Desktop access via HTML page](.pics/screen-desktop.png)

![Docker Terminal access via HTML page](.pics/screen-term.png)

## Kubernetes

* [Kubernetes usage](./kubernetes/README.md)

## Usage

- Docker (via internal reverse proxy)

      docker run -d -p 8080:8080 -e PASSWORD=password --name centos-xfce-ja tmatsuo/centos-xfce-ja

Access http://your-host-name:8080/desktop/ to access xfce desktop.
Access http://your-host-name:8080/term/ to access web console.

- Docker (direct access)

      docker run -d -p 6901:6901 -p 57575:57575 -e PASSWORD=password --name centos-xfce-ja tmatsuo/centos-xfce-ja

Access http://your-host-name:6901/ to access xfce desktop.
Access http://your-host-name:57575/ to access web console.

- Change Password

If you want to change vnc(desktop) login password, please use vncpasswd command after login.
if you want to change web console login password, please use passwd command after login.

### Override VNC environment variables

The following VNC environment variables can be overwritten at the `docker run` phase to customize your desktop environment inside the container:
* `VNC_COL_DEPTH`, default: `24`
* `VNC_RESOLUTION`, default: `1800x850`

### Override reverse proxy listen port

* `PORT`, default: `8080`

