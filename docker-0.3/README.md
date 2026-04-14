# Bitdove Docker

## Environment

Passed Ubuntu 22.04.

```bash
BITDOVE_HOME=~/service/bitdove
echo $BITDOVE_HOME
mkdir -p $BITDOVE_HOME
```

## Local Registry

```bash
# Private registry
docker run -d -p 5000:5000 --name registry --restart unless-stopped --env REGISTRY_STORAGE_DELETE_ENABLED=true --volume registry:/var/lib/registry registry:2

## Download remote image and push to local registry

# Make local JRE image
docker pull adoptopenjdk/openjdk11:jre-11.0.11_9-alpine
docker image list
docker image history adoptopenjdk/openjdk11:jre-11.0.11_9-alpine
# Mod tag to local
docker image tag adoptopenjdk/openjdk11:jre-11.0.11_9-alpine localhost:5000/openjdk11:jre-11.0.11_9-alpine
docker image push localhost:5000/openjdk11:jre-11.0.11_9-alpine
# Backup & restore
docker save -o adoptopenjdk_openjdk11.tar localhost:5000/openjdk11:jre-11.0.11_9-alpine
docker load -i adoptopenjdk_openjdk11.tar
# Remove image downloaded from remote
docker image rm adoptopenjdk/openjdk11:jre-11.0.11_9-alpine
docker image prune --force
##

# Check alive, Response {}
curl http://localhost:5000/v2/

# List all repositories
curl http://localhost:5000/v2/_catalog

# List all tags for a repository
curl http://localhost:5000/v2/openjdk11/tags/list

# Registry web
docker run -it -p 5001:8080 -d --name registry-web --link registry -e REGISTRY_URL=http://registry:5000/v2 -e REGISTRY_NAME=localhost:5000 --volume registry-web:/data hyper/docker-registry-web
```

### Make local busybox

```bash
docker image pull busybox:1.34.1
docker image list # Check TAG 1.34.1 existed
docker image tag busybox:1.34.1 localhost:5000/busybox:1.34.1
docker image push localhost:5000/busybox:1.34.1
docker image rm busybox:1.34.1
```

### Make local RabbitMQ

```bash
docker image pull rabbitmq:3.11.3-management
docker image tag rabbitmq:3.11.3-management localhost:5000/rabbitmq:3.11.3-management
docker image push localhost:5000/rabbitmq:3.11.3-management
docker image rm rabbitmq:3.11.3-management
```

### Make local MariaDB

```bash
docker image pull mariadb:10.9.4
docker image tag mariadb:10.9.4 localhost:5000/mariadb:10.9.4
docker image push localhost:5000/mariadb:10.9.4
docker image rm mariadb:10.9.4
```

## Build

Build from local registry.

```bash
cd $BITDOVE_HOME

# Add bitdove-update-server-0.3.0-SNAPSHOT.jar and other artifacts
mkdir -p $BITDOVE_HOME/artifact
cd $BITDOVE_HOME/bitdove-deployer/docker/artifact

# Check multi ssh "github-rojarsmith" worked.
git clone git@github-rojarsmith:rojarsmith/bitdove-docker.git

cd $BITDOVE_HOME/bitdove-deployer/docker
```

### Build JRE version image

```bash
docker image build --tag localhost:5000/jrever -f experiment/dockerfile-jrever .
docker image push localhost:5000/jrever
docker run --name jrever --publish 8080:8080 localhost:5000/jrever
docker image prune --all --force && docker container prune --force

# Running docker containers indefinitely
docker run --detach --entrypoint "/bin/sh" --name jrever --tty localhost:5000/jrever
# Jump into running container
docker container exec --interactive --tty jrever /bin/sh
```

### Build Bitdove

Building will replace old image each time.

```bash
# N means next version, base on M7
BITDOVE_VERSION=0.3.0M7N

docker image build --tag localhost:5000/bitdove:$BITDOVE_VERSION -f $BITDOVE_VERSION/dockerfile .

docker run --detach --name bitdove-update-server --publish 8180:8080 --volume bitdove:/opt/bitdove localhost:5000/bitdove:$BITDOVE_VERSION

docker image push localhost:5000/bitdove:$BITDOVE_VERSION

# Monitor real time log in another console
docker logs -f bitdove-update-server
```

### Build Bitdove with Mariadb connector

```bash
docker image build --tag localhost:5000/bitdove-mariadb:$BITDOVE_VERSION -f $BITDOVE_VERSION-mariadb/dockerfile .

docker image push localhost:5000/bitdove-mariadb:$BITDOVE_VERSION

docker run --detach --name bitdove-update-server-mariadb_0001 --publish 8180:8080 --volume bitdove_0001:/opt/bitdove/data localhost:5000/bitdove-mariadb:$BITDOVE_VERSION

## Debug
# If exited
docker run --detach --entrypoint "/bin/sh" --name bitdove-update-server-mariadb --tty localhost:5000/bitdove-mariadb:$BITDOVE_VERSION
# If running
docker container exec --interactive --tty bitdove-update-server-mariadb /bin/sh

docker container prune --force &&  docker volume prune --force
##
```



```bash
# Build for experiment
docker image build --tag localhost:5000/bitdove -f experiment/dockerfile .

docker run --detach --name bitdove-update-server --publish 8180:8080 localhost:5000/bitdove

docker run --detach --name bitdove-update-server --publish 8180:8080 --volume bitdove_001:/opt/bitdove localhost:5000/bitdove

docker container logs 

# Mount volume to /vol and run ls
docker run -it --rm -v hawkbit_001:/vol localhost:5000/busybox:1.34.1 ls -l /vol


docker run -it --name bitdove-update-server localhost:5000/bitdove /bin/sh


# Jump into exited container
docker run -it --name jrever localhost:5000/jrever /bin/sh

artifact
${ARTIFACT}


docker run -v my-jenkins-volume:/data --name helper busybox true
docker cp . helper:/data
docker rm helper

docker image prune --all
```



```dockerfile
ENTRYPOINT ["java","-jar","bitdove-update-server-0.3.0-SNAPSHOT.jar", "--spring.profiles.active=prod", "--spring.config.name=application", "--spring.config.location=$APP_HOME/data/properties", "--spring.config.additional-location=$APP_HOME/data/properties", "-Xms768m -Xmx768m -XX:MaxMetaspaceSize=250m -XX:MetaspaceSize=250m -Xss300K -XX:+UseG1GC -XX:+UseStringDeduplication -XX:+UseCompressedOops -XX:+HeapDumpOnOutOfMemoryError"]
```

