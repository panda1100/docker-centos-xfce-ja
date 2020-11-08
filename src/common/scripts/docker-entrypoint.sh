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
    mkdir $STARTUPDIR/tmp
    chmod 777 $STARTUPDIR/tmp

    if [ "$USER" = "" ]; then
        USER="root"
    fi

    if [ "$PASSWORD" = "" ]; then
        PASSWORD=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1`
        echo
        echo "*******************************************"
        echo "***** $USER password is \"$PASSWORD\" *********"
        echo "*******************************************"
        echo
    fi

    if [ "$USER" != "root" ]; then
        echo "Setting up $USER user"
        ROOT_PASSWORD=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1`
        echo "root:${ROOT_PASSWORD}" | chpasswd

        echo $USER | grep -q -w -e bin -e daemon -e adm -e lp -e sync -e shutdown \
                                -e halt -e mail -e operator -e games -e ftp -e nobody \
                                -e systemd-network -e dbus -e tcpdump -e nginx \
                                -e avahi -e tss -e sshd -e polkitd -e rtkit -e pulse \
                                -e geoclue
        if [ $? -eq 0 ]; then
            echo "invalid user name: $USER"
            exit 1
        fi

        if [ "$USER_ID" != "" ]; then
            if [ $USER_ID -lt 1000 ]; then
                echo "invalid uid: $USER_ID"
                exit 1
            fi
        else
            USER_ID=1000
        fi

        cp -a /root/ /home/$USER
        rm -rf /root/.ssh
        useradd $USER -u $USER_ID -d /home/$USER
        chown -R $USER:$USER /home/$USER
        echo "${USER}:${PASSWORD}" | chpasswd
        chown -R $USER:$USER /var/lib/filebrowser
        sed -i "s#-r /root#-r /home/$USER#g" /etc/supervisord.d/filebrowser.ini
        sed -i "s/^username=ask$/username=$USER/g" /etc/xrdp/xrdp.ini
        sed -i "s#sql:/root#sql:/home/$USER#g" /home/$USER/.mozilla/firefox/ygz7f6y1.myprofile/pkcs11.txt
        sed -i "s#/root#/home/$USER#g" /home/$USER/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml
        sed -i "s#/root#/home/$USER#g" /home/$USER/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml

        for i in ttyd.ini code.ini filebrowser.ini novnc.ini; do
            echo "user=$USER" >> /etc/supervisord.d/$i
            echo "directory=/home/$USER" >> /etc/supervisord.d/$i
            echo "environment=HOME=\"/home/$USER\"" >> /etc/supervisord.d/$i
        done

        if [ "$ENABLE_SUDO" = "true" ]; then
            echo "$USER	ALL=(ALL)	NOPASSWD: ALL" >> /etc/sudoers
        fi
    else
        echo "root:${PASSWORD}" | chpasswd
        sed -i "s/^username=ask$/username=root/g" /etc/xrdp/xrdp.ini
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
