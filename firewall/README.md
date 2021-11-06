# Firewall Scripts

### Why?

* Provide firewall / network setup scripts for different baselines
* No hardcoded unique variables
* Scripts can be accessed publicly
* Scripts can be installed as commands

### Example Usage:
```bash
# download the chosen script
cd $(mktemp -d)
curl -LfO '<script>'
# adjust permissions for usage
sudo chown root '<script>'
sudo chgrp root '<script>'
sudo chmod 755 '<script>'
# add the script to your path as a command
sudo mkdir /opt/scripts
sudo mv 'script' -t /opt/scripts/
sudo ln -s /opt/scripts/'<script>' /usr/local/bin/setup-firewall
# run the script as a command
sudo setup-firewall
