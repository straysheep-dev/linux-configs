# setup-chromium.sh

Automatically generate a hardened policy file and the [correct](https://bugs.launchpad.net/ubuntu/+source/chromium-browser/+bug/1714244) [directories](https://forum.snapcraft.io/t/auto-connecting-the-system-files-interface-for-the-chromium-snap/20245) for the [Chromium Snap package](https://snapcraft.io/chromium) to use.

Tested on: 
* Ubuntu 20.04 
* Fedora 34

```bash
sudo dnf install -y snapd
chmod +x setup-chromium.sh
sudo ./setup-chromium.sh
snap download chromium
sudo snap ack ./chromium_<version>.assert
sudo snap install ./chromium_<version>.snap
```

## Policy Overview:
* Based on the [OpenSCAP security guide for Google Chrome STIG configuration](https://static.open-scap.org/ssg-guides/ssg-chromium-guide-stig.html)
* DuckDuckGo default search engine
  - Examples for Google as default search engine provided below
* Clear all browser data on shutdown (auth / login cookies and tokens / history)
* Prevents account sign-in, and account sync
  - Local profiles can still be created and used
  - Incognito mode is disabled
* Block all third-party cookies
* Block filesystem api read/write
  - GUI downloads / uploads still work normally
* Block access to hardware
  - Bluetooth
  - GPU
  - Usb devices 
  - Camera and microphone are still permitted by user approval per site
* Site-per-process (site isolation)
* Allows all cookies for required or trusted sites 
  - ie; Microsoft Teams requires this, as will other single-sign-on services, examples provided below
* uBlock Origin installed and locked as only permitted extension

If you prefer to avoid installing any extensions, remove both `ExtensionInstallAllowlist` and `ExtensionInstallForcelist` lines from this policy.

## Thanks and References:

* https://github.com/OpenSCAP/openscap
* https://static.open-scap.org/ssg-guides/ssg-chromium-guide-stig.html
* https://public.cyber.mil/stigs/downloads/?_dl_facet_stigs=app-security%2Cbrowser-guidance
* https://chromeenterprise.google/policies/

The setup script uses all of the [recommended](https://static.open-scap.org/ssg-guides/ssg-chromium-guide-stig.html) settings as a base

Differences have been noted below, and made either for compatability / usability reasons, or the policy has been deprecated / replaced

### Additional considerations not yet covered by this script:

* [DataLeakPreventionRulesList](https://chromeenterprise.google/policies/#DataLeakPreventionRulesList)
  - This policy allows granular control and reporting of things such as clipboard access, screenshots, printing, etc

### Policies that you should change to your requirements:

* CookiesAllowedForUrls | URLBlockList | URLAllowList

The default list included in this script shows an example for Microsoft Teams (example just below). When blocking 3rd Party Cookies, SSO and similar technologies will need allow-listed like in this example. Listing URL's in this format will also apply to other allow / blocklist policies as well.
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

* DefaultSearchProviderSearchURL | DefaultSearchProviderNewTabURL | DefaultSearchProviderName

Change them to your preferred default search provider. Examples are given below for DuckDuckGo and Google.

```
  "DefaultSearchProviderSearchURL": "https://duckduckgo.com/?q={searchTerms}",
  "DefaultSearchProviderSearchURL": "https://www.google.com/search?q={searchTerms}",
```

* AuthSchemes

[Edge v95 security baseline](https://www.microsoft.com/en-us/download/details.aspx?id=55319) uses the following:

```
ntlm,negotiate
```

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
