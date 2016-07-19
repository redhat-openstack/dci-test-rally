#!/bin/bash

set -eux
stack_name=$1
sudo yum install -y openstack-rally

# https://ask.openstack.org/en/question/67875/how-to-properly-pass-image-argument-to-glance/
export OS_IMAGE_API_VERSION=1

source ~/${stack_name}rc
[ -d ~/.rally ] || mkdir ~/.rally
[ -d ~/.rally/plugins ] || git clone http://github.com/redhat-openstack/rally-plugins.git ~/.rally/plugins
if [ ! -f CentOS-7-x86_64-GenericCloud.raw ]; then
    curl http://cloud.centos.org/centos/7/images/CentOS-7-x86_64-GenericCloud.raw.tar.gz|tar xfz -
    find . -regex '\./CentOS-7-x86_64-GenericCloud-*[0-9]+.raw' -exec mv {} CentOS-7-x86_64-GenericCloud.raw \;
fi

glance image-show CentOS-7-x86_64-GenericCloud || glance image-create --name "CentOS-7-x86_64-GenericCloud" --disk-format qcow2 --container-format bare --is-public=1 --progress < CentOS-7-x86_64-GenericCloud.raw

[ -f cirros-0.3.2-x86_64-vmlinuz ] || curl http://download.cirros-cloud.net/0.3.2/cirros-0.3.2-x86_64-uec.tar.gz  | tar zfxv -
KERNEL_ID=`glance image-create --name "cirros-0.3.2-x86_64-uec-kernel" --disk-format aki --container-format aki --is-public=1 --file cirros-0.3.2-x86_64-vmlinuz | awk '/ id / { print $4 }'`
RAMDISK_ID=`glance image-create --name "cirros-0.3.2-x86_64-uec-ramdisk" --disk-format ari --container-format ari --is-public=1 --file cirros-0.3.2-x86_64-initrd | awk '/ id / { print $4 }'`
glance image-show cirros-0.3.2-x86_64-uec || glance image-create --name cirros-0.3.2-x86_64-uec --disk-format ami --container-format ami --is-public=1 --property kernel_id=$KERNEL_ID --property ramdisk_id=$RAMDISK_ID --file cirros-0.3.2-x86_64-blank.img


[ -f CentOS-7-x86_64-GenericCloud.qcow2 ] || curl http://cloud.centos.org/centos/7/images/CentOS-7-x86_64-GenericCloud.qcow2.xz | unxz - > CentOS-7-x86_64-GenericCloud.qcow2

sudo chmod 644 /etc/rally/rally.conf
rally-manage db recreate
rally deployment create --fromenv --name=existing
[ -d rally ] || git clone https://github.com/openstack/rally


