
# setup-firefox
Automatically generate a hardened policy for Firefox / Firefox-ESR.

Tested on:

* Ubuntu 18.04 => 20.04
* Kali 2020.1 => 2021.2
* Fedora 34

```
# Directories:
/usr/lib/firefox/     # default / ubuntu
/usr/lib64/firefox/   # default / fedora
/usr/lib/firefox-esr/ # esr / kali

# File locations:
/usr/lib/firefox/firefox.cfg
/usr/lib/firefox/defaults/pref/autoconfig.js
/usr/lib/firefox/distribution/policies.json
```

NOTE: If you're using the [Firefox Snap package](https://snapcraft.io/firefox) you'll need to create a `user.js` file instead until the snap package can read the default policy file locations in the filesystem (outside of it's security sandbox).

Once it's created and added to your `~/snap/firefox/` folder, to lock the policy file:
```bash
sudo chattr +i user.js
```
To test that it's locked and cannot be modified:
```bash
snap run --shell firefox; rm user.js
rm: cannot remove 'user.js': Operation not permitted
```

## Policy Overview:

`To do`

## Thanks and References:
* https://github.com/OpenSCAP/openscap
* https://static.open-scap.org/ssg-guides/ssg-firefox-guide-stig.html
* https://public.cyber.mil/stigs/downloads/?_dl_facet_stigs=app-security%2Cbrowser-guidance
* https://github.com/mozilla/policy-templates

## Differences from [SSG-Firefox-Guide-STIG](https://static.open-scap.org/ssg-guides/ssg-firefox-guide-stig.html)

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
