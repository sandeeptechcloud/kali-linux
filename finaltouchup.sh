#!/data/data/com.termux/files/usr/bin/bash

fix_profile() {
    if [ -f "${DESTINATION}/root/.bash_profile" ]; then
        sed -i '/if/,/fi/d' "${DESTINATION}/root/.bash_profile"
    fi
}

fix_sudo() {
    # Only chmod if the files exist inside chroot
    [ -f "$DESTINATION/usr/bin/sudo" ] && chmod +s "$DESTINATION/usr/bin/sudo" || true
    [ -f "$DESTINATION/usr/bin/su" ]   && chmod +s "$DESTINATION/usr/bin/su"   || true
    mkdir -p "$DESTINATION/etc/sudoers.d"
    echo "kali    ALL=(ALL:ALL) ALL" > "$DESTINATION/etc/sudoers.d/kali"
    echo "Set disable_coredump false" > "$DESTINATION/etc/sudo.conf"
}

fix_uid() {
    GID=$(id -g)
    # Run usermod/groupmod inside the chroot using kali-linux-root
    if [ -x "$PREFIX/bin/kali-linux-root" ]; then
        kali-linux-root usermod  -u "$UID" kali  2>/dev/null || true
        kali-linux-root groupmod -g "$GID" kali  2>/dev/null || true
    fi
}

create_xsession_handler() {
    if [ "$SETARCH" = "arm64" ]; then
        LIBGCCPATH=/usr/lib/aarch64-linux-gnu
    else
        LIBGCCPATH=/usr/lib/arm-linux-gnueabihf
    fi

    mkdir -p "$DESTINATION/usr/bin"
    VNC_WRAPPER="$DESTINATION/usr/bin/vnc"

    cat > "$VNC_WRAPPER" << 'EOF'
#!/bin/bash

vnc_start() {
    if [ ! -f ~/.vnc/passwd ]; then
        vnc_passwd
    fi
    USR=$(whoami)
    if [ "$USR" = "root" ]; then
        SCR=:1
    else
        SCR=:2
    fi
    export USER="$USR"
    LD_PRELOAD=LIBGCC_PLACEHOLDER/libgcc_s.so.1 nohup vncserver "$SCR" >/dev/null 2>&1 </dev/null
}

vnc_stop() {
    vncserver -kill :1
    vncserver -kill :2
    return $?
}

vnc_passwd() {
    vncpasswd
    return $?
}

vnc_status() {
    session_list=$(vncserver -list)
    if [[ "$session_list" == *"590"* ]]; then
        echo "$session_list"
    else
        echo "there is nothing to list :)"
        echo "you can start a new session by << vnc start >>"
    fi
}

vnc_kill() {
    pkill Xtigervnc
    return $?
}

case "$1" in
    start)
        vnc_start
        ;;
    stop)
        vnc_stop
        ;;
    status)
        vnc_status
        ;;
    kill)
        vnc_kill
        ;;
    *)
        echo "[!] Usage: vnc {start|stop|status|kill}"
esac
EOF

    # Replace the LD_PRELOAD path placeholder with the real one
    sed -i "s|LIBGCC_PLACEHOLDER|${LIBGCCPATH}|g" "$VNC_WRAPPER"
    chmod +x "$VNC_WRAPPER"
}

## Main

fix_profile
fix_sudo
fix_uid
create_xsession_handler