cat << EOF > rally/samples/tasks/scenarios/allinone.yaml
---
  KeystoneBasic.create_update_and_delete_tenant:
    -
      args:
        name_length: 10
      runner:
        type: "constant"
        times: 10
        concurrency: 2
      sla:
        failure_rate:
          max: 0.0

  KeystoneBasic.create_delete_user:
    -
      args:
        name_length: 10
      runner:
        type: "constant"
        times: 10
        concurrency: 2
      sla:
        failure_rate:
         max: 0.0

  Authenticate.keystone:
    -
      runner:
        type: "constant"
        times: 10
        concurrency: 2
      context:
        users:
          tenants: 2
          users_per_tenant: 2
      sla:
        failure_rate:
         max: 0.0

  Authenticate.validate_cinder:
    -
      args:
        repetitions: 2
      runner:
        type: "constant"
        times: 10
        concurrency: 2
      context:
        users:
          tenants: 2
          users_per_tenant: 2
      sla:
        failure_rate:
         max: 0.0

  Authenticate.validate_glance:
    -
      args:
        repetitions: 2
      runner:
        type: "constant"
        times: 10
        concurrency: 2
      context:
        users:
          tenants: 2
          users_per_tenant: 2
      sla:
        failure_rate:
         max: 0.0

  Authenticate.validate_neutron:
    -
      args:
        repetitions: 2
      runner:
        type: "constant"
        times: 10
        concurrency: 2
      context:
        users:
          tenants: 2
          users_per_tenant: 2
      sla:
        failure_rate:
         max: 0.0

  Authenticate.validate_nova:
    -
      args:
        repetitions: 2
      runner:
        type: "constant"
        times: 10
        concurrency: 2
      context:
        users:
          tenants: 2
          users_per_tenant: 2
      sla:
        failure_rate:
         max: 0.0

  GlanceImages.create_and_delete_image:
    -
      args:
        image_location: "/home/stack/CentOS-7-x86_64-GenericCloud.qcow2"
        container_format: "bare"
        disk_format: "qcow2"
      runner:
        type: "constant"
        times: 4
        concurrency: 2
      context:
        users:
          tenants: 2
          users_per_tenant: 2
      sla:
        failure_rate:
          max: 0.0

  CinderVolumes.create_and_extend_volume:
    -
      args:
        size: 8
        new_size: 16
        volume_type: 'VOLUME_TYPE'
      runner:
        type: "constant"
        times: 10
        concurrency: 2
      context:
        users:
          tenants: 1
          users_per_tenant: 1
      sla:
        failure_rate:
          max: 0.0

  CinderVolumes.create_and_delete_volume:
    -
      args:
        size: 8
        min_sleep: 15
        max_sleep: 20
        volume_type: 'VOLUME_TYPE'
      runner:
        type: "constant"
        times: 10
        concurrency: 2
      context:
        users:
          tenants: 2
          users_per_tenant: 2
      sla:
        failure_rate:
          max: 0.0

  CinderVolumes.create_and_upload_volume_to_image:
    -
      args:
        size: 8
        force: false
        container_format: "bare"
        disk_format: "raw"
        do_delete: true
        volume_type: 'VOLUME_TYPE'
      runner:
        type: "constant"
        times: 5
        concurrency: 2
      context:
        users:
          tenants: 2
          users_per_tenant: 2
      sla:
        failure_rate:
          max: 0.0

  NeutronNetworks.create_and_delete_networks:
    -
      args:
        network_create_args: {}
      runner:
        type: "serial"
        times: 2
      context:
        users:
          tenants: 1
          users_per_tenant: 1
        quotas:
          neutron:
            network: -1
      sla:
        failure_rate:
          max: 0.0

  NeutronNetworks.create_and_delete_ports:
    -
      args:
        network_create_args: {}
        port_create_args: {}
        ports_per_network: 10
      runner:
        type: "serial"
        times: 2
      context:
        users:
          tenants: 1
          users_per_tenant: 1
        quotas:
          neutron:
            network: -1
            port: -1
            subnet: -1
      sla:
        failure_rate:
          max: 0.0

  NeutronNetworks.create_and_delete_routers:
    -
      args:
        network_create_args: {}
        subnet_create_args: {}
        subnet_cidr_start: "10.0.0.0/24"
        subnets_per_network: 1
        router_create_args: {}
      runner:
        type: "serial"
        times: 2
      context:
        users:
          tenants: 1
          users_per_tenant: 1
        quotas:
          neutron:
            network: -1
            subnet: -1
            router: -1
      sla:
        failure_rate:
          max: 0.0

  NeutronNetworks.create_and_delete_subnets:
    -
      args:
        network_create_args: {}
        subnet_create_args: {}
        subnet_cidr_start: "10.1.0.0/24"
        subnets_per_network: 1
      runner:
        type: "serial"
        times: 2
      context:
        users:
          tenants: 1
          users_per_tenant: 1
        quotas:
          neutron:
            network: -1
            subnet: -1
      sla:
        failure_rate:
          max: 0.0

  NovaKeypair.boot_and_delete_server_with_keypair:
    -
      args:
        flavor:
            name: "m1.medium"
        image:
            name: "CentOS-7-x86_64-GenericCloud"
      runner:
        type: "constant"
        times: 5
        concurrency: 2
      context:
        users:
          tenants: 2
          users_per_tenant: 1
      sla:
        failure_rate:
          max: 0.0

  NovaKeypair.create_and_delete_keypair:
    -
      runner:
        type: "constant"
        times: 10
        concurrency: 2
      context:
        users:
          tenants: 3
          users_per_tenant: 2
      sla:
        failure_rate:
          max: 0.0

  NovaServers.boot_and_delete_server:
    -
      args:
        flavor:
            name: "m1.medium"
        image:
            name: "CentOS-7-x86_64-GenericCloud"
        force_delete: false
      runner:
        type: "constant"
        times: 10
        concurrency: 2
      context:
        users:
          tenants: 3
          users_per_tenant: 2
      sla:
        failure_rate:
          max: 0.0

  NovaServers.boot_and_rebuild_server:
   -
      args:
       flavor:
           name: "m1.medium"
       from_image:
           name: "CentOS-7-x86_64-GenericCloud"
       to_image:
           name: "CentOS-7-x86_64-GenericCloud"
      runner:
        type: "constant"
        times: 6
        concurrency: 2
      context:
        users:
          tenants: 1
          users_per_tenant: 1
      sla:
        failure_rate:
          max: 0.0

  NovaServers.boot_server_from_volume_and_delete:
    -
      args:
        flavor:
            name: "m1.medium"
        image:
            name: "CentOS-7-x86_64-GenericCloud"
        volume_size: 10
        force_delete: false
      runner:
        type: "constant"
        times: 6
        concurrency: 2
      context:
        users:
          tenants: 3
          users_per_tenant: 2
      sla:
        failure_rate:
          max: 0.0

  NovaServers.pause_and_unpause_server:
    -
      args:
        flavor:
            name: "m1.medium"
        image:
            name: "CentOS-7-x86_64-GenericCloud"
        force_delete: false
      runner:
        type: "constant"
        times: 6
        concurrency: 2
      context:
        users:
          tenants: 3
          users_per_tenant: 2
      sla:
        failure_rate:
          max: 0.0

  NovaServers.snapshot_server:
    -
      args:
        flavor:
            name: "m1.medium"
        image:
            name: "CentOS-7-x86_64-GenericCloud"
        force_delete: false
      runner:
        type: "constant"
        times: 6
        concurrency: 2
      context:
        users:
          tenants: 3
          users_per_tenant: 2
      sla:
        failure_rate:
          max: 0.0

  NovaServers.suspend_and_resume_server:
    -
      args:
        flavor:
            name: "m1.medium"
        image:
            name: "CentOS-7-x86_64-GenericCloud"
        force_delete: false
      runner:
        type: "constant"
        times: 6
        concurrency: 2
      context:
        users:
          tenants: 3
          users_per_tenant: 2
      sla:
        failure_rate:
          max: 0.0

  Quotas.cinder_update_and_delete:
    -
      args:
        max_quota: 1024
      runner:
        type: "constant"
        times: 10
        concurrency: 2
      context:
        users:
          tenants: 3
          users_per_tenant: 2
      sla:
        failure_rate:
          max: 0.0

  Quotas.nova_update_and_delete:
    -
      args:
        max_quota: 1024
      runner:
        type: "constant"
        times: 10
        concurrency: 2
      context:
        users:
          tenants: 3
          users_per_tenant: 2
      sla:
        failure_rate:
          max: 0.0
EOF

rally task start rally/samples/tasks/scenarios/allinone.yaml
rally task report --junit --out result.xml
