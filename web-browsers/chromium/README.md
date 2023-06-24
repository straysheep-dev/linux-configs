# setup-chromium

Automatically generate a hardened policy file and the [correct](https://bugs.launchpad.net/ubuntu/+source/chromium-browser/+bug/1714244) [directories](https://forum.snapcraft.io/t/auto-connecting-the-system-files-interface-for-the-chromium-snap/20245) for the [Chromium Snap package](https://snapcraft.io/chromium), as well as the [directories](https://support.google.com/chrome/a/answer/9027408?hl=en) used by the [official deb/rpm packages](https://www.google.com/linuxrepositories/) of [Google Chrome](https://www.google.com/chrome/).

Tested on: 
* Ubuntu 20.04, 22.04
* Fedora 34, 35

Install Chromium:

```bash
sudo dnf install -y snapd
snap download chromium
sudo snap ack ./chromium_<version>.assert
sudo snap install ./chromium_<version>.snap

sudo mkdir -p /etc/chromium-browser/policies/managed
sudo mkdir -p /etc/chromium-browser/policies/recommended
```

Install Chrome:

```bash
echo "### THIS FILE IS AUTOMATICALLY CONFIGURED ###
# You may comment out this entry, but any other modifications may be lost.
deb [arch=$(dpkg --print-architecture)] https://dl.google.com/linux/chrome/deb/ stable main" | sudo tee /etc/apt/sources.list.d/google-chrome.list

wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | sudo apt-key add -
if ! (apt-key list | grep '4CCA 1EAF 950C EE4A B839  76DC A040 830F 7FAC 5991'); then echo "BAD SIGNATURE" && exit; else echo OK; fi
if ! (apt-key list | grep 'EB4C 1BFD 4F04 2F6D DDCC  EC91 7721 F63B D38B 4796'); then echo "BAD SIGNATURE" && exit; else echo OK; fi

sudo apt update && \
sudo apt install -y google-chrome-stable

# https://support.google.com/chrome/a/answer/9027408?hl=en
sudo mkdir -p /etc/opt/chrome/policies/managed
sudo mkdir -p /etc/opt/chrome/policies/recommended
```
[Key signatures](https://www.google.com/linuxrepositories/):
```
cat /etc/apt/trusted.gpg.d/google-chrome.gpg | gpg
gpg: WARNING: no command supplied.  Trying to guess what you mean ...

pub   dsa1024/0xA040830F7FAC5991 2007-03-08 [SC]
      Key fingerprint = 4CCA 1EAF 950C EE4A B839  76DC A040 830F 7FAC 5991
uid                             Google, Inc. Linux Package Signing Key <linux-packages-keymaster@google.com>
sub   elg2048/0x4F30B6B4C07CB649 2007-03-08 [E]
pub   rsa4096/0x7721F63BD38B4796 2016-04-12 [SC]
      Key fingerprint = EB4C 1BFD 4F04 2F6D DDCC  EC91 7721 F63B D38B 4796
uid                             Google Inc. (Linux Packages Signing Authority) <linux-packages-keymaster@google.com>
sub   rsa4096/0x1397BC53640DB551 2016-04-12 [S] [expired: 2019-04-12]
sub   rsa4096/0x6494C6D6997C215E 2017-01-24 [S] [expired: 2020-01-24]
sub   rsa4096/0x78BD65473CB3BD13 2019-07-22 [S] [expires: 2022-07-21]
sub   rsa4096/0x4EB27DB2A3B88B8B 2021-10-26 [S] [expires: 2024-10-25]
```

In either case, run the [setup-chromium](/web-browsers/chromium/setup-chromium.sh) shell script to install the policy file from this repo.

---

## Policy Overview:
* Based on the [OpenSCAP security guide for Google Chrome STIG configuration](https://static.open-scap.org/ssg-guides/ssg-chromium-guide-stig.html)
* DuckDuckGo default search engine
  - Examples for Google as default search engine provided below
* Clear all browser data on shutdown (auth / login, cookies, storage, history)
* Prevents account sign-in, and account sync
  - Local profiles can still be created and used
  - Incognito mode is disabled
  - Guest mode is disabled
* Block all third-party cookies
* Block filesystem api read/write
  - GUI downloads / uploads still work normally
* Block access to hardware
  - Bluetooth
  - WebGL API, Pepper 3D API (GPU)
  - USB devices
  - Camera and microphone are still permitted by user approval per site
* Site-per-process (site isolation)
* [JIT compiler disabled](#defaultjavascriptjitsetting)

---

Guest and Incognito modes are disabled by default in this policy. This prevents opening browser sessions without extensions that you may want to always be installed.

If you want to enabled these modes:

```
  # https://chromeenterprise.google/policies/?policy=BrowserGuestModeEnabled
  "BrowserGuestModeEnabled": false,    # change to true
  ...
  # https://chromeenterprise.google/policies/?policy=IncognitoModeAvailability
  "IncognitoModeAvailability": 1,      # change to 0
```

### Chrome Profiles

* https://support.google.com/chrome/a/answer/11198768?hl=en

> Creating different Chrome profiles lets users switch between their managed account and their other Google accounts, such as personal or test accounts, without signing out each time. No data or content is shared between profiles.

Chrome profiles work similar to [Firefox Containers](https://addons.mozilla.org/en-US/firefox/addon/multi-account-containers/).

However, tabs from different profiles cannot exist in the same Chrome window. A new, separate window is created for each Chrome profile you launch a session with.

Settings specific to installed extensions that you'd like to replicate in other profiles will need to be exported from a current profile, and imported into the other profile(s) extension(s). Each newly created profile launches with all of the policies (and extensions to be installed) applied, as if it was the first launch.

### Chrome User-Agent

<https://www.chromium.org/updates/ua-reduction/>

[chrome://version](chrome://version) will show the current `User-Agent` string.

You can set a User-Agent string by starting chromium from the CLI with `--user-agent=`:
```bash
chromium --user-agent='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/102.0.5005.115 Safari/537.36'
```

You can change the User-Agent dynamically (*without installing an extension*) while browsing using the developer tools. Thanks to Micah ([@WebBreacher](https://twitter.com/WebBreacher/status/1572595024046465024)) for sharing this. The linked twitter post shows screenshots of these steps:

1. Open the developer tools
2. Navigate to the Network tab
3. Choose `More network conditions...` (WiFi icon with a small gear on it)
4. On the new pane that appears, under `User agent` uncheck `Use browser default`
5. Opening the menu that says `Custom...` will allow you to set your user agent to any modern user agent

**NOTE**: This change only exists on the tab where you configured it, meaning to maintain the same user agent when opening links in new tabs you must open a blank tab, repeat these steps, and then copy & paste the link into the url bar of the newly configured tab.

Possible desktop platform values:
- Windows NT 10.0; Win64; x64
- Macintosh; Intel Mac OS X 10_15_7
- X11; Linux x86_64
- X11; CrOS x86_64 14541.0.0

Example Values:
- `Mozilla/5.0 (<platform>; <oscpu>) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/<majorVersion>.<minorVersion>; Safari/537.36`
- `Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/102.0.5005.115 Safari/537.36`
- `Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/102.0.5005.115 Safari/537.36`

Edge (Chromium)

[edge://version](edge://version) will show the current `User-Agent` string.

Captured from Wireshark:
- `Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/102.0.5005.63 Safari/537.36 Edg/102.0.1245.39`

## Thanks and References:

- OpenSCAP
	* https://github.com/OpenSCAP/openscap
- Chromium STIG Guide
	* https://static.open-scap.org/ssg-guides/ssg-chromium-guide-stig.html
- Web Browser STIG Guidance
	* https://public.cyber.mil/stigs/downloads/?_dl_facet_stigs=app-security%2Cbrowser-guidance
- Chrome Enterprise Policies
	* https://chromeenterprise.google/policies/
- Google Chrome (Security Updates, CVE list)
	* https://chromereleases.googleblog.com/
- Chromium Blog
	* https://blog.chromium.org/
- Chromium Policy Quick Start Guide
	* https://www.chromium.org/administrators/linux-quick-start/
- Historical list of updates with reference links
	* https://en.wikipedia.org/wiki/Google_Chrome_version_history
- Chromium snap package repo
	* https://launchpad.net/ubuntu/+source/chromium-browser
- Google Linux package repo information
	* https://www.google.com/linuxrepositories/

The policy file uses all of the [recommended](https://static.open-scap.org/ssg-guides/ssg-chromium-guide-stig.html) settings as a base

Differences have been noted below, and made either for compatability / usability reasons, or the policy has been deprecated / replaced

### Additional considerations not yet covered by this script:

* [DataLeakPreventionRulesList](https://chromeenterprise.google/policies/#DataLeakPreventionRulesList)
	- This policy allows granular control and reporting of things such as clipboard access, screenshots, printing, etc

### Policies that you should change to your requirements:

#### DefaultCookiesSetting | RestoreOnStartup | ClearBrowsingDataOnExitList

By default this policy clears all data when closing the browser. If you want your login sessions and previous tabs to restore, you'll need to change the following:

- `ClearBrowsingDataOnExitList` != `cookies_and_other_site_data` Removing this line will allow cookies to persist
- `DefaultCookiesSetting` = `1` Will allow all sites to set cookies, you'll need to delete cookies manually
- `RestoreOnStartup` = `1` Will restore the last session

#### CookiesAllowedForUrls | URLBlockList | URLAllowList

This is an example for Microsoft Teams. When blocking 3rd Party Cookies, SSO and similar technologies will need allow-listed like in this example. Listing URL's in this format will also apply to other allow / blocklist policies as well.
```
  "CookiesAllowedForUrls": [
    "https://[*.]microsoft.com",
    "https://[*.]microsoftonline.com",
    "https://[*.]teams.skype.com",
    "https://[*.]teams.microsoft.com",
    "https://[*.]sfbassets.com",
    "https://[*.]skypeforbusiness.com"
  ],
```

#### Extensions

Example configuration for extensions, using uBlock Origin.

- uBlock Origin is the only extension allowed
- All other extensions are blocked
- uBlock Origin is automatically installed

```
  "ExtensionInstallAllowlist": ["cjpalhdlnbpafiamejdnhcphjbkeiagm"],
  "ExtensionInstallBlocklist": ["*"],
  "ExtensionInstallForcelist": ["cjpalhdlnbpafiamejdnhcphjbkeiagm"],
```

#### DefaultJavaScriptJitSetting

https://chromeenterprise.google/policies/#DefaultJavaScriptJitSetting

- `1` = enabled
- `2` = disabled

Example configuration allowing a list of sites to run JavaScript JIT:

```
  "DefaultJavaScriptJitSetting": 2,

  "JavaScriptJitAllowedForSites":[
    "https://[*.]youtube.com",
  ],
```


#### DefaultSearchProviderSearchURL | DefaultSearchProviderNewTabURL | DefaultSearchProviderName

Change them to your preferred default search provider. Examples are given below for DuckDuckGo and Google.

```
  "DefaultSearchProviderSearchURL": "https://duckduckgo.com/?q={searchTerms}",
  "DefaultSearchProviderSearchURL": "https://www.google.com/search?q={searchTerms}",
```

#### Hardware / GPU Access

https://chromeenterprise.google/policies/#Disable3DAPIs

https://chromeenterprise.google/policies/#HardwareAccelerationModeEnabled

```
  "Disable3DAPIs": true,
  "HardwareAccelerationModeEnabled": false,
```

#### AuthSchemes

[Edge v98 security baseline](https://www.microsoft.com/en-us/download/details.aspx?id=55319) uses the following:

```
ntlm,negotiate
```

---

### Differences from [SSG-Chromium-Guide-STIG](https://static.open-scap.org/ssg-guides/ssg-chromium-guide-stig.html)

The following lists changes made to rules found in the Open-SCAP security guide from their recommended defaults:

```sh
# Block Plugins By Default (deprecated, https://chromeenterprise.google/policies/#DefaultPluginsSetting)
  "DefaultPluginsSetting": 3,

# Disable The AutoFill Feature (deprecated for AutofillAddressEnabled, AutofillCreditCardEnabled)
  "AutofillAddressEnabled": false,
  "AutofillCreditCardEnabled": false,

# Disable Automatic Search And Installation Of Plugins (deprecated, https://chromeenterprise.google/policies/#DisablePluginFinder)
  "DisablePluginFinder": true,

# Disable Use Of Cleartext Passwords (deprecated, not available on https://chromeenterprise.google/policies/)
  "PasswordManagerAllowShowPasswords": false,

# Disable Network Prediction (replaced with NetworkPredictionOptions)
  "DnsPrefetchingEnabled": false,

# Disable Outdated Pluings (deprecated, https://chromeenterprise.google/policies/#AllowOutdatedPlugins)
  "AllowOutdatedPlugins": false,

# Disable All Plugins By Default (deprecated, https://chromeenterprise.google/policies/#DisabledPlugins)
  "DisabledPlugins": "*",

# Disable Insecure And Obsolete Protocol Schemas (deprecated for URLBlocklist)
# Will be organization specific, https://www.chromium.org/administrators/url-blocklist-filter-format
# Note this only applies to schema, javascript within a page is unaffected by the given setting https://chromeenterprise.google/policies/?policy=URLBlocklist
# Examples: "file://*", "custom_scheme://*", "ftp://*"
  "URLBlocklist": ["javascript://*"],

# Disable Session Cookies (better to configure DefaultCookieBehavior = 4)
# Will need to configure CookiesAllowedForUrls, CookiesBlockedForUrls, RestoreOnStartup
  "CookiesSessionOnlyForUrls": ["none"],

# Enable Only Approved Plugings (deprecated, https://chromeenterprise.google/policies/#EnabledPlugins)
  "EnabledPlugins": ["example"],

# Enable The Safe Browsing Feature (deprecated for SafeBrowsingProtectionLevel)
  "SafeBrowsingProtectionLevel": 1,

# Set Chromium's HTTP Authentication Scheme
# Will be organization specific, https://chromeenterprise.google/policies/#AuthSchemes
  "AuthSchemes": basic,digest,ntlm,negotiate,

# Require Outdated Plugins To Be Authorized  (deprecated, not available on https://chromeenterprise.google/policies/)
  "AlwaysAuthorizePlugins": false

# Set The Default Home Page
# "about:blank" no longer works as a valid homepage, use default search provider URL instead.
# HomepageIsNewTabPage also works if it points to your set search engine.
  "HomepageLocation": "https://duckduckgo.com"

# Enable Saving The Browser History
# Browser history can be saved before exiting and clearing the session. Setting this to `true` will disable browser history completely.
  "SavingBrowserHistoryDisabled": false,

# Enable Plugins Only For Approved URLs (deprecated, not available on https://chromeenterprise.google/policies/)
  "PluginsAllowedForUrls": ["none"],
```
