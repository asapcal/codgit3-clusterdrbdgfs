#!/bin/sh
#
# Description: Startup script for clustredrbdgfs dual-primary mode!
#
# Copyright (C) 2029 - 2029 Asaph <asaph.lac.19@hotmail.com>
#

#$ cat /etc/hosts
#127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
#::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
#novos nomes e ips
#10.255.255.x    n1drbd.cluster vm1.cluster
#10.255.255.x    n2drbd.cluster vm2.cluster

#Stop / disable Network Manager on all mvs / vms / servers involved.
#[vm1]
systemctl disable NetworkManager
#Removed symlink /etc/systemd/system/multi-user.target.wants/NetworkManager.service.
#Removed symlink /etc/systemd/system/dbus-org.freedesktop.NetworkManager.service.
#Removed symlink /etc/systemd/system/dbus-org.freedesktop.nm-dispatcher.service.
#Removed symlink /etc/systemd/system/network-online.target.wants/NetworkManager-wait-online.service.

#Configure a server NTP
#[vm1]
systemctl enable ntpd
Created symlink from /etc/systemd/system/multi-user.target.wants/ntpd.service to /usr/lib/systemd/system/ntpd.service.
#[vm1]
firewall-cmd --add-service=high-availability
#Warning: ALREADY_ENABLED: 'high-availability' already in 'public'
#success
#[vm1]
firewall-cmd --reload
#success

#Install the necessary rpms.

yum install epel-release -y


#Install pacemaker and fence agents.

yum install pcs fence-agentes-all -y   
#ou 
yum install -y pacemaker pcs psmisc policycoreutils-python

#Add the new rules and restart the firewall.

firewall-cmd --permanent --add-service=high-availability

#Check the status of selinux with: 

sestatus

#Check if the TCP / UDP ports we enabled during the first step are really enabled, according to the initial firewall configuration.

#[root@vm1 ~]# iptables -nL | grep <porta>

#If so, set the password for the cluster:

echo password | passwd --stdin hacluster

#Changing password for user hacluster.

#passwd: all authentication tokens have been updated successfully.

#Start the pacemaker cluster manager. On each node.
systemctl enable --now pcsd
#Created symlink from /etc/systemd/system/multi-user.target.wants/pcsd.service to /usr/lib/systemd/system/pcsd.service.

#Authenticate the hacluster in any of the mv’s. Us:hacluster Se:pasword

pcs cluster auth vm1.cluster vm2.cluster

#Now, on your first pc, vm, node, etc., type and execute the command below to create the cluster and start it.

pcs cluster setup --start --name mycluster vm1.cluster vm2.cluster

#The cluster resource is active. If you’ve never seen it, here are some commands to help you manage this feature. 

#[root@vm1 ~]# pcs

#[root@vm1 ~]# pcs status help
#[root@vm1 ~]# pacemakerd –features

#Enable the feature with the pacemaker and corosync
# Check the cluster status

pcs cluster enable --all
#vm1.cluster: Cluster Enabled
#vm2.cluster: Cluster Enabled

pcs cluster status


#Check the quorum cluster

#[vm1]
corosync-cfgtool -s

#Check the real-time status of the cluster

#[vm1]
crm_mon  

#[vm1]
corosync-cmapctl | grep members

#IPC: In case of error, review previous steps.

#Here are some support links here in case there are configuration or system errors.
# https://bugs.launchpad.net/debian/+source/pcs/+bug/1640923
# https://shgonzalez.github.io/linux/ha/2017/10/02/How-to-solve-pacemaker-error.html
# https://oss.clusterlabs.org/pipermail/pacemaker/2014-September/022536.html
# https://github.com/ClusterLabs/pcs/issues/153
# http://fibrevillage.com/sysadmin/317-pacemaker-and-pcs-on-linux-example-cluster-creation-add-a-node-to-cluster-remove-a-node-from-a-cluster-desctroy-a-cluster

