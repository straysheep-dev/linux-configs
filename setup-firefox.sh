#!/bin/bash

function isRoot() {
        if [ "${EUID}" -ne 0 ]; then
                echo "You need to run this script as root"
                exit 1
        fi
}

isRoot

function checkVersion() {
	# Check Firefox version
	# Temporary solution until more OS's can be tested
	if [[ -d '/usr/lib/firefox' ]]; then
		FF_DIR=/usr/lib/firefox
	elif [[ -d '/usr/lib/firefox-esr' ]]; then
		FF_DIR=/usr/lib/firefox-esr
	elif [[ -d '/usr/lib64/firefox' ]]; then
		FF_DIR=/usr/lib64/firefox
	fi
}

checkVersion

function setupFirefox() {
	# Write firefox.cfg
	echo '// IMPORTANT: Start your code on the second line - this file must be in the top level of the Firefox directory
lockPref("xpinstall.whitelist.required", true);' >"${FF_DIR}/firefox.cfg"

	# Write autoconfig.js
	echo 'pref("general.config.filename", "firefox.cfg");
pref("general.config.obscure_value", 0);' >"${FF_DIR}/defaults/pref/autoconfig.js"

	# Write policies.json
        echo '{
  "policies": {
    "BlockAboutAddons": false,
    "BlockAboutConfig": false,
    "BlockAboutProfiles": false,
    "BlockAboutSupport": false,
    "DisableDeveloperTools": true,
    "DisableFeedbackCommands": false,
    "DisableFirefoxAccounts": true,
    "DisableFirefoxScreenshots": true,
    "DisableFirefoxStudies": true,
    "DisableFormHistory": true,
    "DisablePocket": true,
    "DisableProfileImport": true,
    "DisableSafeMode": true,
    "DisableSetDesktopBackground": true,
    "DisableTelemetry": true,
    "DisplayBookmarksToolbar": true,
    "DontCheckDefaultBrowser": true,
    "DownloadDirectory": "${home}/Downloads",
    "HardwareAcceleration": false,
    "NetworkPrediction": false,
    "NewTabPage": true,
    "NoDefaultBookmarks": true,
    "OfferToSaveLogins": false,
    "OverrideFirstRunPage": "",
    "OverridePostUpdatePage": "",
    "PromptForDownloadLocation": true,
    "SanitizeOnShutdown": true,
    "SearchBar": "separate",
    "SearchSuggestEnabled": false,
    "SSLVersionMax": "tls1.3",
    "SSLVersionMin": "tls1.2",
    "Homepage": {
      "Locked": true,
      "StartPage": "none"
    },
    "DNSOverHTTPS": {
      "Enabled": false
    },
    "Cookies": {
      "Default": true,
      "AcceptThirdParty": "never",
      "ExpireAtSessionEnd": true,
      "RejectTracker": true,
      "Locked": true
    },
    "EnableTrackingProtection": {
      "Value": true,
      "Locked": true,
      "Cryptomining": true,
      "Fingerprinting": true,
      "Exceptions": []
    },
    "FirefoxHome": {
      "Search": false,
      "TopSites": false,
      "Highlights": false,
      "Pocket": false,
      "Snippets": false,
      "Locked": true
    },
    "PDFjs": {
      "Enabled": false,
      "EnablePermissions": false
    },
    "FlashPlugin": {
      "Allow": [],
      "Block": ["*"],
      "Default": false,
      "Locked": true
    },
    "PopupBlocking": {
      "Allow":[],
      "Default": true,
      "Locked": true
    },
    "Permissions": {
      "Camera": {
        "Allow": [],
        "Block": ["*"],
        "BlockNewRequests": true,
        "Locked": true
      },
      "Microphone": {
        "Allow": [],
        "Block": ["*"],
        "BlockNewRequests": true,
        "Locked": true
      },
      "Location": {
        "Allow": [],
        "Block": ["*"],
        "BlockNewRequests": true,
        "Locked": true
      },
      "Notifications": {
        "Allow": [],
        "Block": ["*"],
        "BlockNewRequests": true,
        "Locked": true
      },
      "Autoplay": {
        "Allow": [],
        "Block": ["*"],
        "Default": "block-audio-video",
        "Locked": true
      }
    },
    "Handlers": {
      "mimeTypes": {
        "application/msword": {
          "action": "useSystemDefault",
          "ask": true
        }
      },
      "schemes": {
        "mailto": {
          "action": "useSystemDefault",
          "ask": true
        },
        "irc": {
          "action": "useSystemDefualt",
          "ask": true
        },
        "ircs": {
          "action": "useSystemDefualt",
          "ask": true 
        }
      },
      "extensions": {
        "pdf": {
          "action": "useHelperApp",
          "ask": true,
          "handlers": [{
            "name": "Evince",
            "path": "/usr/bin/evince" 
          }]
        },
        "xml": {
          "action": "useSystemDefault",
          "ask": true
        },
        "svg": {
          "action": "useSystemDefault",
          "ask": true
        },
        "webp": {
          "action": "useSystemDefault",
          "ask": true
        }
      }
    },
    "EncryptedMediaExtensions": {
      "Enabled": false,
      "Locked": true
    },
    "PictureInPicture": {
      "Enabled": false,
      "Locked": true
    },
    "ExtensionUpdate": false,
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
      "@testpilot-containers": {
        "installation_mode": "force_installed",
        "install_url": "https://addons.mozilla.org/firefox/downloads/latest/multi-account-containers/latest.xpi"
      }
    },
    "Preferences": {
      "browser.fixup.dns_first_for_single_words": {
        "Value": false,
        "Status": "locked"
      },
      "browser.safebrowsing.phishing.enabled": {
        "Value": true,
        "Status": "locked"
      },
      "browser.safebrowsing.malware.enabled": {
        "Value": true,
        "Status": "locked"
      },
      "browser.search.update": {
        "Value": false,
        "Status": "locked"
      },
      "browser.urlbar.suggest.bookmark": {
        "Value": false,
        "Status": "locked"
      },
      "browser.urlbar.suggest.history": {
        "Value": false,
        "Status": "locked"
      },
      "browser.urlbar.suggest.openpage": {
        "Value": false,
        "Status": "locked"
      },
      "browser.urlbar.suggest.topsites": {
        "Value": false,
        "Status": "locked"
      },
      "dom.allow_scripts_to_close_windows": {
        "Value": false,
        "Status": "locked"
      },
      "dom.disable_window_flip": {
        "Value": true,
        "Status": "locked"
      },
      "dom.disable_window_move_resize": {
        "Value": true,
        "Status": "locked"
      },
      "dom.disable_window_open_feature.status": {
        "Value": true,
        "Status": "locked"
      },
      "dom.event.contextmenu.enabled": {
        "Value": false,
        "Status": "locked"
      },
      "extensions.blocklist.enabled": {
        "Value": true,
        "Status": "locked"
      },
      "extensions.htmlaboutaddons.recommendations.enabled": {
        "Value": false,
        "Status": "locked"
      },
      "geo.enabled": {
        "Value": false,
        "Status": "locked"
      },
      "media.gmp-gmpopenh264.enabled": {
        "Value": false,
        "Status": "locked"
      },
      "media.gmp-widevinecdm.enabled": {
        "Value": false,
        "Status": "locked"
      },
      "media.peerconnection.enabled": {
        "Value": false,
        "Status": "locked"
      },
      "network.protocol-handler.external.shell": {
        "Value": false,
        "Status": "locked"
      },
      "places.history.enabled": {
        "Value": false,
        "Status": "locked"
      },
      "security.default_personal_cert": {
        "Value": "Ask Every Time",
        "Status": "locked"
      },
      "security.mixed_content.block_active_content": {
        "Value": true,
        "Status": "locked"
      },
      "security.tls.hello_downgrade_check": {
        "Value": true,
        "Status": "locked"
      },
      "signon.autofillForms": {
        "Value": false,
        "Status": "locked"
      }
    }
  }
}' >"${FF_DIR}/distribution/policies.json"

	# Kali specific
	if [ "${FF_DIR}" == /usr/lib/firefox-esr ] && (grep -q "^ID=kali$" /etc/os-release); then
		sed -i 's/"DisableDeveloperTools": true,$/"DisableDeveloperTools": false,/' "${FF_DIR}/distribution/policies.json"
	fi
}

setupFirefox
