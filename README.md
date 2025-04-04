# Hawkbit Powerkit

## ENV

### ubuntu 24.04

```bash
sudo apt install open-vm-tools-desktop

# OpenJDK
apt search openjdk | grep -E 'openjdk-.*-jdk/'
sudo apt install openjdk-21-jdk
sudo apt install git maven

# Service
sudo mkdir -p /root/service/hawkbit
sudo ls /root

# Build
cd ~
mkdir hawkbit; cd hawkbit
mkdir config
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

## Run

```bash
cd ~/hawkbit
java -jar binary-official/hawkbit-0.8.0/hawkbit-update-server-0-SNAPSHOT.jar  --hawkbit.dmf.rabbitmq.enabled=false
# Port: 8088
java -jar binary-official/hawkbit-0.8.0/hawkbit-simple-ui-0-SNAPSHOT.jar

sudo docker compose -f docker-compose-deps-mysql.yml up -d
```

## Config

```bash

```

```ini

```

## Service

```bash
sudo mkdir /root/service/hawkbit/bin
sudo cp binary-official/hawkbit-0.8.0/hawkbit-update-server-0-SNAPSHOT.jar /root/service/hawkbit/bin

sudo touch /etc/systemd/system/hawkbit.service
sudo vi /etc/systemd/system/hawkbit.service

sudo systemctl daemon-reexec
sudo systemctl start hawkbit
sudo systemctl enable hawkbit # Auto start
sudo systemctl stop hawkbit
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
ExecStart=/usr/bin/java -jar /root/service/hawkbit/bin/hawkbit-update-server-0-SNAPSHOT.jar
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
sudo journalctl -u hawkbit -n 1 --output=json-pretty
rm hawkbit_april.log; sudo journalctl -u hawkbit --since "2025-04-01 00:00:00" --until "2025-04-03 23:59:59" > hawkbit_april.log
# Clean all
sudo journalctl --rotate
sudo journalctl --vacuum-time=1s
```

