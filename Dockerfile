FROM tmatsuo/centos:7
LABEL maintainer="matsuo.tak@gmail.com"

### Envrionment config
ENV HOME=/root \
    TERM=xterm \
    STARTUPDIR=/dockerstartup \
    NO_VNC_HOME=/headless/noVNC \
    VNC_COL_DEPTH=24 \
    VNC_RESOLUTION=1800x850 \
    PASSWORD=password \
    VNC_VIEW_ONLY=false \
    DISPLAY=:1 \
    LANG='ja_JP.utf8' LANGUAGE='ja_JP:ja' LC_ALL='ja_JP.UTF-8' \
    VNC_PORT=5901 \
    CODE_OPTS="--auth none"

WORKDIR $HOME

# Install packages
RUN yum install -y epel-release && \
    wget https://dl.bintray.com/tigervnc/stable/tigervnc-el7.repo -O /etc/yum.repos.d/tigervnc.repo && \
    yum install -y ibus-kkc fcitx fcitx-configtool fcitx-anthy ipa-*-fonts python2-pip.noarch python-tornado.x86_64 supervisor firefox xorg-x11-server-Xorg nginx psmisc openssh-clients openssh-server vim sudo wget which net-tools bzip2 numpy mailcap bash-completion bash-completion-extras tigervnc-server nss_wrapper gettext chromium chromium-libs chromium-libs-media xrdp && \
    echo "###### install xfce ######" && \
    yum -y -x gnome-keyring --skip-broken groups install "Xfce" && \
    yum -y groups install "Fonts" && \
    yum erase -y *power* *screensaver* && \
    rm /etc/xdg/autostart/xfce-polkit* && \
    /bin/dbus-uuidgen > /etc/machine-id && \
    echo "###### install butterfly ######" && \
    pip install --upgrade pip && \
    pip install butterfly && \
    echo "###### install vnc ######" && \
    mkdir -p $NO_VNC_HOME/utils/websockify && \
    wget -qO- https://github.com/novnc/noVNC/archive/v1.2.0.tar.gz | tar xz --strip 1 -C $NO_VNC_HOME && \
    wget -qO- https://github.com/novnc/websockify/archive/v0.9.0.tar.gz | tar xz --strip 1 -C $NO_VNC_HOME/utils/websockify && \
    chmod +x -v $NO_VNC_HOME/utils/*.sh && \
    ln -s $NO_VNC_HOME/vnc.html $NO_VNC_HOME/index.html && \
    echo "###### install filebrowser ######" && \
    curl -fsSL https://filebrowser.org/get.sh | bash && \
    mkdir /var/lib/filebrowser && \
    chown root:root /usr/local/bin/filebrowser && \
    echo "###### install vscode ######" && \
    curl -fsSL https://code-server.dev/install.sh | sh -s -- --version 3.6.0 && \
    /usr/bin/code-server --install-extension ms-kubernetes-tools.vscode-kubernetes-tools && \
    /usr/bin/code-server --install-extension ms-ceintl.vscode-language-pack-ja && \
    /usr/bin/code-server --install-extension auchenberg.vscode-browser-preview && \
    /usr/bin/code-server --install-extension ipedrazas.kubernetes-snippets && \
    echo "###### set locale ######" && \
    localedef -f UTF-8 -i ja_JP ja_JP.UTF-8 && \
    echo "###### cleanup ######" && \
    rm -rf $HOME/.cache/pip/* && \
    yum clean all

### ADD and COPY files
ADD ./src/common/xfce/ $HOME/
ADD ./src/common/scripts $STARTUPDIR
COPY ./src/common/nginx/nginx-module-auth-pam-1.5.2-1.el7.x86_64.rpm /tmp/
COPY ./src/common/nginx/nginx.conf.tmpl /etc/nginx/
COPY ./src/common/nginx/default.d/* /etc/nginx/default.d/
COPY ./src/common/nginx/pam_nginx /etc/pam.d/nginx
COPY ./src/common/scripts/vnc_startup.sh /dockerstartup/vnc_startup.sh
COPY ./src/common/firefox $HOME/.mozilla/firefox/
COPY ./src/common/xfce/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml $HOME/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml
COPY ./src/common/supervisor/*.ini /etc/supervisord.d/
COPY ./src/common/scripts/sshd_startup.sh /dockerstartup/sshd_startup.sh
COPY ./src/common/scripts/docker-entrypoint.sh /
COPY ./src/common/xrdp/xrdp.ini /etc/xrdp/
COPY ./src/common/code/settings.json $HOME/.local/share/code-server/User/
COPY ./src/common/code/argv.json $HOME/.local/share/code-server/User/
COPY ./src/common/code/keybindings.json $HOME/.local/share/code-server/User/

RUN echo "###### install nginx pam auth module ######" && \
    rpm -ivh /tmp/nginx-module-auth-pam-1.5.2-1.el7.x86_64.rpm && \
    rm -f /tmp/nginx-module-auth-pam-1.5.2-1.el7.x86_64.rpm && \
    mkdir /etc/pki/nginx/ && \
    groupadd -g 42 shadow && \
    chgrp shadow /etc/gshadow && \
    chgrp shadow /etc/shadow && \
    chgrp shadow /sbin/unix_chkpwd && \
    chgrp shadow /usr/bin/chage && \
    chmod 2755 /sbin/unix_chkpwd && \
    chmod 2755 /usr/bin/chage && \
    chmod 640 /etc/shadow && \
    chmod 640 /etc/gshadow && \
    gpasswd -a nginx shadow && \
    echo "###### update-ca-trust ######" && \
    update-ca-trust && \
    echo "###### setup supervisord ######" && \
    sed -i "s/nodaemon=false/nodaemon=true/g" /etc/supervisord.conf && \
    echo "###### change permissions for $STARTUPDIR and $HOME ######" && \
    find $STARTUPDIR/ -name '*.sh' -exec chmod $verbose a+x {} + && \
    find $STARTUPDIR/ -name '*.desktop' -exec chmod $verbose a+x {} + && \
    chgrp -R 0 $STARTUPDIR && chmod -R $verbose a+rw $STARTUPDIR && find $STARTUPDIR -type d -exec chmod $verbose a+x {} + && \
    find $HOME/ -name '*.sh' -exec chmod $verbose a+x {} + && \
    find $HOME/ -name '*.desktop' -exec chmod $verbose a+x {} + && \
    chgrp -R 0 $HOME && chmod -R $verbose a+rw $HOME && find $HOME -type d -exec chmod $verbose a+x {} +

### Pach. https://github.com/novnc/noVNC/pull/1451
COPY ./src/common/novnc/vnc.html $NO_VNC_HOME/vnc.html
COPY ./src/common/nginx/launch.sh $NO_VNC_HOME/utils/launch.sh

USER 0
ENTRYPOINT ["/docker-entrypoint.sh"]

