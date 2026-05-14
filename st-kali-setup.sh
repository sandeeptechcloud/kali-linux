#!/data/data/com.termux/files/usr/bin/bash -e
################################################################################
# Kali NetHunter Installer - Custom Hacker Edition
# Modified by Sandeep Tech
################################################################################

# colors
red='\033[1;31m'
yellow='\033[1;33m'
blue='\033[1;34m'
green='\033[1;32m'
cyan='\033[1;36m'
reset='\033[0m'

# Clean up
pre_cleanup() {
        find $HOME -maxdepth 1 -name "kali*.tar.xz" -type f -exec rm -f {} \; || :
}

post_cleanup() {
        find $HOME -maxdepth 1 -name "kali*.tar.xz" -type f -exec rm -f {} \; || :
        [ -f "$HOME/st-kali.sh" ] && rm -f "$HOME/st-kali.sh" || :
}

# Utility function for Unknown Arch
#####################
#    Decide Chroot  #
#####################

setchroot() {
	chroot=full
}

#####################
#    SETARCH        #
#####################
unknownarch() {
	printf "${red} [*] Unknown Architecture :("
	printf "\n${reset}"
	exit
}

# Utility function for detect system
checksysinfo() {
	printf "$blue [*] Checking host architecture ..."
	case $(getprop ro.product.cpu.abi) in
		arm64-v8a)
			SETARCH=arm64;;
		armeabi|armeabi-v7a)
			SETARCH=armhf;;
		*)
			unknownarch;;
	esac
        printf "\n [*] SETARCH = ${SETARCH}"
}

# Check if required packages are present
checkdeps() {
	printf "\n${yellow} ╔═══════════════════════════════════════╗"
	printf "\n${yellow} ║     🚀 INSTALLATION STARTED 🚀       ║"
	printf "\n${yellow} ╚═══════════════════════════════════════╝${reset}"
	printf "\n\n${blue} [*] Updating apt cache..."
	apt update -y &> /dev/null
	echo "\n [*] Checking for all required tools..."

	for i in proot tar wget; do
		if [ -e $PREFIX/bin/$i ]; then
			echo "  ✓ ${green}${i}${reset} is OK"
		else
			echo "  ✗ Installing ${i}..."
			apt install -y $i ||
                        {
				printf "\n${red} [!] ERROR: check your internet connection or apt"
				printf "\n${red} [!] Exiting...${reset}\n"
				exit
			}
		fi
	done

	# Install axel if available (optional, wget is fallback)
	if [ ! -e $PREFIX/bin/axel ]; then
		apt install -y axel &>/dev/null || true
	fi

	echo ""
	echo "  ███████╗████████╗    ██╗     ██╗███╗   ██╗██╗   ██╗██╗  ██╗"
    echo "  ██╔════╝╚══██╔══╝    ██║     ██║████╗  ██║██║   ██║╚██╗██╔╝"
    echo "  ███████╗   ██║       ██║     ██║██╔██╗ ██║██║   ██║ ╚███╔╝ "
    echo "  ╚════██║   ██║       ██║     ██║██║╚██╗██║██║   ██║ ██╔██╗ "
    echo "  ███████║   ██║       ███████╗██║██║ ╚████║╚██████╔╝██╔╝ ██╗"
    echo "  ╚══════╝   ╚═╝       ╚══════╝╚═╝╚═╝  ╚═══╝ ╚═════╝ ╚═╝  ╚═╝"
	echo ""

	printf "\n${green} [*] All dependencies checked!${reset}\n"

	apt upgrade -y &>/dev/null || true
}

# URLs of all possible architectures
seturl() {
	URL="https://kali.download/nethunter-images/current/rootfs/kali-nethunter-rootfs-${chroot}-${SETARCH}.tar.xz"
	# Fallback mirror
	MIRROR_URL="https://github.com/termux/proot-distro/releases/download/v3.10.0/kali-${SETARCH}-pd-v3.10.0.tar.xz"
}

# Utility function to get tar file
gettarfile() {
    seturl
    printf "\n${blue} [*] Fetching tar file"
    printf "\n from ${URL}"
    cd $HOME
    rootfs="kali-nethunter-rootfs-${chroot}-${SETARCH}.tar.xz"
    printf "\n [*] Placing ${rootfs}"
    printf "\n into ${DESTINATION}"
    printf "${reset}\n"
    if [ ! -f "$rootfs" ]; then
        if [ -e "$PREFIX/bin/axel" ]; then
            axel ${EXTRAARGS} --alternate "$URL" -o "$rootfs" || \
                wget -q --show-progress "$URL" -O "$rootfs"
        else
            wget -q --show-progress "$URL" -O "$rootfs"
        fi
    else
        printf "${red} [!] continuing with already downloaded image,"
        printf "\n if this image is corrupted or half downloaded then "
        printf "\n delete it manually to download a fresh image."
        printf "${reset}\n"
    fi
}

