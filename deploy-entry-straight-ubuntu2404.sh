#!/bin/bash
set -e

SUDO_PASS="$1"

echo "SUDO_PASS=$SUDO_PASS"

if [ -f /etc/apt/sources.list.d/rabbitmq.list ]; then
  echo "Delete rabbitmq.list"
  echo "$SUDO_PASS" | sudo -S rm /etc/apt/sources.list.d/rabbitmq.list
fi

echo "$SUDO_PASS" | sudo -S apt-get -y update
echo "$SUDO_PASS" | sudo -S apt-get -y dist-upgrade
echo "$SUDO_PASS" | sudo -S apt-get -y autoclean
echo "$SUDO_PASS" | sudo -S apt-get -y autoremove

# --- MySQL ---

sudo apt-get -y install mariadb-server
sudo systemctl enable mariadb
sudo systemctl start mariadb

MYSQL_ROOT_PASSWORD='pa55W@rd'

sudo mysql <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
FLUSH PRIVILEGES;

GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost' WITH GRANT OPTION;
EOF

echo "Tets MySQL："
mysql -u root -p${MYSQL_ROOT_PASSWORD} -e "SELECT VERSION();"

# --- RabbitMQ ---

echo "$SUDO_PASS" | sudo -S apt-get -y install curl gnupg apt-transport-https

echo "Get key"

TMP_KEY_FILE=tmpkey
curl -1sLf "https://keys.openpgp.org/vks/v1/by-fingerprint/0A9AF2115F4687BD29803A206B73A36E6026DFCA" \
| gpg --dearmor > "$TMP_KEY_FILE"
echo "$SUDO_PASS" | sudo -S cp "$TMP_KEY_FILE" /usr/share/keyrings/com.rabbitmq.team.gpg
rm -f "$TMP_KEY_FILE"

TMP_KEY_FILE=tmpkey
curl -1sLf "https://github.com/rabbitmq/signing-keys/releases/download/3.0/cloudsmith.rabbitmq-erlang.E495BB49CC4BBE5B.key" \
| gpg --dearmor > "$TMP_KEY_FILE"
echo "$SUDO_PASS" | sudo -S cp "$TMP_KEY_FILE" /usr/share/keyrings/rabbitmq.E495BB49CC4BBE5B.gpg
rm -f "$TMP_KEY_FILE"

TMP_KEY_FILE=tmpkey
curl -1sLf "https://github.com/rabbitmq/signing-keys/releases/download/3.0/cloudsmith.rabbitmq-server.9F4587F226208342.key" \
| gpg --dearmor > "$TMP_KEY_FILE"
echo "$SUDO_PASS" | sudo -S cp "$TMP_KEY_FILE" /usr/share/keyrings/rabbitmq.9F4587F226208342.gpg
rm -f "$TMP_KEY_FILE"

echo "Create update list"

echo "$SUDO_PASS" | sudo tee /etc/apt/sources.list.d/rabbitmq.list <<EOF
## Provides modern Erlang/OTP releases
##
deb [arch=amd64 signed-by=/usr/share/keyrings/rabbitmq.E495BB49CC4BBE5B.gpg] https://ppa1.rabbitmq.com/rabbitmq/rabbitmq-erlang/deb/ubuntu noble main
deb-src [signed-by=/usr/share/keyrings/rabbitmq.E495BB49CC4BBE5B.gpg] https://ppa1.rabbitmq.com/rabbitmq/rabbitmq-erlang/deb/ubuntu noble main

# another mirror for redundancy
deb [arch=amd64 signed-by=/usr/share/keyrings/rabbitmq.E495BB49CC4BBE5B.gpg] https://ppa2.rabbitmq.com/rabbitmq/rabbitmq-erlang/deb/ubuntu noble main
deb-src [signed-by=/usr/share/keyrings/rabbitmq.E495BB49CC4BBE5B.gpg] https://ppa2.rabbitmq.com/rabbitmq/rabbitmq-erlang/deb/ubuntu noble main

## Provides RabbitMQ
##
deb [arch=amd64 signed-by=/usr/share/keyrings/rabbitmq.9F4587F226208342.gpg] https://ppa1.rabbitmq.com/rabbitmq/rabbitmq-server/deb/ubuntu noble main
deb-src [signed-by=/usr/share/keyrings/rabbitmq.9F4587F226208342.gpg] https://ppa1.rabbitmq.com/rabbitmq/rabbitmq-server/deb/ubuntu noble main

# another mirror for redundancy
deb [arch=amd64 signed-by=/usr/share/keyrings/rabbitmq.9F4587F226208342.gpg] https://ppa2.rabbitmq.com/rabbitmq/rabbitmq-server/deb/ubuntu noble main
deb-src [signed-by=/usr/share/keyrings/rabbitmq.9F4587F226208342.gpg] https://ppa2.rabbitmq.com/rabbitmq/rabbitmq-server/deb/ubuntu noble main
EOF

echo "$SUDO_PASS" | sudo -S apt-get -y update

echo "$SUDO_PASS" | sudo -S apt-get -y install \
    erlang-base \
    erlang-asn1 erlang-crypto erlang-eldap erlang-ftp erlang-inets \
    erlang-mnesia erlang-os-mon erlang-parsetools erlang-public-key \
    erlang-runtime-tools erlang-snmp erlang-ssl \
    erlang-syntax-tools erlang-tftp erlang-tools erlang-xmerl

echo "$SUDO_PASS" | sudo -S apt -y install \
    rabbitmq-server --fix-missing

echo "$SUDO_PASS" | sudo -S rabbitmq-plugins enable rabbitmq_management

