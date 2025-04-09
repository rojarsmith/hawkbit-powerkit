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

## TLS

```bash
sudo mkdir -p /root/service/key
# CA private key
sudo openssl genrsa -out /root/service/key/ca.key.pem 4096
# CA certification
sudo openssl req -x509 -new -key /root/service/key/ca.key.pem -subj "/C=TW/ST=TAIWAN/O=yowko" -sha256 -days 365 -out /root/service/key/ca.cert.pem
# Server private key
sudo openssl genrsa -out /root/service/key/server.key.pem 4096
# CSR(Certificate Signing Request)
sudo openssl req -new -key /root/service/key/server.key.pem -subj "/C=TW/ST=TAIWAN/O=yowko/CN=localhost" -sha256 -out /root/service/key/server.csr.pem
# Sign to generate server cert
sudo openssl x509 -req -in /root/service/key/server.csr.pem -CA /root/service/key/ca.cert.pem -CAkey /root/service/key/ca.key.pem -sha256 -days 365 -out /root/service/key/server.cert.pem
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

openssl verify -CAfile /root/service/key/ca.cert.pem /root/service/key/cert.p12

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
sudo docker compose --env-file  /root/service/hawkbit/config/rabbitmq.env -f hawkbit-powerkit/docker/docker-compose-deps-rabbitmq.yml up -d
sudo docker container ls

sudo docker exec -it docker-rabbitmq-1 /bin/sh
sudo docker inspect docker-rabbitmq-1

openssl s_client -connect rabbitmq-host:5671 -CAfile /root/service/key/ca.cert.pem
```

## Config

```bash
sudo mkdir -p /root/service/hawkbit/config
sudo vi /root/service/hawkbit/config/application-rabbitmq-prod.properties
# RabbitMQ
sudo cp hawkbit-powerkit/docker/rabbitmq.env /root/service/hawkbit/config/rabbitmq.env
sudo vi /root/service/hawkbit/config/rabbitmq.env
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
spring.rabbitmq.ssl.trust-store=file:/root/service/key/truststore.jks
spring.rabbitmq.ssl.trust-store-password=truststorepass123
spring.rabbitmq.ssl.trust-store-type=JKS
```

```ini
# rabbitmq.env
ABBITMQ_VHOST=/
RABBITMQ_USER=mgr
RABBITMQ_PASS=Passw@rd1234
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
ExecStart=/usr/bin/java -jar /root/service/hawkbit/bin/hawkbit-update-server-0-SNAPSHOT.jar --spring.config.location=/root/service/hawkbit/config/ --spring.profiles.active=prod --spring.config.name=application-rabbitmq 
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

