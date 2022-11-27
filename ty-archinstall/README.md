# ty-archinstall
ncurses installer for Arch Linux implemented with dialog
## testing
### test new iso
```bash
update_ty-archiso.sh
```


## TODO's:
- [ ] repair loginshell variable at useradd
- [ ] get possible Keymap Items from list
        - ls /usr/share/kbd/keymaps/**/*.map.gz | xargs -n1 basename | sed .map.gz^C
- [ ] revisit keymap / /etc/vconsole.conf
- [ ] check if ~/.config/kxkbrc is rpesent directly after useradd
- [ ] ensure Tyrepo is enabled in pacman.conf
- [x] add support for different login shells
- [ ] ~~go directly to cfdisk if no partition table~~
    - if $(#_DEVICES) -eq 0 -> somehow doesn't do the trick
- [x] remove duplication of keyboard choice / start installer
    - [x] leave keyboard choice in .zlogin / remove from /usr/bin/ty-archinstall
    - [x] move package upgrade to /usr/bin/ty-archinstall
- [x] add check after enable NetworkManager
    - /etc/systemd/system/multi-user.target.wants/NetworkManager.service
    - /etc/systemd/system/dbus-org.freedesktop.nm-dispatcher.service
    - /etc/systemd/system/network-online.target.wants/NetworkManager-wait-online.service
- [x] assign fallback locale String to LANGUAGE, assign LANG back to normal System Locale
        LANGUAGE=
        LC_COLLATE=C
- [x] check for presence of /tmp/ty/keymap and put into vconsole
