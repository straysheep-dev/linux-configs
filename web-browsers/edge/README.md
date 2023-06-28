# setup-edge

Generate a hardened policy file, and install Microsoft Edge for Linux.

Tested on:
* Ubuntu 20.04

The following policies will show an `Error` under `Status` but are working and reflected in the settings:

- BackgroundModeEnabled
- DefaultBrowserSettingEnabled
- DiagnosticData
- TyposquattingCheckerEnabled

## Install Edge:

Command line instructions adapted from here: <https://www.microsoftedgeinsider.com/en-us/download>

```bash
curl -sSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
sudo mv microsoft.gpg /etc/apt/trusted.gpg.d/
sudo chown root:root /etc/apt/trusted.gpg.d/microsoft.gpg
sudo chmod 644 /etc/apt/trusted.gpg.d/microsoft.gpg
echo "deb [arch=amd64] https://packages.microsoft.com/repos/edge stable main" | sudo tee /etc/apt/sources.list.d/microsoft-edge-stable.list > /dev/null

sudo apt update
sudo apt install microsoft-edge-stable
```

## Optional Policies

You may want to adjust these policies.

Restore the previous session when the browser starts:

```json
 "RestoreOnStartup": 1,
```

Maintain login sessions and cookies for specific sites:

```json
  "SaveCookiesOnExit": [
    "https://[*.]google.com"
  ],
```

## Thanks & References

Policies are fully documentated here:
- <https://docs.microsoft.com/en-us/deployedge/microsoft-edge-policies>

Edge policy licenses:
- [CC-BY-4.0](https://github.com/MicrosoftDocs/Edge-Enterprise/blob/public/LICENSE)
- [MIT](https://github.com/MicrosoftDocs/Edge-Enterprise/blob/public/LICENSE-CODE)

This policy configuration is based on the following two resources:
- <https://www.microsoft.com/en-us/download/details.aspx?id=55319>
- <https://static.open-scap.org/ssg-guides/ssg-chromium-guide-stig.html>

Microsoft's Linux repositories:
- <https://docs.microsoft.com/en-us/windows-server/administration/linux-package-repository-for-microsoft-software>

Microsoft Edge Beta / Dev Channels:
- <https://www.microsoftedgeinsider.com/en-us/download>