# Official SHA256 hashes from Kali's website
get_sha256() {
    local arch=$1
    local chroot=$2
    case "${arch}-${chroot}" in
        arm64-full) echo "b8098fc90ed74a553592f7019a1d88dfe3c65b16c60af487b0658860554dc5aa" ;;
        armhf-full) echo "b15a4aba9fb1c6f7481d7b3d08cb77c9e9c993eb542475961d008bdc64767d64" ;;
        amd64-full) echo "a6673ef39dfc858a5ad4e4b18f974f3eda7732b12cba07609d377b5dbd7d2436" ;;
        i386-full) echo "a9ee9c504dd9df21da4bfabd9b97b4d6d8816ffabc4b1d10b2c786d52ca06e93" ;;
        arm64-minimal) echo "08f121b553d03476b82b6322365eb4f47f73f4edf8800dafa7462b061eb2d0fc" ;;
        armhf-minimal) echo "1ff5a8313cca728cf3c967bd2c8b59c629e8d4b9f4b35bf62b9df9f0097c8c1d" ;;
        amd64-minimal) echo "63c7ce7c65430b3e95a0e7af530de9e2513dc90df1ced1336e192953c97b7dd6" ;;
        i386-minimal) echo "1aa7d3ef4f8b6e079d5a2ec6a025deec601eab8c7236b336bb9ba23a67845994" ;;
        arm64-nano) echo "484af462afa5064512f420d8565a90c7923ac6288f35d37d37dff6aa44936a23" ;;
        armhf-nano) echo "d0761b79c0b303401a1ac405db1b2b223b0e3e8d60ec647a6b391fd70c595fdf" ;;
        amd64-nano) echo "61c9d00951ab8a45e8a5eaeaff32c8e80e903511b26baed68769299693fe68b5" ;;
        i386-nano) echo "12c3dfc5e6e693662dd3a83abea847ee4140f672c45f18f1c2416d9b3c2a20c6" ;;
        *) echo "" ;;
    esac
}

# Utility function to check integrity
checkintegrity() {
	printf "\n${blue} [*] Checking integrity of file..."
	rootfs="kali-nethunter-rootfs-${chroot}-${SETARCH}.tar.xz"
	if [ ! -f "$rootfs" ]; then
		printf "${red} [!] Downloaded file not found. Please re-run the script."
		printf "${reset}\n"
		exit 1
	fi
	if [ ! -s "$rootfs" ]; then
		printf "${red} [!] Downloaded file is empty. Please re-run the script."
		printf "${reset}\n"
		exit 1
	fi
	# Get expected SHA256 hash
	expected_hash=$(get_sha256 "$SETARCH" "$chroot")
	if [ -z "$expected_hash" ]; then
		printf "${yellow} [!] No official hash found for this architecture, skipping verification"
		printf "${reset}\n"
		return 0
	fi
	# Calculate actual hash
	printf "\n [*] Verifying SHA256 hash..."
	actual_hash=$(sha256sum "$rootfs" | awk '{print $1}')
	if [ "$actual_hash" = "$expected_hash" ]; then
		printf "${green} [*] Integrity check PASSED!"
		printf "${reset}\n"
	else
		printf "${red} Sorry :( your downloaded file was corrupted "
		printf "or half downloaded, but don't worry, just rerun my script"
		printf "${reset}\n"
		printf "${red} Expected: $expected_hash"
		printf "${red} Got:      $actual_hash"
		printf "${reset}\n"
		rm -f "$rootfs"
		exit 1
	fi
}

# ── Spinner animation for long operations ──────────────────────
show_spinner() {
    local msg="$1"
    local pid=$2
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0
    local elapsed=0
    while kill -0 "$pid" 2>/dev/null; do
        i=$(( (i+1) % 10 ))
        local frame=$(echo "$spin" | cut -c$((i+1)))
        printf "\r${cyan}  %s %s  [%ds elapsed]${reset}" "$frame" "$msg" "$elapsed"
        sleep 1
        elapsed=$((elapsed+1))
    done
    printf "\r${green}  ✓ %s  [done in %ds]${reset}\n" "$msg" "$elapsed"
}