#Important command!

[root@vm1 ~]# sudo pcs cluster setup --force vm1.cluster vm2.cluster --name mycluster

#Configuring the fence and stonith_xvm on the cluster nodes;

pcs stonith show

#If all steps were done correctly, there will be no devices configured with this feature. The return message will look something like this: 
#“NO stonith devicesconfigured”.

pcs property set no-quorum-policy=freeze

pcs property set stonith-enabled=true

pcs property show

#Cluster Properties:
# cluster-infrastructure: corosync
# cluster-name: mycluster
# dc-version: 1.1.19-8.el7_6.4-c3c624ea3d
# have-watchdog: false
# stonith-enabled: true

#Check the pacemaker and corosync and see their cluster status.

pcs cluster cib

ps axf

journalctl -b | grep -i error

systemctl status firewalld

pcs stonith show

yum install pcs fence-agents-all -y

pcs stonith list

systemctl status pcsd.service

#Creating the fence / stonith resource on the cluster nodes.

pcs stonith create fence_n1 fence_xvm pcmk_host_list="vm1" port="vm1.cluster"


#pcs stonith create fence_n2 fence_xvm pcmk_host_list="vm2" port="vm2.cluster"

pcs stonith show

#Install the missing packages on the mvs / nos / servers

yum -y install fence-agents-all fence-agents-virsh fence-virt pacemaker-remotepcs fence-virtd resource-agents fence-virtd-libvirt fence-virtd-multicast

#Enable the fence agent to run the feature

systemctl start fence_virtd

systemctl enable fence_virtd

#Release the corresponding tcp port to perform the fence feature

firewall-cmd --add-port=1229/tcp --permanent 

# See https://www.ibm.com/developerworks/community/blogs/mhhaque/entry/how_to_configure_red_hat_cluster_with_fencing_of_two_kvm_guests
#_running_on_two_ibm_powerkvm_hosts?lang=en for creating the fence key.

#To create the xvm key, do:

#[root@vmcluster tmp]# 

dd if=/dev/urandom of=/etc/cluster/fence_xvm.key bs=4k count=1

#Copy the file to all nodes (mvs) via scp

sudo scp /etc/cluster/fence_xvm.key user@vm2.cluster:/tmp/

#In the destination node (mv) copy the key to the desired directory

#[root@vm2 tmp]# 

#mv fence_xvm.key /etc/cluster/fence_xvm.key

#Configure the key for use

#fence_virtd -c

#In this tutorial the default configuration was made, only accepting it without modification

pcs stonith create fence_vm2 fence_xvm pcmk_host_list="vm1" port="vm1.cluster"

pcs stonith create fence_vm1 fence_xvm pcmk_host_list="vm2" port="vm2.cluster"

#https://www.unixarena.com/2016/01/rhel7-configuring-gfs2-on-pacemakercorosync-cluster.html/

#An alternative configuration, this link presents a more alternative and simple configuration.

#Now let's activate the fence and stonith agent feature. 

pcs cluster fence_xvm enable

#pcs cluster fence_xvm enable

pcs property set no-quorum-pilocy=freeze

#In all nos (mvs) of the cluster. Here are just the examples.

systemctl enable fence_virtd.service

systemctl start fence_virtd.service

firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="10.255.255.X" port port="1229" protocol="tcp" accept' 

firewall-cmd –reload

iptables -xnvL

pcs property set stonith-enabled=true

#After this series of commands the fence_xvm feature, stonith should start. To confirm:

pcs status

#Cluster name: mycluster
#Stack: corosync
#Current DC: vm2.cluster (version 1.1.19-8.el7_6.4-c3c624ea3d) - partition with quorum
#Last updated: Wed Sep  4 09:55:17 2019
#Last change: Wed Sep  4 08:54:31 2019 by root via cibadmin on vm1.cluster

#2 nodes configured
#2 resources configured

#Online: [ vm1.cluster vm2.cluster ]

