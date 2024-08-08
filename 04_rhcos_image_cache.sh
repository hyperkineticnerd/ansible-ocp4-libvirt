#!/bin/bash

##### Pre-requisites
# dnf install -y podman
# firewall-cmd --add-port=8080/tcp --zone=public --permanent
# firewall-cmd --reload

##### Download Location
mkdir /home/kni/rhcos_image_cache
semanage fcontext -a -t httpd_sys_content_t "/home/kni/rhcos_image_cache(/.*)?"
restorecon -Rv /home/kni/rhcos_image_cache/

##### Download Image
export RHCOS_QEMU_URI=$(/usr/local/bin/openshift-baremetal-install coreos print-stream-json | jq -r --arg ARCH "$(arch)" '.architectures[$ARCH].artifacts.qemu.formats["qcow2.gz"].disk.location')
export RHCOS_QEMU_NAME=${RHCOS_QEMU_URI##*/}
export RHCOS_QEMU_UNCOMPRESSED_SHA256=$(/usr/local/bin/openshift-baremetal-install coreos print-stream-json | jq -r --arg ARCH "$(arch)" '.architectures[$ARCH].artifacts.qemu.formats["qcow2.gz"].disk["uncompressed-sha256"]')
curl -L ${RHCOS_QEMU_URI} -o /home/kni/rhcos_image_cache/${RHCOS_QEMU_NAME}

##### Host Image
podman run -d --name rhcos_image_cache -v /home/kni/rhcos_image_cache:/var/www/html -p 8080:8080/tcp quay.io/centos7/httpd-24-centos7:latest

##### Generate install-config.yaml flag
export BAREMETAL_IP=$(ip addr show dev baremetal | awk '/inet /{print $2}' | cut -d"/" -f1)
export BOOTSTRAP_OS_IMAGE="http://${BAREMETAL_IP}:8080/${RHCOS_QEMU_NAME}?sha256=${RHCOS_QEMU_UNCOMPRESSED_SHA256}"
echo "    bootstrapOSImage=${BOOTSTRAP_OS_IMAGE}"
