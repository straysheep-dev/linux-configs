#!/bin/bash

# Set "EnableMediaRouter": false, then add the following to stop mdns listener:
# chrome://flags => enable-webrtc-hide-local-ips-with-mdns => false

function isRoot() {
        if [ "${EUID}" -ne 0 ]; then
                echo "You need to run this script as root"
                exit 1
        fi
}

isRoot

function setupChromium() {
        mkdir -p /etc/chromium-browser/policies/managed
        mkdir -p /etc/chromium-browser/policies/recommended

        echo '{
  "AdsSettingForIntrusiveAdsSites": 2,
  "AlwaysOpenPdfExternally": true,
  "AudioSandboxEnabled": true,
  "AutofillAddressEnabled": false,
  "AutofillCreditCardEnabled": false,
  "AutoplayAllowed": false,
  "BackgroundModeEnabled": false,
  "BlockThirdPartyCookies": true,
  "BrowserSignin": 0,
  "ClearBrowsingDataOnExitList": [
    "browsing_history",
    "download_history",
    "cookies_and_other_site_data",
    "cached_images_and_files",
    "password_signin",
    "autofill",
    "site_settings",
    "hosted_app_data"
  ],
  "CookiesAllowedForUrls": [
    "https://[*.]microsoft.com",
    "https://[*.]microsoftonline.com",
    "https://[*.]teams.skype.com",
    "https://[*.]teams.microsoft.com",
    "https://[*.]sfbassets.com",
    "https://[*.]skypeforbusiness.com"
  ],
  "CloudPrintProxyEnabled": false,
  "DefaultBrowserSettingEnabled": false,
  "DefaultCookiesSetting": 4,
  "DefaultFileSystemReadGuardSetting": 2,
  "DefaultFileSystemWriteGuardSetting": 2,
  "DefaultGeolocationSetting": 2,
  "DefaultInsecureContentSetting": 2,
  "DefaultNotificationsSetting": 2,
  "DefaultPopupsSetting": 2,
  "DefaultSearchProviderContextMenuAccessAllowed": false,
  "DefaultSearchProviderEnabled": true,
  "DefaultSearchProviderName": "DuckDuckGo",
  "DefaultSearchProviderNewTabURL": "https://duckduckgo.com/",
  "DefaultSearchProviderSearchURL": "https://duckduckgo.com/?q={searchTerms}",
  "DefaultSensorsSetting": 2,
  "DefaultWebBluetoothGuardSetting": 2,
  "DeveloperToolsAvailability": 0,
  "Disable3DAPIs": true,
  "DnsOverHttpsMode" : "off",
  "DownloadDirectory": "/home/${user_name}/Downloads",
  "EnableMediaRouter": false,
  "EnableOnlineRevocationChecks": true,
  "ExtensionInstallAllowlist": ["cjpalhdlnbpafiamejdnhcphjbkeiagm"],
  "ExtensionInstallBlocklist": ["*"],
  "ExtensionInstallForcelist": ["cjpalhdlnbpafiamejdnhcphjbkeiagm"],
  "HomepageLocation": "https://duckduckgo.com/",
  "ImportSavedPasswords": false,
  "IncognitoModeAvailability": 1,
  "MetricsReportingEnabled": false,
  "NetworkPredictionOptions": 2,
  "PasswordManagerEnabled": false,
  "RemoteAccessHostFirewallTraversal": false,
  "RestoreOnStartup": 5,
  "SafeBrowsingProtectionLevel": 1,
  "SavingBrowserHistoryDisabled": false,
  "SearchSuggestEnabled": false,
  "ShowFullUrlsInAddressBar": true,
  "SitePerProcess": true,
  "SpellcheckEnabled": false,
  "SSLVersionMin": "tls1.2",
  "SyncDisabled": true,
  "URLBlocklist": ["javascript://*"]
}' >/etc/chromium-browser/policies/managed/policies.json
}

setupChromium
