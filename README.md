noVNC Desktop Agent
===================
This script starts a VNC and a websockify instance to allow a remote connection
via noVNC. A random password created for each session.

## Dependencies
This script depends [x11vnc](http://www.karlrunge.com/x11vnc/),
[websockify](https://github.com/novnc/websockify) and
[yad](https://github.com/v1cont/yad)

And thanks to [noVNC](https://github.com/novnc/noVNC) team.

## Installation
I tested this script in my Debian Buster box. I installed the dependencies as
the following:

```bash
apt-get install x11vnc yad
apt-get install python3-pip python3-setuptools python3-wheel
pip3 install websockify
```

## Run
Edit `NOVNC_SERVER` in the script before running it. Use your noVNC server
address:

```
NOVNC_SERVER="172.17.17.48"
```


To run the script:

```bash
bash novnc-desktop-agent.sh
```
