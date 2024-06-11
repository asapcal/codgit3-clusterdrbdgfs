Cluster HA DRBD(Dual-primary),Pacemaker/Corosync/Stonith-fence_xvm, DLM/CLVM e gfs2fs
=====================================================================================
Tutorial and some modifications of several researches: 

## 1. Links and tutorials used 
- http://www.voleg.info/Linux_RedHat6_cluster_drbd_GFS2.html
- https://www.tecmint.com/setup-drbd-storage-replication-on-centos-7/
- https://clusterlabs.org/pacemaker/doc/en-US/Pacemaker/1.1/html/Clusters_from_Scratch/_initialize_drbd.html
- https://www.learnitguide.net/2016/07/how-to-install-and-configure-drbd-on-linux.html
- https://www.atlantic.net/cloud-hosting/how-to-drbd-replication-configuration/
- https://clusterlabs.org/pacemaker/doc/en-US/Pacemaker/1.1/html/Clusters_from_Scratch/_initialize_drbd.html
- https://www.golinuxcloud.com/ste-by-step-configure-high-availability-cluster-centos-7/
- https://www.justinsilver.com/technology/linux/dual-primary-drbd-centos-6-gfs2-pacemaker/
- https://www.ibm.com/developerworks/community/blogs/mhhaque/entry/how_to_configure_red_hat_cluster_with_fencing_of_two_kvm_guests_running_on_two_ibm_powerkvm_hosts?lang=en
- https://www.osradar.com/installing-and-configuring-a-drbd-cluster-in-centos-7/
- http://www.tadeubernacchi.com.br/desabilitando-o-firewalld-centos-7/
- https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/html/selinux_users_and_administrators_guide/sect-Security-Enhanced_Linux-Working_with_SELinux-Changing_SELinux_Modes#sect-Security-Enhanced_Linux-Enabling_and_Disabling_SELinux-Permissive_Mode
- https://www.learnitguide.net/2016/07/how-to-install-and-configure-drbd-on-linux.html
- https://www.atlantic.net/cloud-hosting/how-to-drbd-replication-configuration/
- https://www.tecmint.com/setup-drbd-storage-replication-on-centos-7/
- https://major.io/2011/02/13/dual-primary-drbd-with-ocfs2/
- https://www.golinuxcloud.com/configure-gfs2-setup-cluster-linux-rhel-centos-7/
- https://clusterlabs.org/pacemaker/doc/en-US/Pacemaker/1.1/html/Clusters_from_Scratch/ch09.html
- https://www.lisenet.com/2016/o2cb-cluster-with-dual-primary-drbd-and-ocfs2-on-oracle-linux-7/
- http://www.voleg.info/stretch-nfs-cluster-centos-drbd-gfs2.html
- http://jensd.be/186/linux/use-drbd-in-a-cluster-with-corosync-and-pacemaker-on-centos-7
- https://icicimov.github.io/blog/high-availability/Clustering-with-Pacemaker-DRBD-and-GFS2-on-Bare-Metal-servers-in-SoftLayer/
- https://www.justinsilver.com/technology/linux/dual-primary-drbd-centos-6-gfs2-pacemaker/
- http://www.tadeubernacchi.com.br/desabilitando-o-firewalld-centos-7/
- http://tutoriaisgnulinux.com/2013/06/08/_redhat-cluster-configurando-fence_virt/
- https://www.ntppool.org/zone/br
- https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/html/selinux_users_and_administrators_guide/sect-Security-Enhanced_Linux-Working_with_SELinux-Changing_SELinux_Modes
- https://www.golinuxcloud.com/ste-by-step-configure-high-availability-cluster-centos-7/,https://clusterlabs.org/pacemaker/doc/en-US/Pacemaker/1.1/html/Clusters_from_Scratch/_install_the_cluster_software.html

Similar scheme to that presented in the link: 
- https://icicimov.github.io/blog/high-availability/Clustering-with-Pacemaker-DRBD-and-GFS2-on-Bare-Metal-servers-in-SoftLayer/

## 2.Configuration / disks / programs / tools 
2 mvs / vms of 50.3Gb with partitions of 10.7Gb each. On the same network using nothing but SHELL / BASH / SSH. OS and resources using:  CentOS 7, Pacemaker, Corosync, Stonith, Fence, DLM, CLVM, gfs2fs. 

