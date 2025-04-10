# Hawkbit Powerkit

## ENV

### ubuntu 24.04

```bash
# OpenJDK
apt search openjdk | grep -E 'openjdk-.*-jdk/'
sudo apt install -y openjdk-21-jdk
sudo apt install -y git maven curl

# Service
sudo mkdir -p /root/service/hawkbit/config
sudo tree -d /root/service/hawkbit

# Build
cd ~
mkdir hawkbit; cd hawkbit
mkdir config

git clone https://github.com/rojarsmith/hawkbit-powerkit.git
```

## SSL/TLS

```bash
# CA
sudo tee /root/service/key/ca-openssl.cnf > /dev/null <<EOF
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_ca
prompt = no

[req_distinguished_name]
C = TW
ST = Taiwan
L = Taipei
O = My Local CA
CN = My Local CA

[v3_ca]
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:TRUE
keyUsage = critical, keyCertSign, cRLSign
EOF

# Server
sudo tee /root/service/key/server-localhost-openssl.cnf > /dev/null <<EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = TW
ST = Taiwan
L = Taipei
O = MyServer
CN = localhost

[v3_req]
subjectAltName = @alt_names
basicConstraints = CA:FALSE
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth

[alt_names]
DNS.1 = localhost
DNS.2 = vmota
EOF

sudo openssl req -x509 -out /root/service/key/localhost.crt -keyout /root/service/key/localhost.key \
  -newkey rsa:2048 -nodes -sha256 \
  -subj '/CN=localhost' -extensions EXT -config /root/service/key/localhost-openssl.cnf
  
sudo cp /root/service/key/localhost.crt /root/service/key/cert.pem
sudo cp /root/service/key/localhost.key /root/service/key/key.pem

# CA private key
sudo openssl genrsa -out /root/service/key/ca.key.pem 4096

# CA certification, Import to `Trusted Root Certification Authorities`
sudo openssl req -x509 -new -key /root/service/key/ca.key.pem -sha256 -days 3650 -out /root/service/key/ca.cert.pem \
-config /root/service/key/ca-openssl.cnf

sudo openssl x509 -in /root/service/key/ca.cert.pem -text -noout

# Server private key
sudo openssl genrsa -out /root/service/key/server.key.pem 4096

# CSR(Certificate Signing Request)
sudo openssl req -new -key /root/service/key/server.key.pem \
  -out /root/service/key/server.csr.pem \
  -config /root/service/key/server-localhost-openssl.cnf

# Sign to generate server cert
sudo openssl x509 -req \
  -in /root/service/key/server.csr.pem \
  -CA /root/service/key/ca.cert.pem \
  -CAkey /root/service/key/ca.key.pem \
  -CAcreateserial \
  -out /root/service/key/server.cert.pem \
  -days 825 -sha256 \
  -extfile /root/service/key/server-localhost-openssl.cnf \
  -extensions v3_req

sudo openssl x509 -in /root/service/key/server.cert.pem -text -noout

# Verify server cert
sudo openssl verify -CAfile /root/service/key/ca.cert.pem /root/service/key/server.cert.pem

sudo chmod 644 /root/service/key/server.key.pem

sudo openssl x509 -in /root/service/key/server.cert.pem -noout -text | grep -A1 "Subject:"

## Client

sudo openssl genrsa -out /root/service/key/client.key.pem 4096
sudo openssl req -new -key /root/service/key/client.key.pem -sha256 -out /root/service/key/client.csr.pem
sudo openssl x509 -req -in /root/service/key/client.csr.pem -CA /root/service/key/ca.cert.pem -CAkey /root/service/key/ca.key.pem -sha256 -days 365 -out /root/service/key/client.cert.pem

sudo openssl pkcs12 -export -out /root/service/key/cert.p12 \
  -in /root/service/key/client.cert.pem \
  -inkey /root/service/key/client.key.pem \
  -passin pass:keystorepass123 \
  -passout pass:keystorepass123

sudo openssl verify -CAfile /root/service/key/ca.cert.pem /root/service/key/cert.p12

sudo keytool -importcert \
  -alias rabbitmq-ca \
  -file /root/service/key/ca.cert.pem \
  -keystore /root/service/key/truststore.jks \
  -storepass truststorepass123 \
  -storetype JKS \
  -noprompt
  
sudo keytool -delete \
  -alias rabbitmq-ca \
  -keystore /root/service/key/truststore.jks \
  -storepass truststorepass123
  
sudo touch /root/service/hawkbit/config/rabbitmq.conf
sudo vi /root/service/hawkbit/config/rabbitmq.conf

sudo openssl s_client -connect localhost:5671 -CAfile /root/service/key/ca.cert.pem
sudo openssl s_client -connect localhost:5671 -cert /root/service/key/client.cert.pem \
  -key /root/service/key/client.key.pem \
  -CAfile /root/service/key/ca.cert.pem

sudo cp /root/service/key/ca.cert.pem /usr/local/share/ca-certificates/mgr-ca.crt
sudo update-ca-certificates
```

