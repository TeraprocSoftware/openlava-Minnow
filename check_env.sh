#!/bin/bash

# SMTP properties
: ${CM_SMTP_SENDER_HOST:?"Please add the SMTP host. Check the following entry in the env_props.sh file: CB_SMTP_SENDER_HOST="}
: ${CM_SMTP_SENDER_PORT:?"Please add the SMTP port. Check the following entry in the env_props.sh file: CB_SMTP_SENDER_PORT="}

# AWS related (optional) settings - not setting them causes AWS related operations to fail
: ${AWS_ACCESS_KEY_ID:?"Please set the AWS access key. Check the following entry in the env_props.sh file:AWS_ACCESS_KEY_ID="}
: ${AWS_SECRET_KEY:?"Please set the AWS secret. Check the following entry in the env_props.sh file: AWS_SECRET_KEY="}

echo ==============================================================
echo Starting Teraproc Cluster Manager with the following settings:

for p in "${!CM_@}"; do
  echo $p=${!p}
done
echo ==============================================================
