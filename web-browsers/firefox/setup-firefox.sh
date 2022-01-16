#!/bin/bash

BLUE="\033[01;34m"   # information
GREEN="\033[01;32m"  # information
YELLOW="\033[01;33m" # warnings
RED="\033[01;31m"    # errors
BOLD="\033[01;01m"   # highlight
RESET="\033[00m"     # reset

function isRoot() {
        if [ "${EUID}" -ne 0 ]; then
                echo "You need to run this script as root"
                exit 1
        fi
}
isRoot

function MakeTemp() {

    # Make a temporary working directory
#    if [ -d /tmp/firefox/ ]; then
#        rm -rf /tmp/firefox
#    fi

    if ! [ -d /tmp/firefox ]; then
        mkdir /tmp/firefox
    fi

    SETUPDIR=/tmp/firefox
    export SETUPDIR

    cd "$SETUPDIR" || (echo "Failed changing into setup directory. Quitting." && exit 1)
    echo -e "${BLUE}[i]Changing working directory to $SETUPDIR${RESET}"

}

function libPath() {
	# Check Firefox version for /usr/lib directory path
	# Temporary solution until more OS's can be tested
	if [[ -d '/usr/lib/firefox' ]]; then
		FF_DIR=/usr/lib/firefox
	elif [[ -d '/usr/lib/firefox-esr' ]]; then
		FF_DIR=/usr/lib/firefox-esr
	elif [[ -d '/usr/lib64/firefox' ]]; then
		FF_DIR=/usr/lib64/firefox
	fi
}

function etcPath() {
	# Check Firefox version for /etc/ directory path
	# Check for esr first
	if [[ -d '/etc/firefox-esr' ]]; then
		FF_DIR=/etc/firefox-esr
	elif [[ -d '/etc/firefox' ]]; then
		FF_DIR=/etc/firefox
	fi
}

function removeConfigs() {
	# Check for pre-installed policies and preferences in /etc, and remove them before writing our own
	if [ -e /etc/firefox ]; then
		find /etc/firefox -type f -print0 | xargs -0 rm 2>/dev/null 
	fi
	if [ -e /etc/firefox-esr ]; then
		find /etc/firefox-esr -type f -print0 | xargs -0 rm 2>/dev/null 
	fi
	# Call libPath to detect these files if they exist, and remove them to avoid conflicts if changing path to /etc
	libPath
	if [ -e "$FF_DIR"/firefox.cfg ]; then
		rm "$FF_DIR"/firefox.cfg
	fi
	if [ -e "$FF_DIR"/defaults/pref/autoconfig.js ]; then
		rm "$FF_DIR"/defaults/pref/autoconfig.js
	fi
	if [ -e "$FF_DIR"/distribution/policies.json ]; then
		rm "$FF_DIR"/distribution/policies.json
	fi
}

function writeSysprefs() {
	# Examples:
	# /etc/firefox/policies/*.json
	# /etc/firefox/syspref.js
	# /etc/firefox/prefs/local.js
	echo '// This file can be used to configure global preferences for Firefox
pref("general.config.obscure_value",0,locked);
pref("xpinstall.whitelist.required",true,locked);' > "$SETUPDIR"/syspref.js
}

function writeCfg() {
	# Write firefox.cfg
	echo '// IMPORTANT: Start your code on the second line - this file must be in the top level of the Firefox directory
lockPref("xpinstall.whitelist.required", true);' > "$SETUPDIR"/firefox.cfg
}

function writeAutoconfig() {
	# Write autoconfig.js
	echo 'pref("general.config.filename", "firefox.cfg");
pref("general.config.obscure_value", 0);' > "$SETUPDIR"/autoconfig.js
}

function writePolicies() {
	# Write policies.json
        echo '{
  "policies": {
    "BlockAboutAddons": false,
    "BlockAboutConfig": false,
    "BlockAboutProfiles": false,
    "BlockAboutSupport": false,
    "DisableDeveloperTools": false,
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
      "Block": [],
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
        "Block": [],
        "BlockNewRequests": true,
        "Locked": true
      },
      "Microphone": {
        "Allow": [],
        "Block": [],
        "BlockNewRequests": true,
        "Locked": true
      },
      "Location": {
        "Allow": [],
        "Block": [],
        "BlockNewRequests": true,
        "Locked": true
      },
      "Notifications": {
        "Allow": [],
        "Block": [],
        "BlockNewRequests": true,
        "Locked": true
      },
      "Autoplay": {
        "Allow": [],
        "Block": [],
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
          "action": "useSystemDefault",
          "ask": true
        },
        "ircs": {
          "action": "useSystemDefault",
          "ask": true
        }
      },
      "extensions": {
        "avif": {
          "action": "useSystemDefault",
          "ask": true
        },
        "pdf": {
          "action": "useHelperApp",
          "ask": true,
          "handlers": [{
            "name": "Evince",
            "path": "/usr/bin/evince"
          }]
        },
        "svg": {
          "action": "useSystemDefault",
          "ask": true
        },
        "webp": {
          "action": "useSystemDefault",
          "ask": true
        },
        "xml": {
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
      "dom.security.https_only_mode": {
        "Value": true,
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
}' > "$SETUPDIR"/policies.json
}

# Prompt
echo -e "${BOLD}Which path will be used for the configuration files?${RESET}"
echo ""
echo -e "${BLUE}[/etc]${RESET}      ${BOLD}system-wide, both package manager and snap packages can read these (snap package cannot read the .js files)${RESET}"
echo "    /etc/firefox/syspref.js"
echo "    /etc/firefox/policies/"
echo "    /etc/firefox/policies/policies.json"
echo "    /etc/firefox/pref/"
echo "    /etc/firefox/pref/local.js"
echo "    /etc/firefox/profile"
echo ""
echo -e "${BLUE}[/usr/lib]${RESET}  ${BOLD}system-wide, but only for the package installed by the package manager (snap package cannot read these)${RESET}"
echo "    /usr/lib/firefox/firefox.cfg"
echo "    /usr/lib/firefox/distribution/policies.json"
echo "    /usr/lib/firefox/defaults/pref/autoconfig.js"
echo ""
until [[ $CONFIG_DIR =~ ^(etc|lib)$ ]]; do
	read -rp "Configuration directory [etc|lib]: " CONFIG_DIR
done
if [[ $CONFIG_DIR == "etc" ]]; then
	removeConfigs
	etcPath
	echo -e "${BLUE}[i]Using $FF_DIR as configuration path...${RESET}"
	writeSysprefs
	writePolicies
	# This is always the policies.json path for firefox or firefox-esr
	mkdir -p /etc/firefox/policies
	# Firefox-esr still uses /etc/firefox-esr for syspref.js
	cp "$SETUPDIR"/syspref.js "$FF_DIR"
	cp "$SETUPDIR"/policies.json /etc/firefox/policies
elif [[ $CONFIG_DIR == "lib" ]]; then
	removeConfigs
	libPath
	echo -e "${BLUE}[i]Using $FF_DIR as configuration path...${RESET}"
	writeCfg
	writeAutoconfig
	writePolicies
	cp "$SETUPDIR"/firefox.cfg "$FF_DIR"
	cp "$SETUPDIR"/autoconfig.js "$FF_DIR"/defaults/pref
	cp "$SETUPDIR"/policies.json "$FF_DIR"/distribution
fi

# Kali specific
#if (grep -q "^ID=kali$" /etc/os-release); then
#	# add extension 1
#	# add extension 2
#	# etc...
#fi

echo -e "${BLUE}[i]Done.${RESET}"

exit 0