#Full list of resources:

# xvmfence_n1	(stonith:fence_xvm):	Started vm1.cluster
# xvmfence_n2	(stonith:fence_xvm):	Started vm2.cluster

#Daemon Status:
#  corosync: active/enabled
#  pacemaker: active/enabled
#  pcsd: active/enabled
  
pcs stonith show
  
# xvmfence_n1	(stonith:fence_xvm):	Started vm1.cluster
# xvmfence_n2	(stonith:fence_xvm):	Started vm2.cluster  

#DLM and CLVM and GFS2FS which will also be installed. (On both machines)

yum install gfs2-utils lvm2-cluster dlm

#Before proceeding, it is necessary to change or check the change in the following properties of the cluster:

pcs property set no-quorum-policy=freeze

#Check if the dlm-clone resource [dlm] is in ‘Started’ mode if it isn’t already checked, as there must be some configuration error.

#Configuring the CLVM feature.

grep locking_type /etc/lvm/lvm.conf | egrep -v '#' locking_type = 3

#..to change dynamically.

lvmconf –enable-cluster

systemctl disable lvm2-lvmetad --now

#Warning: Stopping lvm2-lvmetad.service, but it can still be activated by: lvm2-lvmetad.socket

#Create the clvm resource, and verify that the resources are active.

pcs resource create clvmd ocf:heartbeat:clvm op monitor interval=30s on-fail=fence clone interleave=true ordered=true
 
pcs status

#Cluster name: mycluster
#Stack: corosync
#Current DC: vm2.cluster (version 1.1.19-8.el7_6.4-c3c624ea3d) - partition with quorum
#Last updated: Wed Sep  4 15:01:53 2019
#Last change: Wed Sep  4 15:00:13 2019 by root via cibadmin on vm1.cluster

#2 nodes configured
#6 resources configured

#Online: [ vm1.camcluster vm2.cluster ]

#Full list of resources:

# xvmfence_n1	(stonith:fence_xvm):	Started vm1.cluster
# xvmfence_n2	(stonith:fence_xvm):	Started vm2.cluster
# Clone Set: dlm-clone [dlm]
#     Started: [ vm1.cluster vm2.cluster ]
# Clone Set: clvmd-clone [clvmd]
#     Started: [ vm1.cluster vm2.cluster ]
#
#Daemon Status:
#  corosync: active/enabled
#  pacemaker: active/enabled
#  pcsd: active/enabled

#The output should be somewhat similar to the one described above. If not, check the configuration again. Change the boot order of resources.

pcs constraint order start dlm-clone then clvmd-clone

#Adding dlm-clone clvmd-clone (kind: Mandatory) (Options: first-action=start then-action=start)

pcs constraint colocation add clvmd-clone with dlm-clone

#With these resources created, configured and organized, now configure the shared storage between the two virtual machines (vm).

#Stop the cluster vm2.cluster

#pcs cluster stop

#Build logical volumes on the first virtual machine (mv1)

pvcreate /dev/xvdb1

vgcreate fileserver /dev/xvdb1

lvcreate --name r0 --size 9,9G fileserver

#If you want to see the status of these volumes

[root@vm1 ~]# pvs

[root@vm1 ~]# vgs

[root@vm1 ~]# lvs

#Restart the Cluster on the mvs / vms / secondary servers (vm2), and stop the first one (vm1), and repeat.

#[root@vm2 ~]#

#pcs cluster start

#[root@vm1 ~]# 

pcs cluster stop

#[root@vm2 ~]# 

#pvcreate /dev/xvdb1

#vgcreate fileserver /dev/xvdb1

#lvcreate --name r0 --size 9,9G fileserver

#Check the status of these volumes

[root@vm2 ~]# pvs

[root@vm2 ~]# vgs

[root@vm2 ~]# lvs

#Now let's activate our DRBD and put it in dual-primary mode. In both nodes (vms)

#[root@vm1 ~]# 

