# apparmor

Various apparmor profiles

## Firefox

The `copyright` and `MPL-2.0` source files can be found here:

https://bazaar.launchpad.net/~mozillateam/firefox/firefox.focal/files/head:/debian

The `apparmor-usr.bin.firefox` source file can be found here:

https://bazaar.launchpad.net/~mozillateam/firefox/firefox.focal/view/head:/debian/usr.bin.firefox.apparmor.14.10

The `apparmor-firefox.abstractions` file is updated by `aa-update-browser` under the GPLv2:

https://git.launchpad.net/ubuntu/+source/apparmor/tree/debian/aa-update-browser

https://gitlab.com/apparmor/apparmor/-/raw/master/LICENSE

### Filenames and Locations
```
# Firefox
Main configuration file:
/etc/apparmor.d/usr.bin.firefox

Abstractions:
/etc/apparmor.d/abstractions/ubuntu-browsers.d/firefox

Local:
/etc/apparmor.d/local/usr.bin.firefox
```
```
# Firefox-esr
Main configuration file:
/etc/apparmor.d/usr.bin.firefox-esr

Abstractions:
/etc/apparmor.d/abstractions/ubuntu-browsers.d/firefox-esr

Local:
/etc/apparmor.d/local/usr.bin.firefox-esr
```
