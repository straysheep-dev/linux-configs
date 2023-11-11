# refresh-smartcard.sh

# MIT License

# This is a smaller version of the yubi-mode.sh script
# Run this anytime the yubikey has issues signing or authenticating

# https://github.com/drduh/YubiKey-Guide#switching-between-two-or-more-yubikeys

pkill gpg-agent ; pkill ssh-agent ; pkill pinentry
#eval $(gpg-agent --daemon --enable-ssh-support)
gpg-connect-agent "scd serialno" "learn --force" /bye
gpg-connect-agent updatestartuptty /bye
