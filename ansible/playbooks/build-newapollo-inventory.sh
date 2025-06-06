#!/bin/bash

IFS='' read -d '' -r usage_str <<EOF
Usage: $(basename $0) [ -t template_file ] [ -r root_disk_device ] [-u ubuntu_version ] apollo_number custom_hostname private_ip_address
Where:
    template_file = an existing inventory template file (default: buildapollo.template)
    apollo_number = 001-998 for target_environment=prod, or 999 for target_environment=test
    custom_hostname = alphanumeric string with '-' allowed within string
    private_ip_address = 192.168.X.Y
    root_disk_device = /dev/vda2 (default)
    ubuntu_version = default is 24.04 otherwise specify, eg 22.04
Output:
    buildapollo.XXX.inventory: resulting ansible inventory file for building apollo instance
                               (where XXX=apollo_number)
EOF

template_file="buildapollo.template"
apollo_instance_number="0"
custom_hostname=""
ip_address=""
root_disk_device="/dev/vda2" # Nectar ARDC
ubuntu_version="24.04"
target_environment="prod"

if [ $# -gt 1 ] && [ "$1" = "-t" ]; then
    shift
    template_file="$1"
    shift
fi

if [ $# -gt 1 ] && [ "$1" = "-r" ]; then
    shift
    if [[ $1 =~ ^/dev/[vs]da1$ ]]; then
      root_disk_device="$1"
      shift
    else
      echo >&2 "invalid root disk device: $1"
      exit 1
    fi
fi

if [ $# -gt 1 ] && [ "$1" = "-u" ]; then
    shift
    if [[ $1 =~ ^[0-9][0-9].[0-9][0-9]$ ]]; then
      ubuntu_version="$1"
      shift
    else
      echo >&2 "invalid ubuntu version: $1"
      exit 1
    fi
fi

if [ $# -gt 0 ] && [ "${1:0:1}" = "-" ]; then
    echo >&2 "$usage_str"
    exit 1
fi

if [ $# -ne 3 ]; then
    echo >&2 "$usage_str"
    exit 1
fi

if [[ $1 =~ ^[0-9][0-9][0-9]$ ]]; then
    # bash treats numbers with leading 0's as octal - ansible appears to be doing the same
    # so for apollo_instance_number in the inventory file to be treated as base 10 by ansible
    # remove leading zeros - here by explicitly converting to base 10 with 10#
    apollo_instance_number="$((10#$1))"
    apollo_full_number=$1
fi

if [ $apollo_instance_number = "0" ]; then
    echo >&2 "invalid apollo_number: $1"
    exit 1
elif [ $apollo_instance_number = "999" ]; then
    target_environment="test"
fi
shift

# allow hyphen only within string
if [[ $1 =~ ^[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9]$ ]] || [[ $1 =~ ^[a-zA-Z0-9] ]]; then
    custom_hostname=$1
fi
if [ -z "$custom_hostname" ]; then
    echo >&2 "invalid custom hostname: $1"
    exit 1
fi
shift

if [[ $1 =~ ^192\.168\.[0-9]+\.[0-9]+$ ]]; then
    ip_address=$1
fi
if [ -z "$ip_address" ]; then
    echo >&2 "invalid private IP address: $1"
    exit 1
fi
shift



inventory_file="buildapollo.${apollo_full_number}.inventory"
apollo_name="apollo-${apollo_full_number}"


sed "s/APOLLOINSTANCENUMBER/${apollo_instance_number}/g; s/APOLLONAME/${apollo_name}/g; s/CUSTOMHOSTNAME/${custom_hostname}/g; s/PRIVATEIP/${ip_address}/g; s#ROOTDISKDEVICE#${root_disk_device}#g; s/UBUNTUVERSION/${ubuntu_version}/g; s/TESTORPROD/${target_environment}/g" $template_file > $inventory_file

echo >&2 "ansible inventory file generated for apollo build: ${inventory_file}"

