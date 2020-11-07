#!/bin/bash

if [ "$1" != "" ]; then
    exec $@
fi

function disable_service {
    sed -i 's/autostart=true/autostart=false/g' $1
    sed -i 's/autorestart=true/autorestart=false/g' $1
}

if [ "$PORT" = "" ]; then
    PORT=8080
fi
export PORT

# pre hook
if [ "$PRE_HOOK" != "" ]; then
    echo "---- pre hook : $PRE_HOOK --------------"
    source $PRE_HOOK || exit 1
    echo "----------------------------------------"
fi

if [ ! -f /etc/init-done ]; then
    # pre hook (once)
    if [ "$PRE_HOOK_ONCE" != "" ]; then
        echo "---- pre hook once : $PRE_HOOK_ONCE ----"
        source $PRE_HOOK_ONCE || exit 1
        echo "----------------------------------------"
    fi

    if [ "$PASSWORD" = "" ]; then
        PASSWORD=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1`
        echo "generating root user password : \"$PASSWORD\""
    else
        echo "please use your specified password"
    fi
    echo "root:${PASSWORD}" | chpasswd

    if [ "$DISABLE_DESKTOP" = "true" ]; then
        disable_service /etc/supervisord.d/novnc.ini
        disable_service /etc/supervisord.d/xrdp.ini
    fi
    if [ "$DISABLE_TERMINAL" = "true" ]; then
        disable_service /etc/supervisord.d/butterfly.ini
    fi
    if [ "$DISABLE_FILER" = "true" ]; then
        disable_service /etc/supervisord.d/filebrowser.ini
    fi
    if [ "$DISABLE_SSH" = "true" ]; then
        disable_service /etc/supervisord.d/sshd.ini
    fi
    if [ "$DISABLE_RDP" = "true" ]; then
        disable_service /etc/supervisord.d/xrdp.ini
    fi
    if [ "$DISABLE_CODE" = "true" ]; then
        disable_service /etc/supervisord.d/code.ini
    fi

    # change sshd port
    if [ "$SSH_PORT" != "" ]; then
        sed -i "s/^#Port 22/Port $SSH_PORT/g" /etc/ssh/sshd_config
    fi

    # disable ssh password login
    if [ "$DISABLE_SSH_PASSWORD_LOGIN" = "true" ]; then
        sed -i "s/^PasswordAuthentication yes/PasswordAuthentication no/g" /etc/ssh/sshd_config
    fi

    # insert ssh public key
    if [ "$SSH_KEY" != "" ]; then
        mkdir $HOME/.ssh
        chmod 700 $HOME/.ssh
        echo $SSH_KEY >> $HOME/.ssh/authorized_keys
        chmod 600 $HOME/.ssh/authorized_keys
    fi

    # change rdp port
    if [ "$RDP_PORT" != "" ]; then
        sed -i "s/^port=3389/port=$RDP_PORT/g" /etc/xrdp/xrdp.ini
    fi

    # initializing nginx
    mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf.org
    if [ "$NOSSL" = "true" ]; then
        sed "s/^#http/     /g" /etc/nginx/nginx.conf.tmpl > /etc/nginx/nginx.conf
    else
        sed "s/^#ssl/     /g" /etc/nginx/nginx.conf.tmpl > /etc/nginx/nginx.conf
        if [ ! -f /etc/pki/nginx/server.key ]; then
            openssl genrsa 2048 > /etc/pki/nginx/server.key
            openssl req -new -key /etc/pki/nginx/server.key <<EOF > /etc/pki/nginx/server.csr
JP
Default Prefecture
Default City
Default Company
Default Section
localhost



EOF
            openssl x509 -days 3650 -req -signkey /etc/pki/nginx/server.key < /etc/pki/nginx/server.csr > /etc/pki/nginx/server.crt
        fi
    fi
    sed -i "s/8080/$PORT/g" /etc/nginx/nginx.conf
    # initializing nginx done

    echo "VNC_RESOLUTION=$VNC_RESOLUTION" >> $HOME/.bashrc
    if [ "DOCKER_HOST" != "" ]; then
        echo "export DOCKER_HOST=$DOCKER_HOST" >> $HOME/.bashrc
    fi

    # post hook (once)
    if [ "$POST_HOOK_ONCE" != "" ]; then
        echo "---- post hook once : $POST_HOOK_ONCE ----"
        source $POST_HOOK_ONCE || exit 1
        echo "----------------------------------------"
    fi

    touch /etc/init-done
else
    echo "skip initializing"
fi

if [ "$TTYD_OPTS" = "" ]; then
    TTYD_OPTS='-P 30'
fi
export TTYD_OPTS

# post hook
if [ "$POST_HOOK" != "" ]; then
    echo "---- post hook : $POST_HOOK ------------"
    source $POST_HOOK || exit 1
    echo "----------------------------------------"
fi

exec /usr/bin/supervisord