drbdadm create-md r0  #1º

drbdadm up r0         #2º

drbdadm primary r0    #3º

drbdadm adjust r0     #4º

watch cat /proc/drbd  #5º



#Mount the gfs2fs file system on the created volumes (ON ALL SERVERS (VMS)

#[root@vm1 ~]# 
mkfs.gfs2 -j3 -p lock_dlm -t mycluster:gfs2fs /dev/drbd0

mkfs.gfs2 -j3 -p lock_dlm -t mycluster:gfs2fs /dev/fileserver/r0

#/dev/fileserver/r0 is a symbolic link to /dev/dm-2
#This will destroy any data on /dev/dm-2
#Are you sure you want to proceed? [y/n] y
#Discarding device contents (may take a while on large devices): Done
#Adding journals: Done 
#Building resource groups: Done   
#Creating quota file: Done
#Writing superblock and syncing: Done
#Device:                    /dev/fileserver/r0
#Block size:                4096
#Device size:               9,90 GB (2595840 blocks)
#Filesystem size:           9,90 GB (2595836 blocks)
#ournals:                  3
#Journal size:              32MB
#Resource groups:           43
#Locking protocol:          "lock_dlm"
#Lock table:                "mycluster:gfs2fs"
#UUID:                      5438d7f8-a5cc-4264-b9af-78ee8b98598b
#
#Where
# -t clustername: fsname: is used to specify the name of the lock table
# -j nn: specifies how many journals (nodes) are used
# -J: allows you to specify the journal size. if not specified, the jounal will have a standard size of 128 MB. The minimum size is 8 MB (NOT recommended)
#In the command, clustername must be the name of the pacemaker cluster, as I used mycluster, which is the name of my cluster.
#The return of the command should be something similar to the one described above, if this does not happen, there are likely to be configuration errors.

#Manually create the mount point on all nodes (mvs) in the cluster.
#[root@vm1 ~]#

mkdir /clusterfs

#Before creating the GFS2 resource, manually validate that the ‘lvcluster’ file system is working properly.

#In master (server/vm) do:

mount /dev/drbd0 /clusterfs/

#In secondary (vms/servers) do:

#mount | grep clusterfs

#If no results are returned, mount the partition on the other nodes (vms) as well and create this new resource.

#root@vm1 ~]# 

pcs resource create gfs2fs Filesystem device="/dev/drbd0" directory="/clusterfs" fstype=gfs2 options=noatime op monitor interval=10s on-fail=fence clone interleave=true

#Assumed agent name 'ocf:heartbeat:Filesystem' (deduced from 'Filesystem')

#Check the status of the service that was created and see if it is active and running, see if it is in the expected status.

pcs status

#Cluster name: mycluster
#Stack: corosync
#Current DC: vm2.cluster (version 1.1.19-8.el7_6.4-c3c624ea3d) - partition with quorum
#Last updated: Thu Sep  5 11:17:00 2019
#Last change: Thu Sep  5 11:16:49 2019 by root via cibadmin on vm1.cluster

#2 nodes configured
#8 resources configured

#Online: [ vm1.cluster vm2.cluster ] e etc

#The result of these commands should be something similar to the output shown above. Therefore, our gfs2fs service starts automatically on all of our nodes (vms) in the cluster.
#Now organize the resource startup order for GFS2 and CLVMD, so that, after a node restarts, services are started in the correct order, otherwise,
#they will fail to start

pcs constraint order start clvmd-clone then gfs2fs-clone
#Adding clvmd-clone gfs2fs-clone (kind: Mandatory) (Options: first-action=start then-action=start)

pcs constraint colocation add gfs2fs-clone with clvmd-clone

#Now, since our feature / service is running correctly. Create a file on the first node (vm1).

#[root@vm1 ~]#

cd /clusterfs

touch file

#Now check that the files are replicated in real time to the second node (vm2).
#[root@vm2 ~]#
#cd /clusterfs
#ls