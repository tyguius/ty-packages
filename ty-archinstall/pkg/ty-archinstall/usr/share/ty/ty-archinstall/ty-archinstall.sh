#!/bin/bash

###########################################################
# LOG
###########################################################
rm -rf /tmp/ty
mkdir /tmp/ty
echo "#$(date) ${FUNCNAME[0]} log initialized" > /tmp/ty/log

# check if KEYMAP has been changed after start of login shell
if [[ -f /tmp/ty_keymap ]]
then
    KEYMAP=$(cat /tmp/ty_keymap)
    KEYMAP_DEFAULT=false
    echo "KEYMAP=$KEYMAP" >> /tmp/ty/log
else
    KEYMAP_DEFAULT=true
    echo "KEYMAP=default" >> /tmp/ty/log
fi

###########################################################
# DIALOG
###########################################################
# dimensions of dialog boxes
COLS=$(tput cols)
LINES=$(tput lines)
WIDTH=$((COLS/2))
HEIGHT=$((LINES/2))
DIMENSIONS="$HEIGHT $WIDTH"

PACKAGE_VERSION=$(pacman -Q --info ty-archinstall | grep 'Version' | grep -o '[0-9].*')
BACKTITLE="TY-ARCHINSTALL $PACKAGE_VERSION"

# dialog_message TITLE TEXT
dialog_message() {
    dialog --clear --stdout --backtitle "$BACKTITLE" --title "$1" --msgbox "$2" $DIMENSIONS
}

# dialog_yesno TITLE TEXT YESLABEL NOLABEL
dialog_yesno() {
    dialog --clear --stdout --backtitle "$BACKTITLE" --title "$1" --yes-label "$3" --nolabel "$4" --yesno "$2" $DIMENSIONS
}

# dialog_menu TITLE TEXT MENUITEMS[@]
dialog_menu() {
    local _DIALOG_ARGUMENTS=("$@")
    local _MENU_ITEMS=("${_DIALOG_ARGUMENTS[@]:2}")
    dialog --clear --stdout --backtitle "$BACKTITLE" --title "$1" --menu "$2" $DIMENSIONS "$(${#_MENU_ITEMS[@]}\2)" "${_MENU_ITEMS[@]}"
}

###########################################################
# welcome
###########################################################

dialog_message "WELCOME" "Welcome to the install script for Arch Linux by Peter Silikum"

###########################################################
# UEFI bootmode
###########################################################

# test if efivars are present
test_efivars() {
	if ls /sys/firmware/efi/efivars
	then
		true
	else
		false
	fi
}

# try to mount efivars if not present
mount_efivars() {
	mount -t efivars efivars /sys/firmware/efi/efivars
}

if ! test_efivars
then
    if mount_efivars
    then
        UEFI=true
        LOGMESSAGE="efivars mounted by ty-archinstall script"
    else
        UEFI=false
        LOGMESSAGE="could not stat efivars"
    fi
else
    UEFI=true
    LOGMESSAGE="efivars mounted at bootup"
fi
clear
echo "$(date) $LOGMESSAGE" >> /tmp/ty/log

if $UEFI
then
    BOOTMODE="UEFI bootmode checked successfully"
    echo "$(date) $BOOTMODE" >> /tmp/ty/log
    MESSAGE="$LOGMESSAGE\n$BOOTMODE"
else
    MESSAGE=$LOGMESSAGE
fi

dialog_message "BOOTMODE" "$MESSAGE"

###########################################################
# NETWORK CHECK
###########################################################

if ping -c 4 archlinux.org
then
    ONLINE=true
    MESSAGE="Successfully established Internet Connection"
else
    ONLINE=false
    MESSAGE="Could not establish Internet Connection"
fi

echo "$(date) $MESSAGE" >> /tmp/ty/log
dialog_message "NETWORK CHECK" "$MESSAGE"

if ! $ONLINE
then
    dialog_message "NETWORK CHECK" "Connecting via WIFI not yet supported"
    exit 1
fi

###########################################################
# CLOCK
###########################################################
if timedatectl set-ntp true
then
    MESSAGE="'timedatectl set-ntp true' successfull"
    NTP=true
else
    MESSAGE="'timedatectl set-ntp true' not successfull"
    NTP=false
fi

