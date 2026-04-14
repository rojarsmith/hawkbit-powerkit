#!/bin/bash

docker container stop bitdove-update-server-mariadb_0001
docker container prune --force &&  docker volume prune --force