# Utility function to extract tar file
extract() {
	printf "\n${yellow}  ╔══════════════════════════════════════════╗"
	printf "\n${yellow}  ║   📦 Extracting Kali Linux Rootfs...    ║"
	printf "\n${yellow}  ║   ⏱  This will take 10-15 minutes.      ║"
	printf "\n${yellow}  ║   ☕ Grab a coffee and be patient!       ║"
	printf "\n${yellow}  ╚══════════════════════════════════════════╝${reset}\n"

	# Create destination directory
	mkdir -p "$DESTINATION"

	# Extract in background with spinner
	(
	    proot --link2symlink tar -xJf "$rootfs" --strip-components=1 -C "$DESTINATION" 2>/dev/null || \
	    proot --link2symlink tar -xJf "$rootfs" -C "$DESTINATION" 2>/dev/null || \
	    tar -xJf "$rootfs" -C "$DESTINATION" 2>/dev/null || :
	) &
	EXTRACT_PID=$!
	show_spinner "Extracting rootfs (please wait...)" "$EXTRACT_PID"
	wait "$EXTRACT_PID"

	# Verify extraction was successful
	if [ -d "$DESTINATION/etc" ] || [ -d "$DESTINATION/usr" ]; then
		printf "${green} [*] Extraction complete!${reset}\n"
	else
		# Try extracting to home first then move
		printf "${yellow} [*] Retrying extraction...${reset}\n"
		proot --link2symlink tar -xJf "$rootfs" -C "$HOME" 2>/dev/null || \
		    tar -xJf "$rootfs" -C "$HOME" 2>/dev/null || :

		# Find the extracted directory
		EXTRACTED_DIR=""
		for dir in "$HOME"/kali-nethunter-rootfs-* "$HOME"/kali-* "$HOME"/rootfs; do
			if [ -d "$dir" ] && [ "$dir" != "$DESTINATION" ]; then
				EXTRACTED_DIR="$dir"
				break
			fi
		done

		if [ -n "$EXTRACTED_DIR" ]; then
			mv "$EXTRACTED_DIR"/* "$DESTINATION/" 2>/dev/null || \
			    mv "$EXTRACTED_DIR" "$DESTINATION" 2>/dev/null || :
			rm -rf "$EXTRACTED_DIR" 2>/dev/null || :
			printf "${green} [*] Extraction complete!${reset}\n"
		else
			printf "${red} [!] Extraction failed. Please check the archive.${reset}\n"
			exit 1
		fi
	fi
}

# Utility function for login file
createloginfile() {
	# Create kali-linux command (user mode)
	bin=$PREFIX/bin/kali-linux
        printf "\n${blue} [*] Creating ${bin}"
        printf "${reset}\n"
	cat > $bin << EOM
#!/data/data/com.termux/files/usr/bin/bash
unset LD_PRELOAD

# colors
red='\033[1;31m'
yellow='\033[1;33m'
green='\033[1;32m'
cyan='\033[1;36m'
reset='\033[0m'

# Show banner
clear
echo ""
CFONTS_BIN="PREFIX_PLACEHOLDER/bin/cfonts"
if [ -f "\$CFONTS_BIN" ]; then
    "\$CFONTS_BIN" "LINUX" -f block -c yellow,blue -a center
elif command -v cfonts &>/dev/null; then
    cfonts "LINUX" -f block -c yellow,blue -a center
else
    echo -e "\033[1;33m  =============================="
    echo -e "      K A L I   L I N U X"
    echo -e "  ==============================\033[0m"
fi
echo ""
echo -e "\${reset}  ╔══════════════════════════════════════════╗"
echo -e "\${reset}  ║   ⚡ Created by Sandeep Tech ⚡          ║"
echo -e "\${reset}  ╚══════════════════════════════════════════╝"
echo ""
echo -e "\${green} [*] Starting Kali Linux (User Mode)...\${reset}"
echo ""

user=kali
home=/home/\${user}

export PROOT_TMPDIR="PREFIX_PLACEHOLDER/tmp"
mkdir -p "PREFIX_PLACEHOLDER/tmp"

exec proot \\
    --link2symlink \\
    -i 1000:1000 \\
    -r DEST_PLACEHOLDER \\
    -b /dev \\
    -b /proc \\
    -b DEST_PLACEHOLDER/dev:/dev/shm \\
    -b /sdcard \\
    -b HOME_PLACEHOLDER \\
    -w \${home} \\
    /usr/bin/env -i \\
    HOME=\${home} \\
    USER=\${user} \\
    LOGNAME=\${user} \\
    TERM="\${TERM:-xterm-256color}" \\
    LANG=C.UTF-8 \\
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \\
    /bin/bash --login "\${@}"
EOM

	# Replace placeholders with actual values
	sed -i "s|DEST_PLACEHOLDER|${DESTINATION}|g" "$bin"
	sed -i "s|HOME_PLACEHOLDER|${HOME}|g" "$bin"
	sed -i "s|PREFIX_PLACEHOLDER|${PREFIX}|g" "$bin"
	chmod 700 $bin

	# Create kali-linux-root command (root mode)
	bin=$PREFIX/bin/kali-linux-root
        printf "\n${blue} [*] Creating ${bin}"
        printf "${reset}\n"
	cat > $bin << EOM
#!/data/data/com.termux/files/usr/bin/bash
unset LD_PRELOAD

# colors
red='\033[1;31m'
yellow='\033[1;33m'
green='\033[1;32m'
cyan='\033[1;36m'
reset='\033[0m'

# Show banner
clear
echo ""
CFONTS_BIN="PREFIX_PLACEHOLDER/bin/cfonts"
if [ -f "\$CFONTS_BIN" ]; then
    "\$CFONTS_BIN" "LINUX" -f block -c yellow,blue -a center
elif command -v cfonts &>/dev/null; then
    cfonts "LINUX" -f block -c yellow,blue -a center
else
    echo -e "\033[1;33m  =============================="
    echo -e "      K A L I   L I N U X"
    echo -e "  ==============================\033[0m"
fi
echo ""
echo -e "\${reset}  ╔══════════════════════════════════════════╗"
echo -e "\${reset}  ║  ⚡ Website: https://sandeeptech.com ⚡  ║"
echo -e "\${reset}  ╚══════════════════════════════════════════╝"
echo ""
echo -e "\${red} [*] Starting Kali Linux (ROOT Mode)...\${reset}"
echo ""

user=root
home=/root

export PROOT_TMPDIR="PREFIX_PLACEHOLDER/tmp"
mkdir -p "PREFIX_PLACEHOLDER/tmp"

exec proot \\
    --link2symlink \\
    -0 \\
    -r DEST_PLACEHOLDER \\
    -b /dev \\
    -b /proc \\
    -b DEST_PLACEHOLDER/dev:/dev/shm \\
    -b /sdcard \\
    -b HOME_PLACEHOLDER \\
    -w \${home} \\
    /usr/bin/env -i \\
    HOME=\${home} \\
    USER=root \\
    LOGNAME=root \\
    TERM="\${TERM:-xterm-256color}" \\
    LANG=C.UTF-8 \\
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \\
    /bin/bash --login "\${@}"
EOM

	# Replace placeholders with actual values
	sed -i "s|DEST_PLACEHOLDER|${DESTINATION}|g" "$bin"
	sed -i "s|HOME_PLACEHOLDER|${HOME}|g" "$bin"
	sed -i "s|PREFIX_PLACEHOLDER|${PREFIX}|g" "$bin"
	chmod 700 $bin
}

printline() {
	printf "\n${blue}"
	echo " #---------------------------------#"
}

# Start
clear
EXTRAARGS=""
if [[ ! -z $1 ]]; then
    EXTRAARGS=$1
    if [[ $EXTRAARGS != "--insecure" ]]; then
		EXTRAARGS=""
    fi
fi

# ── Install cfonts silently ──────────────────────────────────
printf "${blue} [*] Installing banner dependencies...${reset}\n"

# Termux uses 'pkg' for its own packages (not apt-get)
pkg install nodejs -y &>/dev/null 2>&1 || true
npm install -g cfonts &>/dev/null 2>&1 || true

# ── Clear screen so install text doesn't show above banner ───
clear

# ── Show cfonts banner ───────────────────────────────────────
CFONTS_BIN="$PREFIX/bin/cfonts"
if [ -f "$CFONTS_BIN" ]; then
    "$CFONTS_BIN" "SANDEEP" -f slick -c white,blue -a center
elif command -v cfonts &>/dev/null; then
    cfonts "SANDEEP" -f slick -c white,blue -a center
else
    echo -e "${cyan}  ======================================"
    echo -e "${cyan}       S A N D E E P   T E C H"
    echo -e "${cyan}  ======================================${reset}"
fi
echo -e "${reset}  ╔══════════════════════════════════════════╗"
echo -e "${reset}  ║    ⚡  Created By - SANDEEP TECH  ⚡    ║"
echo -e "${reset}  ╚══════════════════════════════════════════╝"

# ─────────────────────────────────────────────────
#  ACTIVATION KEY GATE
# ─────────────────────────────────────────────────
check_activation_key() {
    local VALID_KEY="de4f0114611aab15fef8881083f2de10"
    local MAX_ATTEMPTS=3
    local attempt=1

    echo -e "${yellow}  ╔══════════════════════════════════════════╗"
    echo -e "  ║      🔐  ACTIVATION KEY REQUIRED        ║"
    echo -e "  ╚══════════════════════════════════════════╝${reset}"
    echo ""
    echo -e "${blue}  This installer requires an activation key."
    echo ""
    echo -e "${cyan}  📖 Get your FREE key:"
    echo -e "${yellow}     https://sandeeptech.com"
    echo ""
    echo -e "${reset}  ➤ Visit the site & read the Kali Linux"
    echo -e "    installation blog to find your key."
    echo ""
    echo -e "${blue}  ──────────────────────────────────────────${reset}"
    echo ""

    while [ $attempt -le $MAX_ATTEMPTS ]; do
        [ $attempt -gt 1 ] && echo -e "${red}  ✗ Incorrect key! Attempt ${attempt}/${MAX_ATTEMPTS}${reset}\n"

        printf "${yellow}  🔑 Enter activation key: ${reset}"
        read -r USER_KEY
        USER_KEY=$(echo "$USER_KEY" | tr -d '[:space:]')

        if [ "$USER_KEY" = "$VALID_KEY" ]; then
            echo ""
            echo -e "${green}  ╔══════════════════════════════════════════╗"
            echo -e "  ║  ✅  Key Verified! Starting Install...   ║"
            echo -e "  ╚══════════════════════════════════════════╝${reset}"
            echo ""
            sleep 1
            return 0
        fi
        attempt=$((attempt + 1))
    done

    echo ""
    echo -e "${red}  ╔══════════════════════════════════════════╗"
    echo -e "  ║  ✗  Invalid Key. Access Denied.         ║"
    echo -e "  ╠══════════════════════════════════════════╣"
    echo -e "  ║  Get your key at:                       ║"
    echo -e "  ║  ${yellow}https://sandeeptech.com${red}               ║"
    echo -e "  ╚══════════════════════════════════════════╝${reset}"
    echo ""
    exit 1
}

check_activation_key

printf "${yellow} [*] Initializing Kali NetHunter Installation...${reset}\n"
echo ""


pre_cleanup
checksysinfo
checkdeps
setchroot
DESTINATION=$HOME/chroot/kali-$SETARCH
gettarfile
checkintegrity
extract
createloginfile

printf "\n${blue} [*] Configuring Kali For You ..."

# Utility function for resolv.conf
resolvconf() {
	#create resolv.conf file
	printf "nameserver 8.8.8.8\nnameserver 8.8.4.4\n" > $DESTINATION/etc/resolv.conf
}
resolvconf

##############
# st-kali.sh #
##############

finalwork() {
	[ -e $HOME/st-kali.sh ] && rm $HOME/st-kali.sh
	echo
	# Download st-kali.sh from GitHub
	wget -q "https://raw.githubusercontent.com/sandeeptechcloud/kali-linux/refs/heads/main/st-kali.sh" -O $HOME/st-kali.sh || \
		curl -sL "https://raw.githubusercontent.com/sandeeptechcloud/kali-linux/refs/heads/main/st-kali.sh" -o $HOME/st-kali.sh
	if [ -f "$HOME/st-kali.sh" ] && [ -s "$HOME/st-kali.sh" ]; then
		DESTINATION=$DESTINATION SETARCH=$SETARCH bash $HOME/st-kali.sh
	else
		printf "${yellow} [!] Could not download st-kali.sh, skipping...${reset}\n"
	fi
}
finalwork

post_cleanup

printline
printf "\n${yellow} ╔═══════════════════════════════════════════════════════╗\n"
printf "${yellow} ║     ✅ Installation Complete! Enjoy Kali Nethunter     ║\n"
printf "${yellow} ╚═══════════════════════════════════════════════════════╝\n"
printf "\n"
printf "  ┌─────────────────────────────────────────────┐\n"
printf "  │                                             │\n"
printf "  │   🎮 Type  ${green}kali-linux${yellow}       → Kali User Mode  │\n"
printf "  │   🎮 Type  ${red}kali-linux-root${yellow}   → Kali Root Mode  │\n"
printf "  │                                             │\n"
printf "  └─────────────────────────────────────────────┘\n"
printf "\n"
printline
printf "${reset}\n"
