#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# st-kali.sh — Post-install configuration for Kali NetHunter (proot)
# Called automatically by st-kali-setup.sh after rootfs extraction.
# Fixes dpkg/apt compatibility issues in a proot (no-root) environment.
# =============================================================================

fix_profile() {
    # Remove login redirect in .bash_profile that causes issues in proot
    if [ -f "${DESTINATION}/root/.bash_profile" ]; then
        sed -i '/if/,/fi/d' "${DESTINATION}/root/.bash_profile"
    fi
}

fix_sudo() {
    [ -f "$DESTINATION/usr/bin/sudo" ] && chmod +s "$DESTINATION/usr/bin/sudo" || true
    [ -f "$DESTINATION/usr/bin/su" ]   && chmod +s "$DESTINATION/usr/bin/su"   || true
    mkdir -p "$DESTINATION/etc/sudoers.d"
    echo "kali    ALL=(ALL:ALL) NOPASSWD: ALL" > "$DESTINATION/etc/sudoers.d/kali"
    echo "Set disable_coredump false" > "$DESTINATION/etc/sudo.conf"
}

fix_dpkg() {
    # -----------------------------------------------------------------
    # proot does not emulate all kernel interfaces that modern apt/dpkg
    # use (LSM sockets, fanotify, security notification channels, etc.)
    # These configs tell dpkg/apt to skip them gracefully.
    # -----------------------------------------------------------------

    # 1. dpkg: skip fsync + honour existing config files without prompting
    mkdir -p "$DESTINATION/etc/dpkg/dpkg.cfg.d"
    cat > "$DESTINATION/etc/dpkg/dpkg.cfg.d/01_proot_fix" << 'DPKGEOF'
force-unsafe-io
force-confdef
force-confold
DPKGEOF

    # 2. apt: noninteractive defaults + skip pre/post hooks that use
    #    getcwd() or exec() — both can return ENOSYS in proot
    mkdir -p "$DESTINATION/etc/apt/apt.conf.d"
    cat > "$DESTINATION/etc/apt/apt.conf.d/99-proot" << 'APTEOF'
APT::Get::Assume-Yes "true";
APT::Get::AllowUnauthenticated "true";
Dpkg::Options {
   "--force-confdef";
   "--force-confold";
   "--force-unsafe-io";
};
DPkg::Pre-Install-Pkgs {"/bin/true";};
DPkg::Post-Invoke {"/bin/true";};
APTEOF

    # 3. Replace dpkg-preconfigure with a no-op stub.
    #    apt hard-calls /usr/sbin/dpkg-preconfigure before unpacking.
    #    That script tries to exec() debconf config scripts which fail
    #    in proot with ENOSYS. A stub that exits 0 skips this entirely.
    mkdir -p "$DESTINATION/usr/sbin"
    cat > "$DESTINATION/usr/sbin/dpkg-preconfigure" << 'DPCEOF'
#!/bin/sh
# proot-compat: debconf config script exec() fails in proot. Skip it.
exit 0
DPCEOF
    chmod +x "$DESTINATION/usr/sbin/dpkg-preconfigure"

    # 4. debconf: set noninteractive via debconf-set-selections (safe format)
    #    DO NOT write to /etc/debconf.conf — it has a strict stanza format
    #    and appending shell variables breaks it ("driver type not specified").
    #    /etc/environment (set below) is enough for noninteractive mode.

    # 5. Fix debconf Encoding.pm: 'locale' binary is not available in proot
    local enc_pm="$DESTINATION/usr/share/perl5/Debconf/Encoding.pm"
    if [ -f "$enc_pm" ]; then
        sed -i 's/my \$cmd = "locale charmap"/my $cmd = "echo UTF-8"/' "$enc_pm"
    fi

    # 6. CRITICAL: Set proot-compatible env for every login session.
    #
    #    WHY /etc/profile.d/ and NOT /etc/environment:
    #    /etc/environment is read ONLY by PAM (pam_env.so) which is NOT
    #    active inside proot. So DEBIAN_FRONTEND set there is INVISIBLE
    #    to dpkg maintainer scripts (keyboard-configuration, etc.) and
    #    causes them to fail with debconf errors during apt upgrade.
    #
    #    /etc/profile.d/ scripts ARE sourced by every "bash --login"
    #    session (which is what kali-linux-root uses), and the exported
    #    variables are inherited by every child process:
    #    bash → apt → dpkg → maintainer scripts
    #    This is what makes apt upgrade work for ALL packages silently.
    mkdir -p "$DESTINATION/etc/profile.d"
    cat > "$DESTINATION/etc/profile.d/00-proot-compat.sh" << 'PROFEOF'
# proot compatibility environment
# Ensures dpkg/apt maintainer scripts never prompt interactively.
# This file is sourced by every bash --login session inside proot.
export DEBIAN_FRONTEND=noninteractive
export DEBCONF_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true
export LC_ALL=C.UTF-8
export LANG=C.UTF-8
PROFEOF
    chmod 644 "$DESTINATION/etc/profile.d/00-proot-compat.sh"
}

