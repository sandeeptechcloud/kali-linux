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

    # --- GTK theme fix: prevents libwnck/glycin crash in proot ---
    # Kali's default Flat-Remix-Blue-Dark uses SVG icons loaded via
    # glycin which requires bwrap (kernel namespaces) → crashes in proot.
    # Adwaita uses pre-rendered PNGs → no bwrap needed → stable in proot.
    mkdir -p "$DESTINATION/root/.config/gtk-3.0"
    mkdir -p "$DESTINATION/root/.config/gtk-4.0"
    cat > "$DESTINATION/root/.config/gtk-3.0/settings.ini" << 'GTKEOF'
[Settings]
gtk-icon-theme-name = Adwaita
gtk-theme-name = Adwaita
GTKEOF
    cat > "$DESTINATION/root/.config/gtk-4.0/settings.ini" << 'GTKEOF'
[Settings]
gtk-icon-theme-name = Adwaita
gtk-theme-name = Adwaita
GTKEOF
    chmod 644 "$DESTINATION/root/.config/gtk-3.0/settings.ini"
    chmod 644 "$DESTINATION/root/.config/gtk-4.0/settings.ini"

    # --- Disable glycin SVG loader (requires bwrap - fails in proot) ---
    LOADERS_DIR=$(ls -d "$DESTINATION"/usr/lib/aarch64-linux-gnu/gdk-pixbuf-2.0/*/loaders 2>/dev/null | head -1)
    if [ -f "${LOADERS_DIR}/libpixbufloader-glycin-svg.so" ]; then
        mv "${LOADERS_DIR}/libpixbufloader-glycin-svg.so" \
           "${LOADERS_DIR}/libpixbufloader-glycin-svg.so.disabled" 2>/dev/null || true
    fi

    cat > "$VNC_WRAPPER" << 'EOF'
#!/bin/bash

_vnc_cmd() {
    # tigervncserver is the correct command on Kali (xtigervncserver doesn't exist)
    command -v tigervncserver  >/dev/null 2>&1 && echo tigervncserver  && return
    command -v xtigervncserver >/dev/null 2>&1 && echo xtigervncserver && return
    echo vncserver
}

_vnc_create_xstartup() {
    mkdir -p ~/.config/tigervnc
    # Always overwrite xstartup to ensure it's the working proot-compatible version
    cat > ~/.config/tigervnc/xstartup << 'XEOF'
#!/bin/bash
export XDG_RUNTIME_DIR=/tmp/runtime-$(id -u)
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
export GTK_THEME=Adwaita

# Start dbus session daemon
eval $(dbus-launch --sh-syntax 2>/dev/null) || true

# Start XFCE4 components individually
# (bypass xfce4-session which crashes due to polkit/wnck in proot)
xfwm4 --daemon 2>/dev/null &
sleep 1
xfdesktop 2>/dev/null &
xfce4-panel --disable-wm-check 2>/dev/null &

# CRITICAL: Keep xstartup alive
# tigervncserver kills VNC when xstartup exits — this prevents that
while true; do sleep 30; done
XEOF
    chmod +x ~/.config/tigervnc/xstartup
}

vnc_start() {
    # Remove old .vnc dir to stop tigervnc from attempting migration (fails in proot)
    if [ -d ~/.vnc ] && [ ! -d ~/.config/tigervnc ]; then
        rm -rf ~/.vnc
    fi

    # Pre-create tigervnc config dir
    mkdir -p ~/.config/tigervnc

    # Set password if not set
    if [ ! -f ~/.config/tigervnc/passwd ]; then
        echo ""
        echo "  [*] No VNC password set. Please set one now:"
        vncpasswd ~/.config/tigervnc/passwd
    fi

    # Create xstartup (XFCE4 desktop)
    _vnc_create_xstartup

    USR=$(whoami)
    SCR=$( [ "$USR" = "root" ] && echo :1 || echo :2 )
    PORT=$(( 5900 + ${SCR#:} ))
    export USER="$USR"
    echo "  [*] Starting VNC on display $SCR (port $PORT) ..."
    LD_PRELOAD=LIBGCC_PLACEHOLDER/libgcc_s.so.1 \
        $(_vnc_cmd) "$SCR" -geometry 1280x720 -depth 24 2>&1 | grep -v "^$" || true
    sleep 2
    if ls /tmp/.X${SCR#:}-lock >/dev/null 2>&1; then
        echo ""
        echo "  [✓] VNC RUNNING on display $SCR  |  Port: $PORT"
        echo "  [✓] Open NetHunter KeX → connect to 127.0.0.1:$PORT"
    else
        echo ""
        echo "  [!] VNC failed. Log:"
        cat ~/.config/tigervnc/localhost${SCR}.log 2>/dev/null | tail -15
    fi
}

vnc_stop() {
    pkill -9 Xtigervnc 2>/dev/null || true
    rm -f /tmp/.X*-lock /tmp/.X11-unix/X* 2>/dev/null || true
    echo "  [*] VNC stopped."
}

vnc_passwd() {
    mkdir -p ~/.config/tigervnc
    vncpasswd ~/.config/tigervnc/passwd
}

vnc_status() {
    LOCKS=$(ls /tmp/.X*-lock 2>/dev/null)
    if [ -n "$LOCKS" ]; then
        echo ""
        echo "  TigerVNC server sessions:"
        echo ""
        for lock in $LOCKS; do
            DISP=${lock#/tmp/.X}; DISP=${DISP%-lock}
            PORT=$((5900 + DISP))
            PID=$(cat "$lock" 2>/dev/null | tr -d ' ')
            echo "    Display :$DISP  |  Port $PORT  |  PID $PID"
            echo "    Connect: 127.0.0.1:$PORT"
        done
        echo ""
    else
        echo "  No active VNC sessions. Run: vnc start"
    fi
}

vnc_kill() {
    pkill Xtigervnc 2>/dev/null || true
    rm -f /tmp/.X*-lock /tmp/.X11-unix/X* 2>/dev/null || true
    echo "  [*] All VNC processes killed."
}

case "$1" in
    start)  vnc_start  ;;
    stop)   vnc_stop   ;;
    status) vnc_status ;;
    passwd) vnc_passwd ;;
    kill)   vnc_kill   ;;
    *)
        echo ""
        echo "  Usage: vnc {start|stop|status|passwd|kill}"
        echo ""
        echo "    start   — Start VNC server (XFCE4 desktop)"
        echo "    stop    — Stop VNC server"
        echo "    status  — Show active VNC sessions"
        echo "    passwd  — Set/change VNC password"
        echo "    kill    — Force-kill all VNC processes"
        echo ""
        ;;
esac
EOF

    sed -i "s|LIBGCC_PLACEHOLDER|${LIBGCCPATH}|g" "$VNC_WRAPPER"
    chmod +x "$VNC_WRAPPER"
}

fix_systemd() {
    # ---------------------------------------------------------------
    # ROOT CAUSE OF RECURRING ERROR:
    # fix_systemd() writes a stub at install time. But when the user
    # later runs 'apt upgrade', dpkg UNPACKS the new systemd .deb and
    # OVERWRITES our stub with the real binary. Then systemd.postinst
    # calls the real binary → O_RDWR+lseek fail → EBADF → dpkg error.
    #
    # THE PERMANENT FIX:
    # Use dpkg-divert to register a diversion for the binary.
    # After diversion, dpkg will ALWAYS install new systemd binaries
    # to systemd-machine-id-setup.distrib instead of our stub path.
    # Our stub at /usr/bin/systemd-machine-id-setup is NEVER touched.
    # ---------------------------------------------------------------

    # 1. Generate a valid 32-char hex machine-id
    local MACHINE_ID=""
    if [ -r /proc/sys/kernel/random/uuid ]; then
        MACHINE_ID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null | tr -d '-\n')
    fi
    if [ ${#MACHINE_ID} -ne 32 ]; then
        MACHINE_ID=$(od -A n -t x1 -N 16 /dev/urandom 2>/dev/null | tr -d ' \n')
    fi
    if [ ${#MACHINE_ID} -ne 32 ]; then
        MACHINE_ID="a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4"
    fi
    echo "$MACHINE_ID" > "$DESTINATION/etc/machine-id"
    chmod 644 "$DESTINATION/etc/machine-id"

    # 2. Write the proot-compatible stub
    mkdir -p "$DESTINATION/usr/bin"
    cat > "$DESTINATION/usr/bin/systemd-machine-id-setup" << 'STUBEOF'
#!/bin/sh
# proot-compat stub — do not remove.
# The real systemd-machine-id-setup uses O_RDWR+lseek on /etc/machine-id
# which fails in proot with EBADF. This stub handles it safely.
MACHINE_ID=/etc/machine-id
if [ ! -s "$MACHINE_ID" ]; then
    UUID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null | tr -d '-\n')
    if [ ${#UUID} -eq 32 ]; then
        echo "$UUID" > "$MACHINE_ID"
    else
        echo "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4" > "$MACHINE_ID"
    fi
fi
exit 0
STUBEOF
    chmod +x "$DESTINATION/usr/bin/systemd-machine-id-setup"

    # 3. Register diversion DIRECTLY in dpkg's diversions database.
    #    WHY direct write instead of running dpkg-divert via proot:
    #    The proot call fails silently (|| true), so diversion was never
    #    registered, and apt upgrade kept overwriting our stub.
    #
    #    dpkg's diversions file format (3 lines per entry):
    #      line 1: original path
    #      line 2: diverted-to path (.distrib suffix)
    #      line 3: package name (: = local admin diversion)
    #
    #    After this, dpkg will ALWAYS put new systemd binaries at
    #    .distrib and leave our stub at the original path untouched.
    local DIVERSIONS="$DESTINATION/var/lib/dpkg/diversions"
    mkdir -p "$DESTINATION/var/lib/dpkg"
    touch "$DIVERSIONS"
    if ! grep -q "systemd-machine-id-setup" "$DIVERSIONS" 2>/dev/null; then
        printf '/usr/bin/systemd-machine-id-setup\n/usr/bin/systemd-machine-id-setup.distrib\n:\n' >> "$DIVERSIONS"
    fi

    # 4. Safety-net Post-Invoke hook: re-create stub if dpkg ever
    #    replaces it (e.g. if diversion was cleared manually).
    #    Uses a separate script to avoid quoting hell in apt.conf.
    mkdir -p "$DESTINATION/usr/local/bin"
    cat > "$DESTINATION/usr/local/bin/proot-fix-stubs.sh" << 'HOOKEOF'
#!/bin/sh
# Called by dpkg Post-Invoke to ensure proot stubs are intact.

# Restore systemd-machine-id-setup stub if overwritten
if ! grep -q 'proot-compat stub' /usr/bin/systemd-machine-id-setup 2>/dev/null; then
    cat > /usr/bin/systemd-machine-id-setup << 'STUB'
#!/bin/sh
# proot-compat stub — do not remove.
MACHINE_ID=/etc/machine-id
if [ ! -s "$MACHINE_ID" ]; then
    UUID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null | tr -d '-\n')
    [ ${#UUID} -eq 32 ] && echo "$UUID" > "$MACHINE_ID" || \
        echo "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4" > "$MACHINE_ID"
fi
exit 0
STUB
    chmod +x /usr/bin/systemd-machine-id-setup
fi

# Ensure machine-id is readable/writable
[ -f /etc/machine-id ] && chmod 644 /etc/machine-id || true
exit 0
HOOKEOF
    chmod +x "$DESTINATION/usr/local/bin/proot-fix-stubs.sh"

    # Hook the safety-net into apt's Post-Invoke
    mkdir -p "$DESTINATION/etc/apt/apt.conf.d"
    cat >> "$DESTINATION/etc/apt/apt.conf.d/99-proot" << 'APTEOF'
DPkg::Post-Invoke {"/usr/local/bin/proot-fix-stubs.sh || true";};
APTEOF

    # 5. Pre-create /run/systemd to prevent mkdir failures in postinst
    mkdir -p "$DESTINATION/run/systemd"

    # 6. Mask systemd units that can never work in proot
    mkdir -p "$DESTINATION/etc/systemd/system"
    for unit in systemd-journald systemd-udevd systemd-networkd systemd-resolved; do
        ln -sf /dev/null "$DESTINATION/etc/systemd/system/${unit}.service" 2>/dev/null || true
    done
}

## Main
fix_profile
fix_sudo
fix_dpkg
fix_systemd
fix_kali_user
fix_uid
create_xsession_handler