```ini
# rabbitmq.conf
listeners.ssl.default = 5671
ssl_options.cacertfile = /etc/rabbitmq/ssl/ca.cert.pem
ssl_options.certfile = /etc/rabbitmq/ssl/server.cert.pem
ssl_options.keyfile = /etc/rabbitmq/ssl/server.key.pem
ssl_options.verify = verify_peer
# ssl_options.verify = verify_none
ssl_options.fail_if_no_peer_cert = false

management.ssl.port       = 15671
management.ssl.cacertfile = /etc/rabbitmq/ssl/ca.cert.pem
management.ssl.certfile   = /etc/rabbitmq/ssl/server.cert.pem
management.ssl.keyfile    = /etc/rabbitmq/ssl/server.key.pem
management.ssl.verify     = verify_none
management.ssl.fail_if_no_peer_cert = false
```

## Build

### 0.8.0

```bash
mkdir -p binary-official/hawkbit-0.8.0
mkdir source-official; cd source-official
wget https://github.com/rojarsmith/hawkbit/archive/refs/tags/0.8.0.tar.gz \
-O hawkbit-0.8.0.tar.gz
tar -xzvf hawkbit-0.8.0.tar.gz
cd hawkbit-0.8.0

# Compile
for i in {1..10}; do mvn -T$(nproc) clean install -DskipTests && break || echo "Build $i times failed, try again..."; done

# OR
mvn -T$(nproc) clean install -DskipTests

# If multiple errors occur during the compilation process, it may be caused by unstable network disconnection and failure to download all dependencies. It is difficult to see the error by looking at the error code alone. Just execute the same compilation several times.

find . -type f -name 'hawkbit-*.jar*' -exec cp {} ../../binary-official/hawkbit-0.8.0 \;
```

## Fast Run

```bash
cd ~/hawkbit
java -jar binary-official/hawkbit-0.8.0/hawkbit-update-server-0-SNAPSHOT.jar  --hawkbit.dmf.rabbitmq.enabled=false

java -jar binary-official/hawkbit-0.8.0/hawkbit-update-server-0-SNAPSHOT.jar --spring.config.location=/root/service/hawkbit/config/ --spring.profiles.active=prod --spring.config.name=application-mysql,application-rabbitmq

# Port: 8088
java -jar binary-official/hawkbit-0.8.0/hawkbit-simple-ui-0-SNAPSHOT.jar

sudo docker compose -f docker-compose-deps-mysql.yml up -d
```

## Docker

