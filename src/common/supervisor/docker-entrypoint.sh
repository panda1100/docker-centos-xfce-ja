#!/bin/bash

if [ "$1" != "" ]; then
    exec $@
fi

if [ ! -f /etc/butterfly-init-done ]; then
    if [ "$PASSWORD" = "" ]; then
        PASSWORD=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1`
        echo "generating root user password : \"$PASSWORD\""
    else
        echo "please use your specified password"
    fi
    echo "root:${PASSWORD}" | chpasswd
    touch /etc/butterfly-init-done
else
    echo "skip generating password"
fi

if [ "$OPTS" = "" ]; then
    OPTS='--keepalive_interval=10 --force_unicode_width=True --uri_root_path=/term/'
fi
export OPTS

if [ "$PORT" = "" ]; then
    PORT=8080
fi
export PORT
sed -i "s/address = .*/address = \":$PORT\"/g" /etc/traefik.toml

exec /usr/bin/supervisord
