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
        find $HOME -name "kali*" -type d -exec rm -rf {} \; || :
}

post_cleanup() {
        find $HOME -name "kali*" -type f -exec rm -rf {} \; || :
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
	printf "\n${yellow} ║     🚀 HACKER STYLE INSTALLATION 🚀   ║"
	printf "\n${yellow} ╚═══════════════════════════════════════╝${reset}"
	printf "\n\n${blue} [*] Updating apt cache..."
	apt update -y &> /dev/null
	echo "\n [*] Checking for all required tools..."

	for i in proot tar axel; do
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

	# Install nodejs and cfonts for hacker-style banner
	echo ""
	echo "  ██╗    ██╗ █████╗ ███████╗██╗   ██╗"
	echo "  ██║    ██║██╔══██╗██╔════╝██║   ██║"
	echo "  ██║ █╗ ██║███████║███████╗██║   ██║"
	echo "  ██║███╗██║██╔══██║╚════██║██║   ██║"
	echo "  ╚███╔███╔╝██║  ██║███████║╚██████╔╝"
	echo "   ╚══╝╚══╝ ╚═╝  ╚═╝╚══════╝ ╚═════╝ "
	echo ""

	printf "${yellow} [*] Installing Node.js and cfonts...${reset}\n"
	apt-get install wget -y &> /dev/null
	apt-get install nodejs -y &> /dev/null
	npm install cfonts -g 2>/dev/null || {
		printf "${yellow} [!] cfonts install failed, using fallback${reset}\n"
	}

	apt upgrade -y
}

# URLs of all possibls architectures
seturl() {
	URL="https://kali.download/nethunter-images/current/rootfs/kali-nethunter-rootfs-${chroot}-${SETARCH}.tar.xz"
	# Fallback mirror
	MIRROR_URL="https://github.com/termux/proot-distro/releases/download/v3.10.0/kali-${SETARCH}-pd-v3.10.0.tar.xz"
}

