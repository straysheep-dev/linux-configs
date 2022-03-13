# linux-configs
Various configuration files for unix/linux operating systems

### Licenses
Unless a different license is included with a file as `<filename>.copyright-notice` all files are released under the GPL-3.0

## To do:
- [x] create table of contents
- [x] add apparmor profiles
- [ ] write overview/summary of the firefox policies
- [ ] add other configurations for ufw
- [ ] add other configurations for iptables
- [ ] add bind9 dns setup and implementation

## Contents
- [AppArmor Profiles](apparmor/)
    * [Firefox](apparmor/#firefox)
- [Auditd Policies](auditd/)
    * [MITRE Rules](auditd/40-mitre.rules)
- [Web Browsers](web-browsers/)
    - [Chromium Configuration](web-browsers/chromium/)
        * [Policy Overview](web-browsers/chromium#policy-overview)
        * [Thanks and References](web-browsers/chromium#thanks-and-references)
        * [Differences from SSG Chromium Guide STIG](web-browsers/chromium#differences-from-ssg-chromium-guide-stig)
    - [Firefox Configuration](web-browsers/firefox/)
        * [Policy Overview](web-browsers/firefox#policy-overview)
        * [Thanks and References](web-browsers/firefox#thanks-and-references)
        * [Differences from SSG Firefox Guide STIG](web-browsers/firefox#differences-from-ssg-firefox-guide-stig)
- [Firewall Scripts](firewall/#firewall-scripts)
    * [Why?](firewall/#why)
    * [Example Usage](firewall/#example-usage)
    * iptables
    * ip6tables
    * ufw
- [Gnome](gnome/)
    * [dconf](gnome/dconf.sh)
    * [gsettings](gnome/gsettings.sh)
- [GnuPG](gnupg/#gnupg)
    * [The Configuration Files](gnupg/#the-configuration-files)
    * [yubi-mode.sh](gnupg/#yubi-modesh)
    * [Commands](gnupg#commands)
    * [Sources](gnupg/#sources)
- [Kali Linux](kali/)
    * [Tools](kali/kali-tools.sh)
    * [System Settings](kali/kali-config.sh)
- [Package Maintenance Scripting](package-maintenance.sh)
- [System Summary and Visibility Scripting](system-summary.sh)
- [unbound](dns/#unbound)
    * [Overview](dns/#overview)
    * [Why?](dns/#why)
    * [Blocking Domains In unbound.conf](dns/#blocking-domains-in-unboundconf)
    * [Hosts Files](dns/#hosts-files)
    * [Dns Blocklist Resources](dns/#dns-blocklist-resources)
    * [Parsing Hosts Files to a File Formatted for unbound](dns/#parsing-hosts-files-to-a-file-formatted-for-unbound)
    * [Dns Response Codes](dns/#dns-response-codes)
    * [References](dns/#references)
