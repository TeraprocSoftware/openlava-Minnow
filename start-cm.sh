#!/bin/bash

[[ "$TRACE" ]] && set -x

: ${DEBUG:=1}
: ${DOCKER_TAG_POSTGRES:=latest}
: ${DOCKER_TAG_CLUSTERMANAGER:=openlava}
: ${DOCKER_TAG_USERMANAGER:=latest}
: ${DOCKER_TAG_POSTFIX:=latest}
: ${DOCKER_TAG_GUI:=openlava}

debug() {
    [[ "$DEBUG" ]] && echo "[DEBUG] $*" 1>&2
}

set_env_props() {
    ####################################
    #        Mandatory parameters      #
    ####################################
    # Base images for each cloud provider

    # Openlava 3.0 2015.04.30
    export CM_AWS_AMI_MAP="us-east-1:ami-30b7b858,us-west-1:ami-e335d9a7,eu-west-1:ami-c9ef80be,ap-southeast-1:ami-c6bd8194"

    # Host address for identity server and mail server
    export CM_INTERNAL_HOST_ADDR=$(hostname -i)

    # AWS access key
    export AWS_ACCESS_KEY_ID=
    export AWS_SECRET_KEY=

    # Cluster Manager public IP address. If not set, ngrok
    # introspective tunnel will be used.
    export CM_HOST_ADDR=http://$(curl -s -m 5 http://169.254.169.254/latest/meta-data/public-ipv4):8080
    ####################################
    #        Optional parameters       #
    ####################################
 
    # Clustermanager DB config
    export CM_DB_ENV_USER="postgres"
    export CM_DB_ENV_PASS="postgres"
    export CM_HBM2DDL_STRATEGY="update"

    # Keystone identity server URL
    export CM_IDENTITY_SERVER_URL=http://$CM_INTERNAL_HOST_ADDR:35357

    # GUI notification endpoint URL
    export CM_GUI_SERVER_URL=http://$CM_INTERNAL_HOST_ADDR/notifications

    # THe SMTP server host
    export CM_SMTP_SENDER_HOST=$CM_INTERNAL_HOST_ADDR
    # THe SMTP server port
    export CM_SMTP_SENDER_PORT=25

    export CM_BLUEPRINT_DEFAULTS="lambda-architecture,multi-node-hdfs-yarn,hdp-multinode-default"
}

check_env_props() {
    source $(dirname $BASH_SOURCE)/check_env.sh
    if [ $? -ne 0 ]; then
      exit 1;
    fi
}

check_start() {
    declare desc="Check if container has already been started"
    debug $desc
    local name=$1
    if [ -z "$name" ]; then
      debug No container name specified
      exit 1;
    fi
    Id=$(docker inspect -f "{{ .Id }}" $name 2> /dev/null)
    if [ $? -ne 0 ]; then
      return 1;
    fi
    if [ -z "$Id" ]; then
      debug Cannot find container id for container: $name
      return 1;
    fi  
    debug $name id: $Id
    Running=$(docker inspect -f "{{ .State.Running }}" $name)
    if [ "$Running" == "true" ]; then
      debug Container $name is already running
      return 0
    fi
    debug Container $name status: $Running
    debug Attemp to start the existing $name container
    debug Running: docker start $Id
    docker start $Id
    return $?
}

start_postfix() {
    declare desc="starts postfix component"
    debug $desc

    check_start postfix
    if [ $? -eq 0 ]; then
      return 0
    fi

    docker run --privileged --restart=always -d \
        --name=postfix \
        -p 25:25 \
        -v /var/spool/postfix:/var/spool/postfix \
        teraproc/postfix:$DOCKER_TAG_POSTFIX
}

start_usermanager() {
    declare desc="starts keystone identity server"
    debug $desc

    check_start keystone
    if [ $? -eq 0 ]; then
      return 0
    fi
    
    docker run --privileged --restart=always -d \
      --name=keystone \
      -p 5000:5000 -p 35357:35357 \
      -v /var/lib/keystone/keystone_db:/var/lib/keystone -v /var/spool/postfix:/var/spool/postfix \
      teraproc/keystone:$DOCKER_TAG_USERMANAGER
}

start_clustermanager_db() {
    declare desc="starts postgresql container for Cluster Manager backend"
    debug $desc

    check_start cmdb
    if [ $? -eq 0 ]; then
      return 0
    fi

    docker run --privileged --restart=always -d \
      --name=cmdb \
      -e "SERVICE_NAME=cmdb" \
      -e SERVICE_CHECK_CMD='psql -h 127.0.0.1 -p 5432 -U postgres -c "select 1"' \
      -v /var/lib/clustermanager/cmdb:/var/lib/postgresql/data \
      postgres:$DOCKER_TAG_POSTGRES
}

cm_envs_to_docker_options() {
  declare desc="create -e var=value options for docker run with all CM_XXX env variables"

  DOCKER_CM_ENVS=""
  for var in  ${!CM_*}; do
    DOCKER_CM_ENVS="$DOCKER_CM_ENVS -e $var=${!var}"
  done
}

start_clustermanager() {
    declare desc="starts clustermanager component"
    debug $desc

    check_start clustermanager
    if [ $? -eq 0 ]; then
      return 0
    fi

    cm_envs_to_docker_options

    docker run --privileged --restart=always -d \
        --name=clustermanager \
        --link cmdb:cm_db \
        -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
        -e AWS_SECRET_KEY=$AWS_SECRET_KEY \
        -e SERVICE_NAME=clustermanager \
        -e SERVICE_CHECK_HTTP=/info \
        -e ENDPOINTS_AUTOCONFIG_ENABLED=false \
        -e ENDPOINTS_DUMP_ENABLED=false \
        -e ENDPOINTS_TRACE_ENABLED=false \
        -e ENDPOINTS_CONFIGPROPS_ENABLED=false \
        -e ENDPOINTS_METRICS_ENABLED=false \
        -e ENDPOINTS_MAPPINGS_ENABLED=false \
        -e ENDPOINTS_BEANS_ENABLED=false \
        -e ENDPOINTS_ENV_ENABLED=false \
        $DOCKER_CM_ENVS \
        -p 8080:8080 \
        teraproc/clustermanager:$DOCKER_TAG_CLUSTERMANAGER bash
}

start_gui() {
    declare desc="starts gui component"
    debug $desc

    check_start gui
    if [ $? -eq 0 ]; then
      return 0
    fi

    docker run -d --restart=always --name gui \
         -e "IDENTITY_ADMIN_ADDRESS=http://${CM_INTERNAL_HOST_ADDR}:35357" \
         -e "IDENTITY_USER_ADDRESS=http://${CM_INTERNAL_HOST_ADDR}:5000" \
         -e "IDENTITY_ADMIN_TOKEN=ADMIN" \
         -e "CLUSTER_MANAGER_ADDRESS=http://${CM_INTERNAL_HOST_ADDR}:8080" \
         -p 80:3000 \
         -v /var/spool/postfix:/var/spool/postfix \
         teraproc/gui:$DOCKER_TAG_GUI
}

check_root() {
    uid=$(id -u)

    if [ ! $uid -eq 0 ] ; then
      echo This script must run as root
      exit 1
    fi
}

main() {
  check_root
  set_env_props
  check_env_props
  start_postfix
  start_usermanager
  start_clustermanager_db
  start_clustermanager
  start_gui
}

[[ "$BASH_SOURCE" == "$0" ]] && main "$@"
