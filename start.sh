#!/usr/bin/env bash

show_help() {
  echo "Usage: ./start.sh"
  echo ""
  echo "-d or --down delete all container"
  echo "-s or --skip-image-build if you want to skip the creation of share and repo image"
  echo "-hi or --host-ip set the host ip"
  echo "-hp or --host-port set the host port. Default 8080"
  echo "-w or --wait wait for backend. Default true"
  echo "-uq or --use-quay-images skip creating backend images and use quay images for ACS and share"
  echo "-h or --help"
}

skip_image_build(){
  SKIP_IMAGE_BUILD="true"
}

down(){
  docker-compose down
  ./delete-storage-container.sh ${AZURE_DELETED_CONTAINER_NAME}
  ./delete-storage-container.sh ${AZURE_CONTAINER_NAME}
  exit 0
}

set_host_ip(){
  SET_HOST_IP=$1
}

set_host_port(){
  HOST_PORT=$1
}

set_wait(){
  WAIT=$1
}

get_value_from_pom(){
  TAG=$1
  POM=$2

  # echo "get_value_from_pom $TAG $POM"

  sed -ne "/$TAG/{s/.*<$TAG>\(.*\)<\/$TAG>.*/\1/p;q;}" $POM
}

error(){
  echo "::error:: $1"
  sleep 5
  exit 1
}

use_quay_images(){
  echo "use_quay_images ..."
  SKIP_IMAGE_BUILD="true"
  REGISTRY_DEFAULT=$(get_value_from_pom image.registry pom.xml)/
  # SHARE_TAG_DEFAULT=$(get_value_from_pom share.version docker/share-idms/pom.xml)
  REPO_TAG_DEFAULTG=$(get_value_from_pom acs.version pom.xml)

  REGISTRY=${REGISTRY:-$REGISTRY_DEFAULT}
  SHARE_TAG=${SHARE_TAG:-$SHARE_TAG_DEFAULT}
  REPO_TAG=${REPO_TAG:-$REPO_TAG_DEFAULTG}

  echo "REGISTRY: $REGISTRY"
  echo "SHARE_TAG: $SHARE_TAG"
  echo "REPO_TAG: $REPO_TAG"
}

# Defaults
WAIT="true"
SET_HOST_IP=""
HOST_PORT="8080"
REGISTRY=""
SHARE_TAG="latest"
REPO_TAG="latest"

while [[ $1 == -* ]]; do
  case "$1" in
    -h|--help|-\?) show_help; exit 0;;
    -d|--down)  down; shift;;
    -w|--wait)  set_wait $2; shift 2;;
    -hi|--host-ip)  set_host_ip $2; shift 2;;
    -hp|--host-port)  set_host_port $2; shift 2;;
    -s|--skip-image-build)  skip_image_build; shift;;
    -uq|--use-quay-images)  use_quay_images; shift;;
    -*) echo "invalid option: $1" 1>&2; show_help; exit 1;;
  esac
done

# Fix container names if set
if [ ! -n "${AZURE_CONTAINER_NAME}" ]
then
  error "AZURE_CONTAINER_NAME missing"
fi
if [ ! -n "${AZURE_DELETED_CONTAINER_NAME}" ]
then
  error "AZURE_DELETED_CONTAINER_NAME missing"
fi
if [ ! -n "${AZURE_STORAGE_ACCOUNT_NAME}" ]
then
  error "AZURE_STORAGE_ACCOUNT_NAME missing"
fi
if [ ! -n "${AZURE_STORAGE_ACCOUNT_KEY}" ]
then
  error "AZURE_STORAGE_ACCOUNT_KEY missing"
fi

echo "AZURE_CONTAINER_NAME: ${AZURE_CONTAINER_NAME}"
echo "AZURE_DELETED_CONTAINER_NAME: ${AZURE_DELETED_CONTAINER_NAME}"
echo "AZURE_STORAGE_ACCOUNT_NAME: ${AZURE_STORAGE_ACCOUNT_NAME}"
echo "AZURE_STORAGE_ACCOUNT_KEY: ${AZURE_STORAGE_ACCOUNT_KEY}"

if [[ $SKIP_IMAGE_BUILD != "true" ]]
then
  echo "Create ACS enterprise image with AMPs: azure connector"
  mvn clean install -PbuildDockerImage
else
  echo "Skipping Share and Repo Image Creation ..."
fi

echo "Starting ACS stack"
docker-compose up -d

if [ $? -eq 0 ]
then
  echo "Docker Compose started ok"
else
  error "Docker Compose failed to start" >&2
fi

if [[ $WAIT == "true" ]]
then
  WAIT_INTERVAL=1
  COUNTER=0
  TIMEOUT=300
  t0=`date +%s`

  echo "Waiting for alfresco to start"
  until $(curl --output /dev/null --silent --head --fail http://localhost:8082/alfresco) || [ "$COUNTER" -eq "$TIMEOUT" ]; do
    printf '.'
    sleep $WAIT_INTERVAL
    COUNTER=$(($COUNTER+$WAIT_INTERVAL))
  done

  if (("$COUNTER" < "$TIMEOUT")) ; then
    t1=`date +%s`
    delta=$((($t1 - $t0)/60))
    echo "Alfresco Started in $delta minutes"
  else
    echo "Waited $COUNTER seconds"
    echo "Alfresco Could not start in time."
    echo "START of Alfresco service logs for investigation"
    docker-compose logs --tail="all" alfresco
    error "END of Alfresco service logs for investigation"
  fi
fi