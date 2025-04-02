# Hawkbit Powerkit

## ENV

### ubuntu 24.04

```bash
# OpenJDK
apt search openjdk | grep -E 'openjdk-.*-jdk/'
sudo apt install openjdk-17-jdk
sudo apt install openjdk-21-jdk
sudo update-alternatives --config java
sudo apt install git maven

sudo apt install open-vm-tools-desktop
cd ~
mkdir hawkbit; cd hawkbit/
```

## Build

### 0.8.0

```bash
mkdir binary-official
mkdir source-official; cd source-official
wget https://github.com/rojarsmith/hawkbit/archive/refs/tags/0.8.0.tar.gz \
-O hawkbit-0.8.0.tar.gz
tar -xzvf hawkbit-0.8.0.tar.gz
cd hawkbit-0.8.0
mvn -T$(nproc) clean install -DskipTests

# If multiple errors occur during the compilation process, it may be caused by unstable network disconnection and failure to download all dependencies. It is difficult to see the error by looking at the error code alone. Just execute the same compilation several times.

cp hawkbit-monolith/hawkbit-update-server/target/hawkbit-update-server* ../../binary-official
```

## Run

```bash
cd ~/hawkbit
java -jar binary-official/hawkbit-update-server-0-SNAPSHOT.jar
```