```bash
## RabbitMQ
# 1 time
sudo docker compose -f hawkbit-powerkit/docker/docker-compose-deps-rabbitmq.yml exec rabbitmq env
sudo docker compose -f hawkbit-powerkit/docker/docker-compose-deps-rabbitmq.yml down
sudo docker compose --env-file /root/service/hawkbit/config/rabbitmq.env -f hawkbit-powerkit/docker/docker-compose-deps-rabbitmq.yml up -d
sudo docker container ls

sudo docker exec -it docker-rabbitmq-1 bash
sudo docker exec -it docker-rabbitmq-1 /bin/sh
sudo docker inspect docker-rabbitmq-1

sudo openssl s_client -connect rabbitmq-host:5671 -CAfile /root/service/key/ca.cert.pem
sudo docker stats

## MySQL
sudo docker compose -f hawkbit-powerkit/docker/docker-compose-deps-mysql.yml down
sudo docker compose --env-file /root/service/hawkbit/config/mysql.env -f hawkbit-powerkit/docker/docker-compose-deps-mysql.yml up -d
sudo docker exec -it docker-mysql-1 bash
sudo docker exec -it docker-mysql-1 mysql -u root -pPassw@rd1234 hawkbit -e "CREATE TABLE IF NOT EXISTS table_user (id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(100)); INSERT INTO table_user (name) VALUES ('Alice'), ('Bob');"
sudo docker exec -it docker-mysql-1 mysql -u root -pPassw@rd1234 hawkbit -e "SELECT * FROM table_user;"
sudo docker exec -it docker-mysql-1 mysql -u root -pPassw@rd1234 hawkbit -e "DROP TABLE IF EXISTS table_user;"

# Backup
sudo docker exec docker-mysql-1 mysqldump -u root -pPassw@rd1234 hawkbit | sudo tee /root/service/hawkbit/db/mysql_data_backup/backup-$(date +%F).sql > /dev/null
# Restore
sudo bash -c "cat /root/service/hawkbit/db/mysql_data_backup/backup-YYYY-MM-DD.sql | docker exec -i docker-mysql-1 mysql -u root -pPassw@rd1234 hawkbit"

# Hawkbit
mkdir ~/hawkbit/binary-mod # put in mod jar
pushd ~/hawkbit/hawkbit-powerkit/docker/entry
cp ~/hawkbit/binary-mod/hawkbit-update-server-0.4.0JAP-SNAPSHOT.jar .
cp ~/hawkbit/binary-mod/hawkbit-device-simulator-0.4.0-SNAPSHOT.jar .
sudo chmod -R 777 hawkbit-update-server-0.4.0JAP-SNAPSHOT.jar
sudo chmod -R 777 hawkbit-device-simulator-0.4.0-SNAPSHOT.jar
sudo docker build -t hawkbit-server:0.4.0JAP -f dockerfile .
popd

# Web UI: http://localhost:8088

jar tf hawkbit-update-server-0.4.0JAP-SNAPSHOT.jar

sudo vi /root/service/hawkbit/config/application-mysql-docker-prod.properties
sudo vi /root/service/hawkbit/config/application-rabbitmq-docker-prod.properties

cd ~/hawkbit/hawkbit-powerkit/docker
sudo docker compose -f hawkbit-powerkit/docker/docker-compose-hawkbit.yml down
sudo docker compose -f hawkbit-powerkit/docker/docker-compose-hawkbit.yml up

sudo chmod -R 777 ../binary-official/hawkbit-0.8.0/hawkbit-update-server-0-SNAPSHOT.jar
cp ../binary-official/hawkbit-0.8.0/hawkbit-update-server-0-SNAPSHOT.jar ./docker/hawkbit-update-server-SNAPSHOT.jar
```

## Config

```bash
sudo mkdir -p /root/service/hawkbit/config
sudo vi /root/service/hawkbit/config/application-prod.properties
sudo vi /root/service/hawkbit/config/application-rabbitmq-prod.properties
sudo vi /root/service/hawkbit/config/application-mysq-prod.properties

# RabbitMQ
sudo cp hawkbit-powerkit/docker/rabbitmq.env /root/service/hawkbit/config/rabbitmq.env
sudo vi /root/service/hawkbit/config/rabbitmq.env

# MySQL
sudo tee /root/service/hawkbit/config/mysql.cnf > /dev/null <<EOF
[mysqld]
user=mysql
default-storage-engine=INNODB
character-set-server=utf8
[client]
default-character-set=utf8
[mysql]
default-character-set=utf8
EOF
sudo cp hawkbit-powerkit/docker/mysql.env /root/service/hawkbit/config/mysql.env
```

```bash
# application-prod.properties
spring.main.allow-bean-definition-overriding=true
```

```ini
# application-mysql-prod.properties
spring.jpa.database=MYSQL
spring.datasource.url=jdbc:mariadb://localhost:3306/hawkbit
spring.datasource.username=root
spring.datasource.password=Passw@rd1234
spring.datasource.driverClassName=org.mariadb.jdbc.Driver
#spring.datasource.sql-script-encoding=utf-8
#spring.datasource.continue-on-error=false
#spring.datasource.separator=;
```

