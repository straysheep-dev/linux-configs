# apparmor

Various apparmor profiles


## Firefox

[MPL-2.0](https://git.launchpad.net/~mozillateam/firefox/tree/debian/copyright) + [GPL-2.0-or-later](https://gitlab.com/apparmor/apparmor/-/raw/master/LICENSE)

The apparmor profiles here are [my own fork](https://github.com/straysheep-dev/linux-configs/tree/main/apparmor) of the original file(s) that used to ship with Ubuntu before Firefox moved to snap being the default. These work with both, Firefox and Firefox-ESR, with local overrides to protect `$HOME` and other paths via [apparmor-usr.bin.firefox.local](./files/apparmor-usr.bin.firefox.local).

> [!NOTE]
> The `MPL-2.0` file and the original [`usr.bin.firefox.apparmor.14.10`](https://bazaar.launchpad.net/~mozillateam/firefox/firefox.focal/view/head:/debian/usr.bin.firefox.apparmor.14.10) profile are from the [Firefox source on launchpad](https://bazaar.launchpad.net/~mozillateam/firefox/firefox.focal/files/head:/debian). That repo also contains a [copyright](https://git.launchpad.net/~mozillateam/firefox/tree/debian/copyright) file which listed `usr.bin.firefox.apparmor.14.10` as falling under the MPL-2.0. An up-to-date copy of the `copyright` file is available in the root of this repo. The original MPL-2.0 and usr.bin.firefox.apparmor.14.10 files are no longer present in the latest versions of the code on launchpad.

- `apparmor-usr.bin.firefox` falls under the MPL-2.0 license
- `apparmor-firefox.abstractions` appears to be created by [`aa-update-browser`](https://git.launchpad.net/ubuntu/+source/apparmor/tree/debian/aa-update-browser) and falls under the GPL-2.0-or-later license
- `apparmor-usr.bin.firefox.local` is my local override file, and falls under the default MIT license of this repo


### Filenames and Locations

**Firefox**

- Main configuration file: `/etc/apparmor.d/usr.bin.firefox`
- Abstractions: `/etc/apparmor.d/abstractions/ubuntu-browsers.d/firefox`
- Local: `/etc/apparmor.d/local/usr.bin.firefox`

**Firefox-esr**

- Main configuration file: `/etc/apparmor.d/usr.bin.firefox-esr`
- Abstractions: `/etc/apparmor.d/abstractions/ubuntu-browsers.d/firefox-esr`
- Local: `/etc/apparmor.d/local/usr.bin.firefox-esr`
