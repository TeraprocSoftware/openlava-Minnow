# Automated deployment of Minnow on local machine

Minnow is a project to automate the process of installing/deploying OpenLava cluster on Amazon EC2, and then to manage the life cycle of OpenLava cluster including actions of scaling in & out, stopping, restarting, deleting the cluster. Minnow deployer can install and deploy Minnow services (cluster manager, keystone, GUI, postgres, postfix) in an docker-enabled environment. 

## Before start
Please prepare your AWS account with your Access Key ID and Secret Access Key ready. Please refer to http://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSGettingStartedGuide/AWSCredentials.html 
for how to prepare Access Key ID and Secret Access Key

## Execute Minnow deployer
Edit following parameters in the script: start-cm.sh

  * CM_AWS_AMI_MAP - AMI of OpenLava host. Teraproc provide default images as "us-east-1:ami-30b7b858,us-west-1:ami-e335d9a7,eu-west-1:ami-c9ef80be,ap-southeast-1:ami-c6bd8194"
  * AWS_ACCESS_KEY_ID - your AWS access key
  * AWS_SECRET_KEY - your AWS secret key
  * CM_HOST_ADDR - Public IP address of your host on which Minnow services are running

Then execute: start-cm.sh

## Access Minnow GUI

Once the installation is finished, you may access the registration portal via http://<CM_HOST_ADDR>