```ini
# application-rabbitmq-prod.properties
spring.rabbitmq.username=mgr
spring.rabbitmq.password=Passw@rd1234
spring.rabbitmq.virtual-host=/
spring.rabbitmq.host=localhost
spring.rabbitmq.port=5672
# spring.rabbitmq.port=5671 # SSL 

spring.rabbitmq.ssl.enabled=true
#spring.rabbitmq.ssl.verify-hostname=false
#spring.rabbitmq.ssl.validate-server-certificate=false

# mutual TLS (optional)
#spring.rabbitmq.ssl.key-store=file:/root/service/key/cert.p12
#spring.rabbitmq.ssl.key-store-password=keystorepass123
#spring.rabbitmq.ssl.key-store-type=PKCS12

# CA
#spring.rabbitmq.ssl.trust-store=file:/root/service/key/truststore.jks
#spring.rabbitmq.ssl.trust-store-password=truststorepass123
#spring.rabbitmq.ssl.trust-store-type=JKS
```

```ini
# rabbitmq.env
ABBITMQ_VHOST=/
RABBITMQ_USER=mgr
RABBITMQ_PASS=Passw@rd1234
```

```ini
# mysql.env
MYSQL_DATABASE=hawkbit
MYSQL_ROOT_PASSWORD=Passw@rd1234
```

## Service

```bash
cd ~/hawkbit
sudo mkdir /root/service/hawkbit/bin
sudo cp binary-official/hawkbit-0.8.0/hawkbit-update-server-0-SNAPSHOT.jar /root/service/hawkbit/bin

sudo touch /etc/systemd/system/hawkbit.service
sudo vi /etc/systemd/system/hawkbit.service

sudo systemctl daemon-reexec
sudo systemctl start hawkbit
sudo systemctl enable hawkbit # Auto start
sudo systemctl stop hawkbit
sudo systemctl daemon-reload
sudo systemctl restart hawkbit
sudo systemctl status hawkbit
sudo systemctl | more
sudo systemctl | grep "hawkbit"
sudo systemctl list-units --type=service
# active
sudo systemctl is-active hawkbit

# http://localhost:8080
```

```ini
# /etc/systemd/system/hawkbit.service
[Unit]
Description=Hawkbit
After=network.target

[Service]
User=root
ExecStart=/usr/bin/java -jar /root/service/hawkbit/bin/hawkbit-update-server-0-SNAPSHOT.jar --spring.config.location=/root/service/hawkbit/config/ --spring.profiles.active=prod --spring.config.name=application-mysql,application-rabbitmq
# ExecStart=/usr/bin/java -Djavax.net.debug=ssl,handshake -jar /root/service/hawkbit/bin/hawkbit-update-server-0-SNAPSHOT.jar --spring.config.name=application-rabbitmq --spring.config.location=/root/service/hawkbit/config/ --spring.profiles.active=prod # Debug SSL
SuccessExitStatus=143
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=hawkbit

[Install]
WantedBy=multi-user.target
```

## Log

```bash
vi /etc/systemd/journald.conf
ls /run/log/journal/

# Check journal disk usage
sudo journalctl --disk-usage
sudo journalctl -u hawkbit
sudo journalctl -u hawkbit -f -o cat # Listening
sudo journalctl -u hawkbit -n 1 --output=json-pretty
rm hawkbit_april.log; sudo journalctl -u hawkbit --since "2025-04-01 00:00:00" --until "2025-04-03 23:59:59" > hawkbit_april.log
# Clean all
sudo journalctl --rotate
sudo journalctl --vacuum-time=1s
```

## Storage

Hawkbit is using the file system by default storage path `./artifactrepo`. This can be changed via property `org.eclipse.hawkbit.repository.file.path`.

```bash
sudo mkdir -p /root/service/hawkbit/artifact
```

## Database

```bash
sudo mkdir -p /root/service/hawkbit/db/mysql_data_backup
sudo rm -R /root/service/hawkbit/db/mysql_data

# Backup
# cronjob container
# host cron
```

