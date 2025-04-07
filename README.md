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
sudo openssl req -new -key /root/service/key/server.key.pem -sha256 -out /root/service/key/server.csr.pem
# Sign to generate server cert
sudo openssl x509 -req -in /root/service/key/server.csr.pem -CA /root/service/key/ca.cert.pem -CAkey /root/service/key/ca.key.pem -sha256 -days 365 -out /root/service/key/server.cert.pem
# Verify server cert
sudo openssl verify -CAfile /root/service/key/ca.cert.pem /root/service/key/server.cert.pem
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
# 1 time
sudo docker compose -f hawkbit-powerkit/docker/docker-compose-deps-rabbitmq.yml exec rabbitmq env
sudo docker compose -f hawkbit-powerkit/docker/docker-compose-deps-rabbitmq.yml down
sudo docker compose --env-file  /root/service/hawkbit/config/rabbitmq.env -f hawkbit-powerkit/docker/docker-compose-deps-rabbitmq.yml up

sudo docker compose -f hawkbit-powerkit/docker/docker-compose-deps-rabbitmq.yml up -d
```

## Config

```bash
sudo mkdir -p /root/service/hawkbit/config
sudo vi /root/service/hawkbit/config/application-rabbitmq-prod.properties
sudo cp hawkbit-powerkit/docker/rabbitmq.env /root/service/hawkbit/config/rabbitmq.env
sudo vi /root/service/hawkbit/config/rabbitmq.env
```

```ini
spring.rabbitmq.username=mgr
spring.rabbitmq.password=Passw@rd1234
spring.rabbitmq.virtual-host=/
spring.rabbitmq.host=localhost
spring.rabbitmq.port=5672
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
StandardOutput=syslog
StandardError=syslog
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
sudo journalctl -u hawkbit -f # Listening
sudo journalctl -u hawkbit -n 1 --output=json-pretty
rm hawkbit_april.log; sudo journalctl -u hawkbit --since "2025-04-01 00:00:00" --until "2025-04-03 23:59:59" > hawkbit_april.log
# Clean all
sudo journalctl --rotate
sudo journalctl --vacuum-time=1s
```