## 3. Network settings 
Starting the configuration, the first step is to define your IP’s as static, to create a stable ssh connection between them.
If you don't know how to use SSH see this tutorial :(http://rberaldo.com.br/usando-o-ssh/).Ex:
```
hostname:vm1 - ip:10.255.255.xxx → ssh vm1@10.255.255.xxx
```
Reminder, always keep your system up to date!
Change the IP of these machines via file to static mode .Ex:
```
$ sudo vi /etc/sysconfig/network-scripts/ifcfg-eth0
```
Now, with the network cards already configured, it is necessary to redefine the name of the virtual machines in the file: / etc / hosts.
IPC: There are several ways, for example: hostnamectl set-hostname “vm0.cluster”. Where “vm0.cluster” is mv's new full hostname.

## 4.Configuration steps
- Step 1: Preparation of the machine regarding the network and name, which I have just shown. Together with the installation of DRBD and its configuration in mode (DUAL-PRIMARY) .And then the installation and configuration of the cluster managers, COROSYNC and PACEMAKER.
- Step 2: Installation of CLUSTER PCS and the configuration of this cluster with Fence and Stonith using the agent (fence_xvm) which is aimed at mvs / vms, if you are not using mvs / vms, look for your specific agent. DLM, CLVM (LVM). The first one deals with blocks as the name suggests, because if one of the cluster nodes goes down, it is our duty to keep the other cluster node clean. (LVM / CLVM) are nothing more than logical volume managers. If multiple nodes in the cluster require simultaneous read / write access to LVM volumes on an active / active system, you must use CLVMD.
CLVMD provides a system for coordinating activation and changes in LVM volumes on nodes in a cluster simultaneously.
The CLVMD clustered blocking service provides protection for LVM metadata, as multiple nodes in the cluster interact with the volumes and make changes to their layout.
- Step 3: Creation of the last resources for the completion of the project. Among them we have the PV (Phisical Volume), the VG (Volume Group) and the LV (logical volume). On which the DRBD will be mounted, and for that we will change the initial configuration made in the resource file ("r0.res"). And formatting the DRBD-simulated "disk" with a GFS2FS file system and mounting a partition on it. It is worth mentioning that this last step should only be done on the (m) / vm / server / primary node (because the change will be replicated automatically).
IPC: The assembly and configuration of the DRBD was done at the beginning by my preference, it can be done at the end when it is necessary to implement it in the code. 
## 5. Installation of DRBD facilities
Add the package repository for DRBD operation (On all servers / mvs / vms / nodes!): 
```
$ sudo rpm -ivh http://www.elrepo.org/elrepo-release-7.0-2.el7.elrepo.noarch.rpm
$ sudo rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-elrepo.org
$ sudo yum install drbd kmod-drbd
$ sudo yum install drbd90-utils.x86_64 drbd84-utils-sysvinit.x86_64 kmod-drbd84.x86_64”
```
This last command should, after a question that must be answered with (y), display a “Done” answer.  

## 6. Preparing disks and partitions (Replicate on all servers / mvs / vms / nodes!)
Now the DRBD is already installed, prepare the disk and the partitions for the resource configuration file (no need to worry about the module identification, it will be loaded at the next boot and if the configuration files are correct, everything will work). 
```
$ sudo cfdisk /dev /nomedapartição 
```
Pay attention to the name of your disk / partition which can be different depending on the linux distribution being used ("In my case: xvdb").
After activating this command, select the option, NEW (to create a new partition), and then the option SAVE, to confirm the creation of this new disk partition. Change the output of the command: "lsblk" to this state, you can use the command: fdisk as well.Ex:
```
[user@hostname ~]$ lsblk
NAME                           MAJ:MIN  RM    SIZE  RO TYPE  MOUNTPOINT
sr0                             11:0     1   1024M   0 rom   
xvda                              8:0    0     50G   0 disk  
├─xvda1                           8:1    0      1G   0 part  /boot
└─xvda2                           8:2    0     49G   0 part  
  ├─vg_centos65-lv_root (dm-0) 253:0     0   45,1G   0 lvm   /
  └─vg_centos65-lv_swap (dm-1) 253:1     0    3,9G   0 lvm   [SWAP]
xvdb                            132:16   0     10G   0 disk  
└─xvdb1                         132:17   0     10G   0 part
```

