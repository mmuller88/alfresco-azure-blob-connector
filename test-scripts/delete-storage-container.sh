#!/usr/bin/env bash

container_name=$1

if [[ -z "${container_name}" ]]
then
  echo "Please provide container to delete."
  exit 1
fi

# Substitute all '/' to '-' and then remove all '-'
# Convert any UPPER case letter(s) to lower case: https://blogs.msdn.microsoft.com/jmstall/2014/06/12/azure-storage-naming-rules/
container_name=`echo ${container_name} | tr / - | tr -d - | tr '[:upper:]' '[:lower:]'`

az storage container delete --name ${container_name} --account-name=${AZURE_STORAGE_ACCOUNT_NAME} --account-key=${AZURE_STORAGE_ACCOUNT_KEY}