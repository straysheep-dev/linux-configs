# kali-configs

Files to autoamtically configure Kali for general use, and avoid repeating steps after installing.

## Updating & Upgrading

<https://www.kali.org/docs/general-use/updating-kali/>

With a rolling distribution like Kali, on occassion apt will have package dependancy conflicts that require apt's upgrade to remove packages.

```bash
sudo apt update && sudo apt full-upgrade -y
```

This will handle the conflicts correctly and upgrade Kali.