## 7. SELinux permissive or disabled (Replicate on all servers / mvs / vms / nodes!)
Or change the SELinux state to permissive, with the commands below. 
```
$ sudo setenforce permissive
$ sudo sestatus
SELinux status:                                      enabled
SELinuxfs mount:                          /sys/fs/selinux
SELinux root directory:                  /etc/selinux
Loaded policy name:                            targeted
Current mode:                                     permissive
Mode from config file:                        enforcing
Policy MLS status:                                enabled
Policy deny_unknown status:              allowed
Max kernel policy version:                      31
```
Or disable SElinux permanently with the command string. 
```
Disabling SELinux permanently
Edit the /etc/selinux/config file, run:
$ sudo vi /etc/selinux/config
Set SELINUX to disabled:
SELINUX=disabled
Save and close the file in vi/vim. Reboot the Linux system:
$ sudo reboot
```
To learn more visit the link:  https://www.cyberciti.biz/faq/disable-selinux-on-centos-7-rhel-7-fedora-linux/

## 8. Reviewing all configuration so far. Firewall (Replicate on all servers / mvs / vms / nodes!)
Firewall configuration
Consult your firewall documentation to learn how to open / allow ports. You will need the following ports open for your cluster to function properly.
Ports: 
| # | Component   | Protocol    | Port              |
|---|-------------|-------------|-------------------|
| 1 | DRBD        |     TCP     | 7788              |
| 2 | Corosync    |     UDP     | 5404, 5405        |
| 3 | GFS2        |     TCP     | 2224, 3121, 21064 |
```
$ sudo iptables -I INPUT -p tcp --dport 2224 -j ACCEPT   ---   iptables -nL | grep 2224
$ sudo iptables -I INPUT -p tcp --dport 3121 -j ACCEPT   ---   iptables -nL | grep 3121
$ sudo iptables -I INPUT -p tcp --dport 21064 -j ACCEPT ---   iptables -nL | grep 21064
$ sudo iptables -I INPUT -p udp --dport 5404 -j ACCEPT  ---   iptables -nL | grep 5404
$ sudo iptables -I INPUT -p udp --dport 5405 -j ACCEPT  ---   iptables -nL | grep 5405
```
Also enable port 7788 on the firewall, on both machines so as not to suffer future validation errors, do the commands below on all nodes of the project. 
```
$ sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="10.255.255.231" port port="7788" protocol="tcp" accept'
$ sudo firewall-cmd reload
```

## 9. Install DRBD: (Replicate on all servers / mvs / vms / nodes!) 
```
$ sudo rpm -ivh http://www.elrepo.org/elrepo-release-7.0-2.el7.elrepo.noarch.rpm
$ lsmod | grep -i drbd
```
Check that all hosts have their names and ips properly configured.
```
$ cat /etc/hostname
$ cat /etc/hosts
```

## 10. Configuration files (Replicate on all servers / mvs / vms / nodes!)
Edit the file “/etc/drbd.d/global_common.conf” and change the option “usage-count from yes to no” and save the file on all DRBD nodes (mvs).
And on all nodes / vms / etc in the cluster create the file, “r0.res” inside the directory, “/etc/drbd.d/”.
Move the loop file that should be in the directory: “/etc/init.d/loop-for-drbd” To keep the dual-primary mode (in my case) after the reboot. 

## 11. Script execution (According to your environment)
With these files in their respective places, start configuring the DRBD for use in (DUAL-PRIMARY) mode.
Do not activate DRBD in this step, so that nothing goes wrong when activating the cluster.
The instructions must be implemented in all mvs / nodes and so on. Although, this guide is only shown running on a set of 2 virtualized machines with VMware on the same network.
* The mvs / vms / secondary nodes commands are commented within the script, read on to make changes according to your scenario. * 

![That's all folks](https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcRjTP8kaxaOmV1_V4FYGLwJ27se8-5WUl-IyQ&usqp=CAU)