(echo "$(date) $MESSAGE"; echo "timedatectl status") >> /tmp/ty/log
timedatectl status >> /tmp/ty/log

dialog_message "SYSTEM CLOCK" "$MESSAGE"

###########################################################
# LOCALE
###########################################################

confirm_locale() {
    LOCALE_VARIABLES=("$@")
    dialog_yesno "$TITLE" "Continue with this choice?\n$1 for \n${LOCALE_VARIABLES[*]:1}" "CONFIRM" "BACK" #"${LOCALE_MENUITEMS[@]}"
}

choose_locale_system() {
    SYSTEM_LOCALE_VARIABLES=( 'LANG' 'LC_MESSAGES' 'LC_CTYPE' 'LC_NUMERIC' )
    SYSTEM_LOCALE=$(dialog_menu "SYSTEM LOCALE" "Please choose System locale:" "${LOCALE_MENUITEMS[@]}" )
    if confirm_locale "$SYSTEM_LOCALE" "${SYSTEM_LOCALE_VARIABLES[@]}"
    then
        LOCALES+=("$SYSTEM_LOCALE")
        echo "LANGUAGE=$SYSTEM_LOCALE:en_US.UTF8:en_US:en:C" >> /tmp/ty/locale.conf
        echo "LC_COLLATE=C" >> /tmp/ty/locale.conf
        for VARIABLE in "${SYSTEM_LOCALE_VARIABLES[@]}"
        do
            echo "$VARIABLE=$SYSTEM_LOCALE" >> /tmp/ty/locale.conf
        done
    else
        choose_locale_system
    fi
}

choose_locale_area() {
    AREA_LOCALE_VARIABLES=( 'LC_TIME' 'LC_MONETARY' 'LC_PAPER' 'LC_NAME' 'LC_ADDRESS' 'LC_TELEPHONE' 'LC_MEASUREMENT' )
    AREA_LOCALE=$(dialog_menu "AREA LOCALE" "Please choose Area (localization) locale:" "${LOCALE_MENUITEMS[@]}" )
    if confirm_locale "$AREA_LOCALE" "${AREA_LOCALE_VARIABLES[@]}"
    then
        LOCALES+=("$AREA_LOCALE")
        for VARIABLE in "${AREA_LOCALE_VARIABLES[@]}"
        do
            echo "$VARIABLE=$AREA_LOCALE" >> /tmp/ty/locale.conf
        done
    else
        choose_locale_local
    fi
}

TITLE="LOCALE"
LOCALE_MENUITEMS=( 'de_DE.UTF-8' 'Deutsch' 'en_GB.UTF-8' 'British English' 'en_US.UTF-8' 'US English' )
LOCALES=()

choose_locale_system

choose_locale_area

###########################################################
# USER & HOST
###########################################################
TITLE="MAIN USER"

confirm_username() {
    dialog_yesno "$TITLE" "Continue with these choices?\nUSER: '$USER_NAME'\nfull name: '$USER_NAME_FULL'" "CONFIRM" "BACK"
}

get_username() {
    USER_NAME_FULL=$(dialog --clear --stdout --backtitle "$BACKTITLE" --title "$TITLE" --inputbox "Please enter full Name for main user (sudoer):" $DIMENSIONS)
    USER_NAME_PROPOSITION=$(echo ${USER_NAME_FULL,,} | awk '{ print $1 }')
    USER_NAME=$(dialog --clear --stdout --backtitle "$BACKTITLE" --title "$TITLE" --inputbox "Please enter username for $USER_NAME_FULL:" $DIMENSIONS "$USER_NAME_PROPOSITION")
    if ! confirm_username
    then
        get_username
    fi
}

get_username

TITLE="HOSTNAME"
confirm_hostname() {
    dialog_yesno "$TITLE" "Continue with this choice?\nhostname: $HOST_NAME" "CONFIRM" "BACK"
}

