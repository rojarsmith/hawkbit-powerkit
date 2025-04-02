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
```

## Config

```bash

```

```ini

```

