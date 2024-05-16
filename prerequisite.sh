#!/bin/bash

set echo off

echo "--------------------------------------------------"
echo "--            Creating the NAMESPACES           --"
echo "--------------------------------------------------"

# Define the secret details
SECRET_NAME="acrsecret2"
DOCKER_SERVER="ionatestregistry.azurecr.io"
DOCKER_USERNAME="ionatestregistry"
DOCKER_PASSWORD="A/So/z9Buscg+V6aJkWgL2qdK47KgIxJks+nWtnff7+ACRDniEKP"
DOCKER_EMAIL="akshaykumar.jadhav@hcl.com"

# Define the namespaces
NAMESPACES=("core-ns" "datahub-ns" "act-ns" "observe-ns")
 
# Loop through each namespace and create it
for NAMESPACE in "${NAMESPACES[@]}"; do
  # Create the namespace
  kubectl create namespace "$NAMESPACE"
done

echo ""
echo "--    Check the namespaces    --"
kubectl get namespace -A

echo ""
echo "===================================================================="

echo "--------------------------------------------------------------------"
echo "--      Creating the Docker Registry Secret in All Namespaces     --"
echo "--------------------------------------------------------------------"


# Loop through each namespace and create the docker-registry secret
for NAMESPACE in "${NAMESPACES[@]}"; do
  kubectl create secret docker-registry $SECRET_NAME \
    --docker-server=$DOCKER_SERVER \
    --docker-username=$DOCKER_USERNAME \
    --docker-password=$DOCKER_PASSWORD \
    --docker-email=$DOCKER_EMAIL \
    --namespace $NAMESPACE
done

echo ""
echo "--    Check the Secret $SECRET_NAME in all namespaces    --"
kubectl get secrets -A

echo ""
echo "========================================================================="

echo "---------------------------------------------------"
echo "--       Creating the Amazon EBS CSI Driver      --"
echo "---------------------------------------------------"

# Variables for EBS CSI
MY_CLUSTER="iona-demo"
ROLE_NAME="AmazonEKS_EBS_CSI_DriverRole"
EBS_POLICY_ARN="arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
REGION="us-west-2"
#ACCOUNT_ID="716523076871"

# This section is for creating the Amazon EBS CSI driver
# make sure that eksetl is installed in the CLI
# Create an IAM role and attach a policy. (Using EKSETL)

eksctl create iamserviceaccount \
    --name ebs-csi-controller-sa \
    --namespace kube-system \
    --cluster $MY_CLUSTER \
	--region $REGION \
	--role-name $ROLE_NAME \
    --role-only \
    --attach-policy-arn $EBS_POLICY_ARN \
    --approve


# Installing the Amazon EBS CSI driver as EKS add-on

aws eks create-addon --cluster-name iona-demo --addon-name aws-ebs-csi-driver \
  --service-account-role-arn arn:aws:iam::716523076871:role/AmazonEKS_EBS_CSI_DriverRole

# Verify the installation
echo "--  Check the EBS add-on in kube-system  --"
kubectl get pods --namespace=kube-system|grep -i ebs

echo "---------------------------------------------------"
echo "---       Deploying Storage Class Manifest      ---"
echo "---------------------------------------------------"

kubectl apply -f ./others/ebs-sc.yaml

echo ""
echo "--    Check the Storage Class(ebs-sc)    --"
kubectl get storageclass -A|grep -i ebs-sc

echo ""
echo "============================================================================="

echo "----------------------------------------------------"
echo "--          Installing Secret Manager CSI         --"
echo "----------------------------------------------------"

# Add and install Secret Manager CSI Driver 
helm repo add secrets-store-csi-driver https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts

helm install csi-secrets-store secrets-store-csi-driver/secrets-store-csi-driver --namespace kube-system --set syncSecret.enabled=true --set enableSecretRotation=true

# Verify Secret Manager CSI Driver is installed
kubectl get daemonsets -n kube-system -l app.kubernetes.io/instance=csi-secrets-store

# Add and install Secret Manager CSI Driver Provider
helm repo add aws-secrets-manager https://aws.github.io/secrets-store-csi-driver-provider-aws

helm install -n kube-system secrets-provider-aws aws-secrets-manager/secrets-store-csi-driver-provider-aws

# Verify both the installation
kubectl get pods --namespace=kube-system|grep -i secrets

# Make sure that secrets (keys and values) are added in secret manager at AWS console.
# Also, make sure that 'secret manager access policy' is created 
# Attach 'secret manager access policy' to the 'IAM role' with OIDC provider of the eks cluster

echo "--   Secrets must be added in AWS Secret Manager   --"
echo "--       IAM Policy is secret-manager-access       --"
echo "--          IAM Role is iona-demo-sa-role          --"

echo "---------------------------------------------------------------"
echo "--       Deploying Service Accounts in All Namespaces        --"
echo "--     Deploying Secret Provider Class in All Namespaces     --"
echo "---------------------------------------------------------------"

# Create service account in all namespaces to fetch from AWS Secret Manager
# create Secret Provider Class in all namespaces to fetch from AWS Secret Manager

# Define the namespaces
NAMESPACES=("datahub-ns" "act-ns" "core-ns")
 
# Define the YAML files to be deployed
YAML_FILES=("./others/service-account.yaml" "./others/secretproviderclass.yaml")
 
# Loop through each namespace and deploy the YAML files
for NAMESPACE in "${NAMESPACES[@]}"; do
  echo "Deploying to namespace $NAMESPACE"
 
  # Loop through each YAML file
  for YAML_FILE in "${YAML_FILES[@]}"; do
    echo "Applying $YAML_FILE to namespace $NAMESPACE"
 
    # Apply the YAML file to the specified namespace
    kubectl apply -f $YAML_FILE -n $NAMESPACE
 
    # Check if the deployment was successful
    if [ $? -eq 0 ]; then
      echo "Successfully applied $YAML_FILE to namespace $NAMESPACE"
    else
      echo "Failed to apply $YAML_FILE to namespace $NAMESPACE"
      exit 1
    fi
  done
 
  echo "Finished deploying to namespace $NAMESPACE"
done

echo ""
echo ""
echo "--  Check the Service accounts created in all namespaces  --"
kubectl get sa -A |head -10
echo ""
echo ""
echo "--  Check the Secret Provider Class created in all namespaces  --"
kubectl get secretproviderclass -A

rm -f ./kafka-helm/Chart.lock
echo "--------------------------------------------------"
echo "--           Script execution completed.        --"
echo "--------------------------------------------------"

