
# setup-firefox

Apply a hardened policy for Firefox / Firefox-ESR.

Tested on:

* Ubuntu 18.04 -> 22.04
* Kali 2020.1 -> 2024.1
* Fedora 34

```
# Directories:
/etc/firefox[-esr]    # default / any
or
/usr/lib/firefox/     # default / ubuntu
/usr/lib64/firefox/   # default / fedora
/usr/lib/firefox-esr/ # esr / kali

# File locations:
/etc/firefox/syspref.js
/etc/firefox/policies/policies.json
or
/usr/lib/firefox/firefox.cfg
/usr/lib/firefox/defaults/pref/autoconfig.js
/usr/lib/firefox/distribution/policies.json
```

## Install a policy file on Kali:

- Use `/etc/firefox` instead of `/etc/firefox-esr`
- You only need the policy file, no other configuration files are necessary

```bash
sudo rm -rf /etc/firefox-esr/*
sudo mkdir -p /etc/firefox/policies
sudo cp ./firefox-policies-kali.json /etc/firefox/policies/policies.json
```

## Snap Package

Previously the [Firefox Snap package](https://snapcraft.io/firefox) required a `user.js` file to be configured. This was before it could read the policy file at `/etc/firefox/policies/*.json` (there's now an automatic snap connection to provide it read access to this location, however it still cannot read any syspref.js or other .js files in the /etc/firefox* directories).

If you still need/want to create a user.js file, create it within your `~/snap/firefox/common/.mozilla/firefox/<string>.default-release` folder, then to lock the policy file:
```bash
sudo chattr +i user.js
```
To test that it's locked and cannot be modified:
```bash
snap run --shell firefox; rm user.js
rm: cannot remove 'user.js': Operation not permitted
```

## Policy Overview:

The main policy file is based on the STIG profile for firefox.

The `firefox-policies-kali.json` is meant to be used for web applicaton testing. It has similar defaults, but a few key differences and everything is unlocked:

- All locked policies are unlocked, but most are still set to a specific default
- Wappalyzer extension
- Checks `/home/kali/` for both the burpsuite and OWASP ZAP CA certificates, installs them

### Differences from [SSG-Firefox-Guide-STIG](https://static.open-scap.org/ssg-guides/ssg-firefox-guide-stig.html)

The main change in Firefox 81/78.3-ESR policy configuration has been moving all of the "*.cfg" settings into the "Preferences" policy contained within the larger "policies.json". Many of the edits you can make to about:config are able to be entered there now. 

Review which prefixes are available here: https://github.com/mozilla/policy-templates#preferences

```bash
# Disable Automatic Downloads of MIME Types (replaced with "Handlers" since v78/v78-ESR, https://github.com/mozilla/policy-templates#handlers)
lockPref("browser.helperApps.alwaysAsk.force", true);

# Disable Autofill Form Assistance (enabled and locked by "DisableFormHistory" since v60/v60-ESR, https://github.com/mozilla/policy-templates#disableformhistory)
lockPref("browser.formfill.enable", false);

# Disable Background Information Submission (enabled and locked by "DisableTelemetry" since v60/v60-ESR, https://github.com/mozilla/policy-templates#disabletelemetry)
lockPref("datareporting.policy.dataSubmissionEnabled", false);

# Disable Firefox Development Tools
NOTE: development tools are enabled for Kali

# Disable Extension Installation (managed and locked by "ExtensionSettings" since v69/v68.1-ESR to allow approved extensions and block all others, https://github.com/mozilla/policy-templates#extensionsettings)
lockPref("xpinstall.enabled", false);

# Enable Downloading and Opening File Confirmation (managed by "PromptForDownloadLocation", https://github.com/mozilla/policy-templates#promptfordownloadlocation
lockPref("plugin.disable_full_page_plugin_for_types", <list>);

# Disable the Firefox Password Store (managed by "PasswordManagerEnabled", https://github.com/mozilla/policy-templates#passwordmanagerenabled
lockPref("signon.rememberSignons", false);

# Enable Firefox Pop-up Blocker (enabled and locked by "PopupBlocking" since v60/v60-ESR, https://github.com/mozilla/policy-templates#popupblocking
lockPref("dom.disable_window_open_feature.status", true);
```

## Security Notes

Both Chrome and Firefox will prompt the user before a website is able to read the user's clipboard data.

Firefox will also block attempts by a website to automatically set data into the clipboard without user interaction, and notify the user this occurred.


## Useful Extensions

These lines can be added to the policies.json file to automatically install the extension(s) listed.

- [uBlock Origin](https://github.com/gorhill/uBlock)
- [DuckDuckGo](https://github.com/duckduckgo/duckduckgo-privacy-extension)
- [Firefox Containers](https://github.com/mozilla/multi-account-containers/#readme)

```json
    "ExtensionSettings": {
      "*": {
        "blocked_install_message": "Extension blocked by policy",
        "install_sources": ["https://addons.mozilla.org/"],
        "installation_mode": "blocked",
        "allowed_types": ["extension"]
      },
      "uBlock0@raymondhill.net": {
        "installation_mode": "force_installed",
        "install_url": "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi"
      },
      "jid1-ZAdIEUB7XOzOJw@jetpack": {
        "installation_mode": "force_installed",
        "install_url": "https://addons.mozilla.org/firefox/downloads/latest/duckduckgo-for-firefox/latest.xpi"
      },
      "@testpilot-containers": {
        "installation_mode": "force_installed",
        "install_url": "https://addons.mozilla.org/firefox/downloads/latest/multi-account-containers/latest.xpi"
      }
    },
```

## Thanks and References:

* https://github.com/OpenSCAP/openscap
* https://github.com/ComplianceAsCode/content
* https://static.open-scap.org/ssg-guides/ssg-firefox-guide-stig.html
* https://github.com/mozilla/policy-templates
* https://www.blackhillsinfosec.com/towards-quieter-firefox/
* https://github.com/IppSec/parrot-build/blob/master/roles/customize-browser/templates/policies.json.j2