# Utility function to get tar file
gettarfile() {
    seturl
    printf "\n$blue} [*] Fetching tar file"
    printf "\n from ${URL}"
    cd $HOME
    rootfs="kali-nethunter-rootfs-${chroot}-${SETARCH}.tar.xz"
    printf "\n [*] Placing ${rootfs}"
    DESTINATION=$HOME/chroot/kali-$SETARCH
    printf "\n into {$DESTINATION}"
    printf "${reset}\n"
    if [ ! -f "$rootfs" ]; then
        axel ${EXTRAARGS} --alternate "$URL"
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

# Utility function to extract tar file
extract() {
	printf "\n${blue} [*] Extracting ${rootfs}"
        printf "\n into ${DESTINATION}"
        printf "${reset}\n"
	proot --link2symlink \
		tar -xf "$rootfs" \
		-C $HOME 2>/dev/null || :
}

# Utility function for login file
createloginfile() {
	DESTINATION=$HOME/chroot/kali-$SETARCH

	# Create kali-linux command (user mode)
	bin=$PREFIX/bin/kali-linux
        printf "\n${blue} [*] Creating ${bin}"
        printf "${reset}\n"
	cat > $bin <<- EOM
#!/data/data/com.termux/files/usr/bin/bash
unset LD_PRELOAD

# colors
red='\033[1;31m'
yellow='\033[1;33m'
green='\033[1;32m'
cyan='\033[1;36m'
reset='\033[0m'

# Show SANDEEP-TECH banner
clear
echo ""
echo -e "${yellow} ╔═══════════════════════════════════════════════════════════════╗"
echo -e "${yellow} ║                                                               ║"
echo -e "${yellow} ║   ███████╗██████╗ ██████╗  ██████╗ ███╗   ███╗               ║"
echo -e "${yellow} ║   ██╔════╝██╔══██╗██╔══██╗██╔═══██╗████╗ ████║               ║"
echo -e "${yellow} ║   █████╗  ██████╔╝██████╔╝██║   ██║██╔████╔██║               ║"
echo -e "${yellow} ║   ██╔══╝  ██╔══██╗██╔══██╗██║   ██║██║╚██╔╝██║               ║"
echo -e "${yellow} ║   ███████╗██║  ██║██║  ██║╚██████╔╝██║ ╚═╝ ██║               ║"
echo -e "${yellow} ║   ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝ ╚═╝     ╚═╝               ║"
echo -e "${yellow} ║                                                               ║"
echo -e "${yellow} ║   ███████╗ ██████╗ ██████╗  ██████╗  █████╗ ███╗   ██╗      ║"
echo -e "${yellow} ║   ██╔════╝██╔═══██╗██╔══██╗██╔════╝ ██╔══██╗████╗  ██║      ║"
echo -e "${yellow} ║   ███████╗██║   ██║██████╔╝██║  ███╗███████║██╔██╗ ██║      ║"
echo -e "${yellow} ║   ╚════██║██║   ██║██╔══██╗██║   ██║██╔══██║██║╚██╗██║      ║"
echo -e "${yellow} ║   ███████║╚██████╔╝██║  ██║╚██████╔╝██║  ██║██║ ╚████║      ║"
echo -e "${yellow} ║   ╚══════╝ ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═══╝      ║"
echo -e "${yellow} ║                                                               ║"
echo -e "${yellow} ╚═══════════════════════════════════════════════════════════════╝"
echo -e "${cyan}              ████████╗██╗  ██╗███████╗    ███████╗               ║"
echo -e "${cyan}              ╚══██╔══╝██║  ██║██╔════╝    ██╔════╝               ║"
echo -e "${cyan}                 ██║   ███████║█████╗      █████╗                 ║"
echo -e "${cyan}                 ██║   ██╔══██║██╔══╝      ██╔══╝                 ║"
echo -e "${cyan}                 ██║   ██║  ██║███████╗    ███████╗               ║"
echo -e "${cyan}                 ╚═╝   ╚═╝  ╚═╝╚══════╝    ╚══════╝               ║"
echo -e "${cyan}                                                              ║"
echo -e "${cyan}              ██████╗ ███████╗███╗   ██╗███████╗██████╗          ║"
echo -e "${cyan}              ██╔══██╗██╔════╝████╗  ██║██╔════╝██╔══██╗         ║"
echo -e "${cyan}              ██████╔╝█████╗  ██╔██╗ ██║█████╗  ██████╔╝         ║"
echo -e "${cyan}              ██╔══██╗██╔══╝  ██║╚██╗██║██╔══╝  ██╔══██╗         ║"
echo -e "${cyan}              ██████╔╝███████╗██║ ╚████║███████╗██║  ██║         ║"
echo -e "${cyan}              ╚═════╝ ╚══════╝╚═╝  ╚═══╝╚══════╝╚═╝  ╚═╝         ║"
echo -e "${cyan}                                                              ║"
echo -e "${cyan}     ██████╗██████╗  █████╗ ███████╗██╗  ██╗                     ║"
echo -e "${cyan}    ██╔════╝██╔══██╗██╔══██╗██╔════╝██║  ██║                     ║"
echo -e "${cyan}    ██║     ██████╔╝███████║███████╗███████║                     ║"
echo -e "${cyan}    ██║     ██╔══██╗██╔══██║╚════██║██╔══██║                     ║"
echo -e "${cyan}     ╚██████╗██║  ██║██║  ██║███████║██║  ██║                     ║"
echo -e "${cyan}      ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝                     ║"
echo ""
echo -e "${reset}  ╔═══════════════════════════════════════════════════════╗"
echo -e "${reset}  ║           ⚡ Created by Sandeep Tech ⚡              ║"
echo -e "${reset}  ╚═══════════════════════════════════════════════════════╝"
echo ""
echo -e "${green} [*] Starting Kali Linux (User Mode)...${reset}"
echo ""

user=kali
home=DEST_PLACEHOLDER/home/$user
LOGIN="sudo -u \$user /bin/bash"

cmd="proot \\
    --link2symlink \\
    -0 \\
    -r DEST_PLACEHOLDER \\
    -b /dev \\
    -b /proc \\
    -b DEST_PLACEHOLDER/dev:/dev/shm \\
    -b /sdcard \\
    -b HOME_PLACEHOLDER \\
    -w \${home} \\
    PREFIX_PLACEHOLDER/bin/env -i \\
    HOME=\${home} TERM=\${TERM} \\
    LANG=\${LANG} \\
    PATH=DEST_PLACEHOLDER/bin:\${home}/bin:DEST_PLACEHOLDER/sbin:\${home}/sbin:DEST_PLACEHOLDER/etc:\${home}/bin \\
    \${LOGIN}"

args="\${@}"
if [ "\${#}" == 0 ]; then
    exec \$cmd
else
    \$cmd -c "\${args}"
fi
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
	cat > $bin <<- EOM
#!/data/data/com.termux/files/usr/bin/bash
unset LD_PRELOAD

# colors
red='\033[1;31m'
yellow='\033[1;33m'
green='\033[1;32m'
cyan='\033[1;36m'
reset='\033[0m'

# Show SANDEEP-TECH banner
clear
echo ""
echo -e "${yellow} ╔═══════════════════════════════════════════════════════════════╗"
echo -e "${yellow} ║                                                               ║"
echo -e "${yellow} ║   ███████╗██████╗ ██████╗  ██████╗ ███╗   ███╗               ║"
echo -e "${yellow} ║   ██╔════╝██╔══██╗██╔══██╗██╔═══██╗████╗ ████║               ║"
echo -e "${yellow} ║   █████╗  ██████╔╝██████╔╝██║   ██║██╔████╔██║               ║"
echo -e "${yellow} ║   ██╔══╝  ██╔══██╗██╔══██╗██║   ██║██║╚██╔╝██║               ║"
echo -e "${yellow} ║   ███████╗██║  ██║██║  ██║╚██████╔╝██║ ╚═╝ ██║               ║"
echo -e "${yellow} ║   ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝ ╚═╝     ╚═╝               ║"
echo -e "${yellow} ║                                                               ║"
echo -e "${yellow} ║   ███████╗ ██████╗ ██████╗  ██████╗  █████╗ ███╗   ██╗      ║"
echo -e "${yellow} ║   ██╔════╝██╔═══██╗██╔══██╗██╔════╝ ██╔══██╗████╗  ██║      ║"
echo -e "${yellow} ║   ███████╗██║   ██║██████╔╝██║  ███╗███████║██╔██╗ ██║      ║"
echo -e "${yellow} ║   ╚════██║██║   ██║██╔══██╗██║   ██║██╔══██║██║╚██╗██║      ║"
echo -e "${yellow} ║   ███████║╚██████╔╝██║  ██║╚██████╔╝██║  ██║██║ ╚████║      ║"
echo -e "${yellow} ║   ╚══════╝ ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═══╝      ║"
echo -e "${yellow} ║                                                               ║"
echo -e "${yellow} ╚═══════════════════════════════════════════════════════════════╝"
echo -e "${cyan}              ████████╗██╗  ██╗███████╗    ███████╗               ║"
echo -e "${cyan}              ╚══██╔══╝██║  ██║██╔════╝    ██╔════╝               ║"
echo -e "${cyan}                 ██║   ███████║█████╗      █████╗                 ║"
echo -e "${cyan}                 ██║   ██╔══██║██╔══╝      ██╔══╝                 ║"
echo -e "${cyan}                 ██║   ██║  ██║███████╗    ███████╗               ║"
echo -e "${cyan}                 ╚═╝   ╚═╝  ╚═╝╚══════╝    ╚══════╝               ║"
echo -e "${cyan}                                                              ║"
echo -e "${cyan}              ██████╗ ███████╗███╗   ██╗███████╗██████╗          ║"
echo -e "${cyan}              ██╔══██╗██╔════╝████╗  ██║██╔════╝██╔══██╗         ║"
echo -e "${cyan}              ██████╔╝█████╗  ██╔██╗ ██║█████╗  ██████╔╝         ║"
echo -e "${cyan}              ██╔══██╗██╔══╝  ██║╚██╗██║██╔══╝  ██╔══██╗         ║"
echo -e "${cyan}              ██████╔╝███████╗██║ ╚████║███████╗██║  ██║         ║"
echo -e "${cyan}              ╚═════╝ ╚══════╝╚═╝  ╚═══╝╚══════╝╚═╝  ╚═╝         ║"
echo -e "${cyan}                                                              ║"
echo -e "${cyan}     ██████╗██████╗  █████╗ ███████╗██╗  ██╗                     ║"
echo -e "${cyan}    ██╔════╝██╔══██╗██╔══██╗██╔════╝██║  ██║                     ║"
echo -e "${cyan}    ██║     ██████╔╝███████║███████╗███████║                     ║"
echo -e "${cyan}    ██║     ██╔══██╗██╔══██║╚════██║██╔══██║                     ║"
echo -e "${cyan}     ╚██████╗██║  ██║██║  ██║███████║██║  ██║                     ║"
echo -e "${cyan}      ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝                     ║"
echo ""
echo -e "${reset}  ╔═══════════════════════════════════════════════════════╗"
echo -e "${reset}  ║           ⚡ Created by Sandeep Tech ⚡              ║"
echo -e "${reset}  ╚═══════════════════════════════════════════════════════╝"
echo ""
echo -e "${red} [*] Starting Kali Linux (ROOT Mode)...${reset}"
echo ""

user=root
home=DEST_PLACEHOLDER/root
LOGIN="/bin/bash --login"

cmd="proot \\
    --link2symlink \\
    -0 \\
    -r DEST_PLACEHOLDER \\
    -b /dev \\
    -b /proc \\
    -b DEST_PLACEHOLDER/dev:/dev/shm \\
    -b /sdcard \\
    -b HOME_PLACEHOLDER \\
    -w \${home} \\
    PREFIX_PLACEHOLDER/bin/env -i \\
    HOME=\${home} TERM=\${TERM} \\
    LANG=\${LANG} \\
    PATH=DEST_PLACEHOLDER/bin:\${home}/bin:DEST_PLACEHOLDER/sbin:\${home}/sbin:DEST_PLACEHOLDER/etc:\${home}/bin \\
    \${LOGIN}"

args="\${@}"
if [ "\${#}" == 0 ]; then
    exec \$cmd
else
    \$cmd -c "\${args}"
fi
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

echo ""
echo -e "${yellow} ╔═══════════════════════════════════════════════════════════════╗"
echo -e "${yellow} ║                                                               ║"
echo -e "${yellow} ║    ███╗   ██╗███████╗ ██████╗ ██████╗  ██████╗  ██████╗██╗  ██║║"
echo -e "${yellow} ║    ████╗  ██║██╔════╝██╔═══██╗██╔══██╗██╔════╝ ██╔════╝██║  ██║║"
echo -e "${yellow} ║    ██╔██╗ ██║█████╗  ██║   ██║██████╔╝██║  ███╗██║     ███████║║"
echo -e "${yellow} ║    ██║╚██╗██║██╔══╝  ██║   ██║██╔══██╗██║   ██║██║     ██╔══██║║"
echo -e "${yellow} ║    ██║ ╚████║███████╗╚██████╔╝██║  ██║╚██████╔╝╚██████╗██║  ██║║"
echo -e "${yellow} ║    ╚═╝  ╚═══╝╚══════╝ ╚═════╝ ╚═╝  ╚═╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝║║"
echo -e "${yellow} ║                                                               ║"
echo -e "${yellow} ║   ██████╗ ███████╗███╗   ██╗███████╗ ██████╗ ██╗     ███████╗██████╗║"
echo -e "${yellow} ║   ██╔══██╗██╔════╝████╗  ██║██╔════╝██╔═══██╗██║     ██╔════╝██╔══██║"
echo -e "${yellow} ║   ██████╔╝█████╗  ██╔██╗ ██║█████╗  ██║   ██║██║     █████╗  ██████╔║"
echo -e "${yellow} ║   ██╔══██╗██╔══╝  ██║╚██╗██║██╔══╝  ██║   ██║██║     ██╔══╝  ██╔══██║"
echo -e "${yellow} ║   ██║  ██║███████╗██║ ╚████║███████╗╚██████╔╝███████╗███████╗██║  ██║"
echo -e "${yellow} ║   ╚═╝  ╚═╝╚══════╝╚═╝  ╚═══╝╚══════╝ ╚═════╝ ╚══════╝╚══════╝╚═╝  ╚═╝║"
echo -e "${yellow} ║                                                               ║"
echo -e "${yellow} ╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo -e "${cyan}          ██████╗  █████╗ ███╗   ██╗██╗  ██╗███████╗██████╗"
echo -e "${cyan}          ██╔══██╗██╔══██╗████╗  ██║██║ ██╔╝██╔════╝██╔══██╗"
echo -e "${cyan}          ██████╔╝███████║██╔██╗ ██║█████╔╝ █████╗  ██████╔╝"
echo -e "${cyan}          ██╔══██╗██╔══██║██║╚██╗██║██╔═██╗ ██╔══╝  ██╔══██╗"
echo -e "${cyan}          ██████╔╝██║  ██║██║ ╚████║██║  ██╗███████╗██║  ██║"
echo -e "${cyan}          ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝"
echo ""
echo -e "${reset}  ╔═══════════════════════════════════════════════════════╗"
echo -e "${reset}  ║      ⚡ HACKER EDITION - SANDEEP TECH ⚡               ║"
echo -e "${reset}  ╚═══════════════════════════════════════════════════════╝"
echo ""
printf "${yellow} [*] Initializing Kali NetHunter Installation...${reset}\n"
echo ""

pre_cleanup
checksysinfo
checkdeps
setchroot
gettarfile
checkintegrity
extract
createloginfile
post_cleanup

printf "\n${blue} [*] Configuring Kali For You ..."

# Utility function for resolv.conf
resolvconf() {
	#create resolv.conf file 
	printf "\nnameserver 8.8.8.8\nnameserver 8.8.4.4" > $DESTINATION/etc/resolv.conf
} 
resolvconf

################
# finaltouchup #
################

finalwork() {
	[ -e $HOME/finaltouchup.sh ] && rm $HOME/finaltouchup.sh
	echo
	# Download finaltouchup.sh from GitHub
	axel ${EXTRAARGS} -a "https://raw.githubusercontent.com/sandeeptechcloud/kali-linux/main/finaltouchup.sh" || \
		wget -q "https://raw.githubusercontent.com/sandeeptechcloud/kali-linux/main/finaltouchup.sh" -O $HOME/finaltouchup.sh
	DESTINATION=$DESTINATION SETARCH=$SETARCH bash $HOME/finaltouchup.sh
}
finalwork

printline
printf "\n${yellow} ╔═══════════════════════════════════════════════════════╗"
printf "\n${yellow} ║     ✅ Installation Complete! Enjoy Kali Nethunter     ║"
printf "\n${yellow} ╚═══════════════════════════════════════════════════════╝"
echo ""
echo "  ┌─────────────────────────────────────────────┐"
echo "  │                                             │"
echo "  │   🎮 Type  ${green}kali-linux${yellow}  → Kali User Mode      │"
echo "  │   🎮 Type  ${red}kali-linux-root${yellow} → Kali Root Mode      │"
echo "  │                                             │"
echo "  └─────────────────────────────────────────────┘"
echo ""
printline
printf "${reset}\n"
