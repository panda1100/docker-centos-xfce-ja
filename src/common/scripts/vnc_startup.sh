#!/bin/bash
### every exit != 0 fails the script
set -e

## print out help
help (){
echo "
USAGE:
docker run -it -p 6901:6901 -p 5901:5901 consol/<image>:<tag> <option>

IMAGES:
consol/ubuntu-xfce-vnc
consol/centos-xfce-vnc
consol/ubuntu-icewm-vnc
consol/centos-icewm-vnc

TAGS:
latest  stable version of branch 'master'
dev     current development version of branch 'dev'

OPTIONS:
-w, --wait      (default) keeps the UI and the vncserver up until SIGINT or SIGTERM will received
-s, --skip      skip the vnc startup and just execute the assigned command.
                example: docker run consol/centos-xfce-vnc --skip bash
-d, --debug     enables more detailed startup output
                e.g. 'docker run consol/centos-xfce-vnc --debug bash'
-h, --help      print out this help

Fore more information see: https://github.com/ConSol/docker-headless-vnc-container
"
}
if [[ $1 =~ -h|--help ]]; then
    help
    exit 0
fi

# should also source $STARTUPDIR/generate_container_user
set +e
source $HOME/.bashrc
set -e

# add `--skip` to startup args, to skip the VNC startup procedure
if [[ $1 =~ -s|--skip ]]; then
    echo -e "\n\n------------------ SKIP VNC STARTUP -----------------"
    echo -e "\n\n------------------ EXECUTE COMMAND ------------------"
    echo "Executing command: '${@:2}'"
    exec "${@:2}"
fi
if [[ $1 =~ -d|--debug ]]; then
    echo -e "\n\n------------------ DEBUG VNC STARTUP -----------------"
    export DEBUG=true
fi

## correct forwarding of shutdown signal
cleanup () {
    kill -s SIGTERM $!
    exit 0
}
trap cleanup SIGINT SIGTERM

## write correct window size to chrome properties
$STARTUPDIR/chrome-init.sh

## resolve_vnc_connection
VNC_IP=$(hostname -i)

## change vnc password
echo -e "\n------------------ change VNC password  ------------------"
# first entry is control, second is view (if only one is valid for both)
mkdir -p "$HOME/.vnc"
PASSWD_PATH="$HOME/.vnc/passwd"

if [ ! -f $PASSWD_PATH ]; then
    if [[ $VNC_VIEW_ONLY == "true" ]]; then
        echo "start VNC server in VIEW ONLY mode!"
        #create random pw to prevent access
        echo $(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 20) | vncpasswd -f > $PASSWD_PATH
    fi
    echo "$PASSWORD" | vncpasswd -f >> $PASSWD_PATH
    chmod 600 $PASSWD_PATH
fi

## start vncserver and noVNC webclient
echo -e "\n------------------ start noVNC  ----------------------------"
if [[ $DEBUG == true ]]; then echo "$NO_VNC_HOME/utils/launch.sh --vnc localhost:$VNC_PORT --listen 6901"; fi
$NO_VNC_HOME/utils/launch.sh --vnc localhost:$VNC_PORT --listen 6901 &> $STARTUPDIR/no_vnc_startup.log &
PID_SUB=$!

echo -e "\n------------------ start VNC server ------------------------"
echo "remove old vnc locks to be a reattachable container"
vncserver -kill $DISPLAY &> $STARTUPDIR/vnc_startup.log \
    || rm -rfv /tmp/.X*-lock /tmp/.X11-unix &> $STARTUPDIR/vnc_startup.log \
    || echo "no locks present"

echo -e "start vncserver with param: VNC_COL_DEPTH=$VNC_COL_DEPTH, VNC_RESOLUTION=$VNC_RESOLUTION\n..."
if [[ $DEBUG == true ]]; then echo "vncserver $DISPLAY -depth $VNC_COL_DEPTH -geometry $VNC_RESOLUTION"; fi
vncserver $DISPLAY -depth $VNC_COL_DEPTH -geometry 1280x1024 &> $STARTUPDIR/no_vnc_startup.log

echo -e "start window manager\n..."
$HOME/wm_startup.sh &> $STARTUPDIR/wm_startup.log

## log connect options
echo -e "\n\n------------------ VNC environment started ------------------"
echo -e "\nVNCSERVER started on DISPLAY= $DISPLAY \n\t=> connect via VNC viewer with $VNC_IP:$VNC_PORT"
echo -e "\nnoVNC HTML client started:\n\t=> connect via http://$VNC_IP:6901/?password=...\n"

echo -e "\n------------------ setup resolution ------------------------"
xrandr

set +e
## add custom resolution
## xrandr --newmode args is output of "gtf 1800 800 60"
##xrandr --newmode 1800x850 125.75  1800 1904 2088 2376  850 853 863 883 -hsync +vsync
##xrandr --addmode VNC-0 1800x850

xrandr | grep -q "$VNC_RESOLUTION"
if [ $? = 0 ]; then
    echo "resolution $VNC_RESOLUTION already exits"
else
    echo "$VNC_RESOLUTION" | grep -q "^[0-9]*x[0-9]*$"
    if [ $? -ne 0 ]; then
        echo "set resolution 1280x1024"
        RES="1280x1024"
    fi

    RES_X=`echo $VNC_RESOLUTION | cut -d "x" -f1`
    RES_Y=`echo $VNC_RESOLUTION | cut -d "x" -f2`
    echo "gtf $RES_X $RES_Y 60"
    GTF=`gtf $RES_X $RES_Y 60 | grep Modeline | cut -d "\"" -f 3`

    echo "xrandr --newmode $VNC_RESOLUTION $GTF"
    xrandr --newmode $VNC_RESOLUTION $GTF
    sleep 1
    echo "xrandr --addmode VNC-0 $VNC_RESOLUTION"
    xrandr --addmode VNC-0 $VNC_RESOLUTION
fi

echo -e "\n------------------ change resolution ------------------------"
if [ ! -f $HOME/.config/xfce4/xfconf/xfce-perchannel-xml/displays.xml ]; then
    xrandr --output VNC-0 --mode $VNC_RESOLUTION
    true
fi

set -e

if [[ $DEBUG == true ]] || [[ $1 =~ -t|--tail-log ]]; then
    echo -e "\n------------------ $HOME/.vnc/*$DISPLAY.log ------------------"
    # if option `-t` or `--tail-log` block the execution and tail the VNC log
    tail -f $STARTUPDIR/*.log $HOME/.vnc/*$DISPLAY.log
fi

echo -e "\n------------------ start ibus-daemon ------------------------"
# start input method
export GTK_TM_MODULE=ibus
export QT_TM_MODULE=ibus
export XMODIFIERS=@im=ibus
ibus-daemon -drx

if [ -z "$1" ] || [[ $1 =~ -w|--wait ]]; then
    wait $PID_SUB
else
    # unknown option ==> call command
    echo -e "\n\n------------------ EXECUTE COMMAND ------------------"
    echo "Executing command: '$@'"
    exec "$@"
fi