fix_kali_user() {
    # Ensure kali user exists with correct home and shell
    if ! grep -q "^kali:" "$DESTINATION/etc/passwd" 2>/dev/null; then
        echo "kali:x:1000:1000:Kali User,,,:/home/kali:/bin/bash" >> "$DESTINATION/etc/passwd"
    else
        sed -i 's|^kali:[^:]*:[^:]*:[^:]*:[^:]*:[^:]*:.*|kali:x:1000:1000:Kali User,,,:/home/kali:/bin/bash|' \
            "$DESTINATION/etc/passwd"
    fi

    # Ensure kali group exists
    if ! grep -q "^kali:" "$DESTINATION/etc/group" 2>/dev/null; then
        echo "kali:x:1000:" >> "$DESTINATION/etc/group"
    fi

    # Create kali home directory
    mkdir -p "$DESTINATION/home/kali"
    chmod 755 "$DESTINATION/home/kali"

    # Clear passwords so no prompts inside proot
    if [ -f "$DESTINATION/etc/shadow" ]; then
        grep -q "^kali:" "$DESTINATION/etc/shadow" && \
            sed -i 's|^kali:[^:]*:|kali::|' "$DESTINATION/etc/shadow" || \
            echo "kali::19000:0:99999:7:::" >> "$DESTINATION/etc/shadow"
        grep -q "^root:" "$DESTINATION/etc/shadow" && \
            sed -i 's|^root:[^:]*:|root::|' "$DESTINATION/etc/shadow" || true
    fi

    # Colorful .bashrc for kali user
    cat > "$DESTINATION/home/kali/.bashrc" << 'RCEOF'
export TERM="${TERM:-xterm-256color}"
export LANG=C.UTF-8
PS1='\[\033[1;32m\]\u\[\033[0m\]@\[\033[1;34m\]\h\[\033[0m\]:\[\033[1;33m\]\w\[\033[0m\]\$ '
alias ls='ls --color=auto'
alias ll='ls -la --color=auto'
RCEOF
    chmod 644 "$DESTINATION/home/kali/.bashrc"

    cat > "$DESTINATION/home/kali/.bash_profile" << 'PFEOF'
[ -f ~/.bashrc ] && . ~/.bashrc
PFEOF
    chmod 644 "$DESTINATION/home/kali/.bash_profile"
}

fix_uid() {
    GID=$(id -g)
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

vnc_stop()   { vncserver -kill :1; vncserver -kill :2; }
vnc_passwd() { vncpasswd; }
vnc_status() {
    session_list=$(vncserver -list)
    if [[ "$session_list" == *"590"* ]]; then
        echo "$session_list"
    else
        echo "No active sessions. Start one with: vnc start"
    fi
}
vnc_kill() { pkill Xtigervnc; }

case "$1" in
    start)  vnc_start  ;;
    stop)   vnc_stop   ;;
    status) vnc_status ;;
    kill)   vnc_kill   ;;
    *)      echo "[!] Usage: vnc {start|stop|status|kill}" ;;
esac
EOF

    sed -i "s|LIBGCC_PLACEHOLDER|${LIBGCCPATH}|g" "$VNC_WRAPPER"
    chmod +x "$VNC_WRAPPER"
}

## Main
fix_profile
fix_sudo
fix_dpkg
fix_kali_user
fix_uid
create_xsession_handler