get_hostname() {
    HOST_NAME=$(dialog --clear --stdout --backtitle "$BACKTITLE" --title "$TITLE" --inputbox "Please enter hostname:" $DIMENSIONS)
    if [[ ${#HOSTNAME} -le 16 ]] && [[ "$HOST_NAME" != *[^[:alpha:]]* ]]
    then
        if ! confirm_hostname
        then
            get_hostname
        fi
    else
        dialog_message "HOSTNAME" "invalid input, try again.\nhostname may contain no special characters and can be no longer than 16 characters! (will be used for disk label of system partition, can be changed after install)"
        get_hostname
    fi
}

get_hostname
###########################################################
# DISK LAYOUT
###########################################################
DEVICES=($(fdisk -l | grep "^/dev/" | awk '{ print $1 }'))

format_disk() {
    cfdisk
    DEVICES=$(fdisk -l | grep "^/dev/" | awk '{ print $1 }')
    if [[ ${#DEVICES[@]} -eq 1 ]]
    then
        format_disk
    fi
}

current_disk_layout() {
    (echo  "Want to continue with this Disk Layout?"; echo ""; echo "";) > /tmp/ty/current_disk_layout
    lsblk -lo NAME,FSTYPE,FSVER,LABEL,FSAVAIL,MOUNTPOINTS >> /tmp/ty/current_disk_layout
    (echo ""; echo ""; echo "Disk Layout cannot be changed during mounting") >> /tmp/ty/current_disk_layout
}

confirm_disk_layout() {
    current_disk_layout
    dialog_yesno "DISK LAYOUT" "$(cat /tmp/ty/current_disk_layout)" "MOUNT DRIVES" "PARTITION DISK"
}

disk_layout() {
#     if [[ ${#DEVICES[@]} -eq 1 ]]
#     then
#         format_disk
#     fi
    if ! confirm_disk_layout
    then
        cfdisk
        disk_layout
    fi
}

disk_layout

###########################################################
# MOUNT DEVICES
###########################################################

# prompt user to choose a device from a list of devices not yet selected
choose_device() {
    MESSAGE="$1"
    DEVICE_MENUITEMS=()
    for DEVICE in "${DEVICES[@]}"
    do
        DEVICE_LABEL=$(lsblk -no LABEL $DEVICE)
        DEVICE_SIZE=$(fdisk -lo SIZE | grep $DEVICE | awk '{ print $3 }')
        if [[ -n $DEVICE_LABEL ]]
        then
            DEVICE_DESCRIPTION="$DEVICE_SIZE - $DEVICE_LABEL"
        else
            DEVICE_DESCRIPTION="$DEVICE_SIZE - $DEVICE"
        fi
        DEVICE_MENUITEMS+=( "$DEVICE" "$DEVICE_DESCRIPTION")
    done
    DEVICE_SELECTED=$(dialog_menu "DISK LAYOUT" "$MESSAGE" "${DEVICE_MENUITEMS[@]}")
    echo $DEVICE_SELECTED
}

# choose partition, create & label ext4 filesystem for /
mount_root_partition()  {

    ROOT_DEVICE=$(choose_device "Please choose partition to mount at /")
    mkfs.ext4 -L $HOST_NAME $ROOT_DEVICE
    if mount "$ROOT_DEVICE" "/mnt"
    then
        DEVICES=( "${DEVICES[@]/$ROOT_DEVICE}" )
        echo "ROOT_DEVICE=$ROOT_DEVICE" >> /tmp/ty/log
        dialog_message "ROOT PARTITION" "device $ROOT_DEVICE succesfully mounted at /mnt"
    else
        dialog_message "DISK LAYOUT" "could not mount $ROOT_DEVICE at /mnt"
        mount_root_partition
    fi
}
DEVICES=($(fdisk -l | grep "^/dev/" | awk '{ print $1 }'))
mount_root_partition

# choose and optionally format efi system partition
TITLE="EFI PARTITION"

mount_efi_partition() {
    # choose path to efi system partition
    EFI_PATH_MENUITEMS=('/efi' 'recommended' '/boot/efi' '' '/boot' '')
    EFI_PATH=$(dialog_menu "$TITLE" "please choose mount point for efi partition:" "${EFI_PATH_MENUITEMS[@]}")
    EFI_DEVICE=$(choose_device "Please choose device to mount at $EFI_PATH:")

    # otionally format device
    if dialog_yesno "$TITLE" "wipe and create new file system on $EFI_DEVICE?" "FORMAT TO fat32" "CONTINUE"
    then
        mkfs.fat -F 32 -n "EFI_BOOT" $EFI_DEVICE
    fi

    # mount efi system partition
    if mount --mkdir "$EFI_DEVICE" "/mnt$EFI_PATH"
    then
        DEVICES=( "${DEVICES[@]/$EFI_DEVICE}" )
        echo "EFI_PATH=$EFI_PATH" >> /tmp/ty/log
        echo "EFI_DEVICE=$EFI_DEVICE" >> /tmp/ty/log
        dialog_message "$TITLE" "device $EFI_DEVICE succesfully mounted at /mnt$EFI_PATH"
    else
        dialog_message "DISK LAYOUT" "could not mount $EFI_DEVICE at /mnt$EFI_PATH"
        mount_efi_partition
    fi
}

mount_efi_partition

# choose and optionally inititlize swap partition
TITLE="SWAP PARTITION"
swap_partition() {
    if dialog_yesno "$TITLE" "use separate partition for swap?" "SWAP PARTITION" "CONTINUE WITHOUT SWAP PARTITION"
    then
        # choose partition to use for swap
        SWAP_DEVICE=$(choose_device "Please choose SWAP partition:")
        # optionally initialize swap on chosen partition
        if dialog_yesno "$TITLE" "initialize swap partition or continue with present swap?" "INITIALIZE SWAP" "CONTINUE"
        then
            mkswap -L "SWAP" $SWAP_DEVICE
        fi
        # turn swap on
        if swapon $SWAP_DEVICE
        then
            DEVICES=( "${DEVICES[@]/$SWAP_DEVICE}" )
            echo "SWAP_DEVICE=$SWAP_DEVICE" >> /tmp/ty/log
            dialog_message "$TITLE" "SWAP initialized successfully at $SWAP_DEVICE"
        else
            dialog_message "$TITLE" "could not initialize SWAP at $SWAP_DEVICE"
            swap_partition
        fi
    fi
}

swap_partition

# optionally mount additional devices
TITLE="EXTRA DEVICES"
mount_extra_devices() {
    current_disk_layout
    if dialog_yesno "$TITLE" "$(cat /tmp/ty/current_disk_layout)" "MOUNT EXTRA DEVICES" "CONTINUE WITH CURRENT LAYOUT"
    then
        EXTRA_DEVICE=$(choose_device "Please choose device to mount:")
        EXTRA_MOUNTPOINT=$(choose_mountpoint $EXTRA_DEVICE)
        if mount --mkdir "$EXTRA_DEVICE" "/mnt$EXTRA_MOUNTPOINT"
        then
            DEVICES=( "${DEVICES[@]/$EXTRA_DEVICE}" )
            (echo "$(date) succesfully mounted:"; echo "$EXTRA_DEVICE $EXTRA_MOUNTPOINT") >> /tmp/ty/log
            dialog_message "$TITLE" "device $EXTRA_DEVICE succesfully mounted at /mnt$EXTRA_MOUNTPOINT"
        else
            dialog_mesage "$TITLE" "could not mount $EXTRA_DEVICE at /mnt$EXTRA_MOUNTPOINT"
        fi
        mount_extra_devices
    fi
}

mount_extra_devices

###########################################################
# PACSTRAP
###########################################################
TITLE="PACSTRAP"
# TODO: confirm disk layout before continue
# TODO: update mirrorlist

dialog_message "$TITLE" "Continue with pacstrap"

# pacstrap default packages
# TODO: make packagelist editable
pacstrap -K /mnt linux linux-firmware linux-headers intel-ucode base base-devel dialog man-db man-pages texinfo sudo mc bash-completion btop networkmanager

genfstab -U /mnt >> /mnt/etc/fstab

# enable Repos:
cp -f /etc/pacman.conf /mnt/etc/pacman.conf

###########################################################
# TIMEZONE
###########################################################
# TODO: choose timezone
arch-chroot /mnt ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime
sleep 5
arch-chroot /mnt hwclock --systohc
sleep 5

###########################################################
# LOCALE
###########################################################
cp /tmp/ty/locale.conf /mnt/etc/locale.conf
echo "" >> /mnt/etc/locale.gen
echo "# locales enabled by ty-archinstall.sh" >> /mnt/etc/locale.gen
for LOCALE in "${LOCALES[@]}"
do
    echo "$LOCALE UTF-8" >> /mnt/etc/locale.gen
done

if ! $KEYMAP_DEFAULT
then
    echo "KEYMAP=de" >> /mnt/etc/vconsole.conf
fi

arch-chroot /mnt locale-gen

###########################################################
# NETWORK CONFIGURATION
###########################################################
echo "$HOST_NAME" > /mnt/etc/hostname

arch-chroot /mnt systemctl enable NetworkManager
sleep 10
if [[ -L /mnt/etc/systemd/system/network-online.target.wants/NetworkManager-wait-online.service ]]
then
    MESSAGE="enabling 'NetworkManager.service' appears to have worked"
else
    MESSAGE="enabling 'NetworkManager.service' appears to NOT have worked"
fi

dialog_message "NETWORK CONFIGURATION" "$MESSAGE"

###########################################################
# SHELL & EDITOR
###########################################################



# choose default login shell for main user
choose_login_shell() {
    USER_SHELL_MENUITEMS=('bash' 'Bourne Again SHell (default)' 'fish' 'Friendly Interactive SHell' 'ksh' 'Korn SHell' 'zsh' 'Z Shell (default on macOS)')
    USER_SHELL=$(dialog_menu "USER LOGIN SHELL" "Please choose the default login shell for $USER_NAME '$USER_NAME_FULL'\nShells other than bash will be installed, if you want to install additional shells, you can install them later manually:" "${USER_SHELL_MENUITEMS[@]}")
    if [[ "$USER_SHELL" != "bash" ]]
    then
        arch-chroot /mnt pacman -S $USER_SHELL --noconfirm
    fi
    echo "USER_SHELL=$USER_SHELL" >> /tmp/ty/log
}
# choose editor to set as default in environment variable $EDITOR
choose_editor() {
    EDITOR_MENUITEMS=('vi' 'VIsual editor' 'vim' 'VI Improved' 'nano' 'Pico text editor emulation' )
    EDITOR=$(dialog_menu "EDITOR" "Please choose editor to set as default in environment variable \$EDITOR" "${EDITOR_MENUITEMS[@]}")
    arch-chroot /mnt pacman -S $EDITOR --noconfirm
    echo "EDITOR=$EDITOR" >> /mnt/etc/environment
    echo "EDITOR=$EDITOR" >> /tmp/ty/log
}

choose_login_shell

choose_editor

###########################################################
# PACKAGES
###########################################################
server_install() {
    arch-chroot /mnt pacman -S openssh emacs
    arch-chroot /mnt systemctl enable sshd.service
    sleep 10
}

choose_desktop_packages() {
    DESKTOP_PACKAGES_MENUITEMS=('ty-devel-school-meta' 'IDEs and stuff' 'off' 'ty-kde-multimedia' 'video, photos and stuff' 'off' 'ty-kde-utilities-meta' 'system administration utilities' 'off' 'ty-plasma-desktop' 'KDE Plasma customization' 'off' )
    DESKTOP_PACKAGES_OPTIONAL=$(dialog --clear --stdout --backtitle "$BACKTITLE" --title "$TITLE" --checklist "Please choose Desktop packages to install:" $DIMENSIONS 0 "${DESKTOP_PACKAGES_MENUITEMS[@]}")
#     for CHOICE in "${CHOICES[@]}"
#     do
#         DESKTOP_PACKAGES+=("$CHOICE")
#     done
}

desktop_install() {
    XORG_PACKAGES=('xorg' 'xf86-video-nouveau')
    DESKTOP_PACKAGES_BASIC=('sddm' 'plasma' 'konsole' 'kwrite' 'okular' 'dolphin' 'fuse2' 'xclip' 'ttf-dejavu' 'pipewire-jack' 'pipewire-media-session' )
#    SOUND_PACKAGES=('pulseaudio' 'pulseaudio-jack' 'pulseaudio-alsa' 'phonon-qt-5-vlc'  'kmix')
    choose_desktop_packages
    arch-chroot /mnt pacman -S "${XORG_PACKAGES[@]}"
    sleep 10
    arch-chroot /mnt pacman -S "${DESKTOP_PACKAGES_BASIC[@]}"
#     arch-chroot /mnt pacman -S "${SOUND_PACKAGES[@]}" # --noconfirm
    sleep 10
    arch-chroot /mnt pacman -S "${DESKTOP_PACKAGES_OPTIONAL[@]}"
    sleep 15
    arch-chroot /mnt systemctl enable sddm
    sleep 10
}

arch-chroot /mnt pacman -Syy


TITLE="PACKAGES"
SYSTEM_TYPES=( 'DESKTOP' 'choose packages for KDE Plasma desktop environment' 'HEADLESS SERVER' 'enable sshd' )
SYSTEM_TYPE=$(dialog_menu "$TITLE" "Please choose Type of System to install:" "${SYSTEM_TYPES[@]}")

case "$SYSTEM_TYPE"
in
    "DESKTOP")
        desktop_install;;
    "HEADLESS SERVER")
        server_install;;
esac


###########################################################
# SUDO
###########################################################
arch-chroot /mnt groupadd sudo
echo "# sudo config enabled by ty-archinstall" > "/mnt/etc/sudoers.d/10-$USER_NAME"
echo "%sudo   ALL=(ALL:ALL) ALL" >> "/mnt/etc/sudoers.d/10-$USER_NAME"
# TODO: enable this, to see how/if it really works
# echo "$USER_NAME $HOST_NAME= NOPASSWD: /usr/bin/halt,/usr/bin/poweroff,/usr/bin/reboot,/usr/bin/pacman -Syu" >> "/mnt/etc/sudoers.d/10-$USER_NAME"
# ^ seems to be a relict from debian?
# sudo password valid for all open terminals -> dangerous, gives sudo access to al processes, don't use on server
# echo "Defaults timestamp_type=global" >> "/mnt/etc/sudoers.d/10-$USER_NAME"
# set sudo timeout to 10 minutes
echo "Defaults timestamp_timeout=10" >> "/mnt/etc/sudoers.d/10-$USER_NAME"
# issue bell if terminal out of focus needs attention for sudo password prompt
echo 'Defaults passprompt="^G[sudo] password for %p: "' >> "/mnt/etc/sudoers.d/10-$USER_NAME"
echo "Defaults insults" >> "/mnt/etc/sudoers.d/10-$USER_NAME"


# TODO: add alias to bashrc/fishrc to have the sudo timeout be reset with each usage of sudo alias sudo='sudo -v; sudo '
###########################################################
# ADD USER
###########################################################


# useradd
arch-chroot /mnt useradd -m -G sudo -c "$USER_NAME_FULL" -s /bin/$USER_SHELL $USER_NAME
sleep 15

# TODO

###########################################################
# PASSWORD
###########################################################
TITLE="PASSWORD"
get_password() {
    PASSWORD=$(dialog --clear --stdout --insecure --backtitle "$BACKTITLE" --title "$TITLE" --passwordbox "Please enter password for 'root' and '$USER_NAME'" $DIMENSIONS)
    PASSWORD_REPEAT=$(dialog --clear --stdout --insecure --backtitle "$BACKTITLE" --title "$TITLE" --passwordbox "Please repeat password:" $DIMENSIONS)
    if [[ "$PASSWORD" != "$PASSWORD_REPEAT" ]]
    then
        dialog_message "$TITLE" "Passwords don't match"
        get_password
    fi
}

get_password

(echo "$PASSWORD"; echo "$PASSWORD") | arch-chroot /mnt passwd

(echo "$PASSWORD"; echo "$PASSWORD") | arch-chroot /mnt passwd "$USER_NAME"

###########################################################
# GRUB
###########################################################
TITLE="GRUB"
bootloader_grub() {
    if dialog_yesno "$TITLE" "Want to install bootloader 'GRUB2'?" "SETUP GRUB" "CONTINUE WITHOUT BOOTLOADER"
    then
        arch-chroot /mnt pacman -S efibootmgr grub os-prober --noconfirm
        sed '/GRUB_DISABLE_OS_PROBER=false/s/^#//' -i /mnt/etc/default/grub
        arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=$EFI_PATH --bootloader-id=TYARCH
        arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
        sleep 10
    fi
}

bootloader_grub

###########################################################
# REBOOT
###########################################################

cp /tmp/ty/log /mnt/home/$USER_NAME/ty-archinstall.log

if dialog_yesno "REBOOT" "Install finished.\nReboot now or drop to live system shell?" "REBOOT" "LIVE-SYSTEM"
then
    reboot
fi





