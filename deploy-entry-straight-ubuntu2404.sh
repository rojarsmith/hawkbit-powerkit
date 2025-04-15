#!/bin/bash
set -e

SUDO_PASS="$1"

echo "SUDO_PASS=$SUDO_PASS"

echo "$SUDO_PASS" | sudo -S sed -i -e 's/set compatible/set nocompatible/' /etc/vim/vimrc.tiny

if [ -f /etc/apt/sources.list.d/rabbitmq.list ]; then
  echo "Delete rabbitmq.list"
  echo "$SUDO_PASS" | sudo -S rm /etc/apt/sources.list.d/rabbitmq.list
fi

echo "$SUDO_PASS" | sudo -S apt-get -y update
echo "$SUDO_PASS" | sudo -S apt-get -y dist-upgrade
echo "$SUDO_PASS" | sudo -S apt-get -y autoclean
echo "$SUDO_PASS" | sudo -S apt-get -y autoremove

# --- MySQL ---

MYSQL_ROOT_PASSWORD='Passw@rd1234'

if systemctl status mariadb &>/dev/null; then
    echo "MySQL existed, skip"
else
    sudo apt-get -y install mariadb-server
    sudo systemctl enable mariadb
    sudo systemctl start mariadb

    sudo mysql <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
FLUSH PRIVILEGES;
GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost' WITH GRANT OPTION;
EOF

    echo "Tets MySQL："
    mysql -u root -p${MYSQL_ROOT_PASSWORD} -e "SELECT VERSION();"
    mysql -u root -p${MYSQL_ROOT_PASSWORD} -e \
        "CREATE DATABASE IF NOT EXISTS hawkbit CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    sudo systemctl daemon-reload
    sudo systemctl restart mariadb
fi

# --- RabbitMQ ---

RABBITMQ_ROOT_PASSWORD='Passw@rd1234'

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

sudo rabbitmqctl add_user mgr ${RABBITMQ_ROOT_PASSWORD}
sudo rabbitmqctl set_user_tags mgr administrator
sudo rabbitmqctl add_vhost /
sudo rabbitmqctl set_permissions -p / mgr ".*" ".*" ".*"
sudo rabbitmqctl delete_user guest

# --- Hawkbit ---

sudo apt-get -y install openjdk-21-jdk git maven curl

sudo mkdir -p /opt/hawkbit
sudo mkdir -p /opt/hawkbit/config
sudo mkdir -p /opt/hawkbit/lib
sudo wget -O /opt/hawkbit/hawkbit-update-server.jar https://github.com/rojarsmith/releases/releases/download/hawkbit/hawkbit-update-server-0.4.0JAP-SNAPSHOT.jar
sudo wget https://dlm.mariadb.com/4234102/Connectors/java/connector-java-3.5.3/mariadb-java-client-3.5.3.jar -P /opt/hawkbit/lib/
sudo chown -R root:root /opt/hawkbit

echo "$SUDO_PASS" | sudo tee /etc/systemd/system/hawkbit.service <<EOF
[Unit]
Description=Hawkbit
After=network.target

[Service]
User=root
ExecStart=/usr/bin/java -cp "/opt/hawkbit/lib/*:/opt/hawkbit/hawkbit-update-server.jar" org.springframework.boot.loader.JarLauncher --spring.config.location=/opt/hawkbit/config/ --spring.profiles.active=prod --spring.config.name=application,application-mysql,application-rabbitmq
SuccessExitStatus=143
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=hawkbit

[Install]
WantedBy=multi-user.target
EOF

sudo tee /opt/hawkbit/config/application-prod.properties <<EOF
spring.main.allow-bean-definition-overriding=true
EOF

sudo tee /opt/hawkbit/config/application-mysql-prod.properties <<EOF
spring.jpa.database=MYSQL
spring.datasource.url=jdbc:mariadb://localhost:3306/hawkbit
spring.datasource.username=root
spring.datasource.password=Passw@rd1234
spring.datasource.driverClassName=org.mariadb.jdbc.Driver
EOF

sudo tee /opt/hawkbit/config/application-rabbitmq-prod.properties <<EOF
spring.rabbitmq.username=mgr
spring.rabbitmq.password=Passw@rd1234
spring.rabbitmq.virtual-host=/
spring.rabbitmq.host=localhost
spring.rabbitmq.port=5672
EOF

sudo systemctl daemon-reload
sudo systemctl start hawkbit
sudo systemctl enable hawkbit
