#!/bin/bash

if [ "$1" != "" ]; then
    exec $@
fi

function disable_service {
    sed -i 's/autostart=true/autostart=false/g' $1
    sed -i 's/autorestart=true/autorestart=false/g' $1
}

if [ ! -f /etc/init-done ]; then
    if [ "$PASSWORD" = "" ]; then
        PASSWORD=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1`
        echo "generating root user password : \"$PASSWORD\""
    else
        echo "please use your specified password"
    fi
    echo "root:${PASSWORD}" | chpasswd

    if [ "$DISABLE_DESKTOP" = "true" ]; then
        disable_service /etc/supervisord.d/novnc.ini
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

    touch /etc/init-done
else
    echo "skip initializing"
fi

if [ "$OPTS" = "" ]; then
    OPTS='--keepalive_interval=10 --force_unicode_width=True --uri_root_path=/term/'
fi
export OPTS

if [ "$PORT" = "" ]; then
    PORT=8080
fi
export PORT

if [ ! -f /etc/nginx/nginx.conf.org ]; then
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
fi

exec /usr/bin/supervisord
