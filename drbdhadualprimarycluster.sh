#!/bin/sh
#
# Description: Startup script for clustredrbdgfs dual-primary mode!
#
# Copyright (C) 2029 - 2029 Asaph <asaph.lac.19@hotmail.com>
#
#Os comandos a serem executados nos "nós secundarios" estaão neste script em forma de comentario
#por favor leia o arquivo até p final e o Readme.md em caso de duvida.

#Instale do corosync e pacemaker. Verifique se os hosts estão corretamente identificados no arquivo: “/etc/hosts”

#[root@n1drbd ~]# cat /etc/hosts
#127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
#::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
#novos nomes e ips
#10.255.255.x    n1drbd.cluster vm1.cluster
#10.255.255.x    n2drbd.cluster vm2.cluster

#Pare/desative o Network Manager em todos os mvs/vms/servidores envolvidos.
#[vm1]
systemctl disable NetworkManager
#Removed symlink /etc/systemd/system/multi-user.target.wants/NetworkManager.service.
#Removed symlink /etc/systemd/system/dbus-org.freedesktop.NetworkManager.service.
#Removed symlink /etc/systemd/system/dbus-org.freedesktop.nm-dispatcher.service.
#Removed symlink /etc/systemd/system/network-online.target.wants/NetworkManager-wait-online.service.

#Configure o servidor NTP
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

#Instale os rpms(repositórios) necessários.

yum install epel-release -y


#Instale o pacemaker e os agentes de fence.

yum install pcs fence-agentes-all -y   
#ou 
yum install -y pacemaker pcs psmisc policycoreutils-python

#Adicione as novas regras e reinicie o firewall.

firewall-cmd --permanent --add-service=high-availability

#Verifique o status do selinux com. 

sestatus

#Verifique se as portas TCP/UDP que habilitamos durante a primeira etapa estão realmente habilitadas, conforme a configuração de firewall inicial.

#[root@vm1 ~]# iptables -nL | grep <porta>

#Se sim, configure a senha para o cluster:

echo password | passwd --stdin hacluster
#Mudando senha para o usuário hacluster.
#passwd: todos os tokens de autenticações foram atualizados com sucesso.

#Inicie o gerenciador de cluster do pacemaker.Em cada nó.
systemctl enable --now pcsd
#Created symlink from /etc/systemd/system/multi-user.target.wants/pcsd.service to /usr/lib/systemd/system/pcsd.service.

#Autentique o hacluster em qualquer um dos mv’s. Us:hacluster Se:pasword

pcs cluster auth vm1.cluster vm2.cluster

#Agora, no seu primeiro pc, vm, node, etc, digite e execute o comando abaixo para criar o cluster e starta-lo.

pcs cluster setup --start --name mycluster vm1.cluster vm2.cluster

#O recurso de cluster está ativo. Caso nunca tenha visto, aqui estão alguns comandos para ajudar no gerenciamento deste recurso. 

#[root@vm1 ~]# pcs

#[root@vm1 ~]# pcs status help
#[root@vm1 ~]# pacemakerd –features


#Habilite o recurso com o pacemaker e o corosync
#Faça a checagem do status do cluster

pcs cluster enable --all
#vm1.cluster: Cluster Enabled
#vm2.cluster: Cluster Enabled

pcs cluster status


#Verifique o quorum do cluster

#[vm1]
corosync-cfgtool -s

#Verifique o status em tempo real do cluster

#[vm1]
crm_mon  

#[vm1]
corosync-cmapctl | grep members

#IPC: Em caso de erro, revisar passos anteriores.

#Aqui abaixo estão alguns links de apoio para o caso haja erros de configurção ou sistema.
# https://bugs.launchpad.net/debian/+source/pcs/+bug/1640923
# https://shgonzalez.github.io/linux/ha/2017/10/02/How-to-solve-pacemaker-error.html
# https://oss.clusterlabs.org/pipermail/pacemaker/2014-September/022536.html
# https://github.com/ClusterLabs/pcs/issues/153
# http://fibrevillage.com/sysadmin/317-pacemaker-and-pcs-on-linux-example-cluster-creation-add-a-node-to-cluster-remove-a-node-from-a-cluster-desctroy-a-cluster

#Comando importante!

[root@vm1 ~]# sudo pcs cluster setup --force vm1.cluster vm2.cluster --name mycluster

#Configurando o fence e o stonith_xvm nos nós do cluster;

pcs stonith show

#Se todos os passos foram feitos corretamente não haverá dispositivos configurados com este recurso. A mensagem de retorno vai ser algo parecido com isso: 
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

#Verifique o pacemaker e corosync e veja seu status de cluster.

pcs cluster cib

ps axf

journalctl -b | grep -i error

systemctl status firewalld

pcs stonith show

yum install pcs fence-agents-all -y

pcs stonith list

systemctl status pcsd.service

#Criando o recurso fence/stonith nos nós do cluster.

pcs stonith create fence_n1 fence_xvm pcmk_host_list="vm1" port="vm1.cluster"


#pcs stonith create fence_n2 fence_xvm pcmk_host_list="vm2" port="vm2.cluster"

pcs stonith show

#Instale os pacotes faltosos nas maquinas(Execute este comado nas duas maquinas)

yum -y install fence-agents-all fence-agents-virsh fence-virt pacemaker-remotepcs fence-virtd resource-agents fence-virtd-libvirt fence-virtd-multicast

#Habilite o agente de fence para execução do recurso

systemctl start fence_virtd

systemctl enable fence_virtd

#Libere a porta tcp correspondente para execução do recurso de fence

firewall-cmd --add-port=1229/tcp --permanent 

#De agora em diante siga as instruções do site: https://www.ibm.com/developerworks/community/blogs/mhhaque/entry/how_to_configure_red_hat_cluster_with_fencing_of_two_kvm_guests
#_running_on_two_ibm_powerkvm_hosts?lang=en para criação da chave de fence.

#Para criação da chave xvm, faça:

#[root@vmcluster tmp]# 

dd if=/dev/urandom of=/etc/cluster/fence_xvm.key bs=4k count=1

#Copie o arquivo para todos os nós(mvs) via scp

sudo scp /etc/cluster/fence_xvm.key user@vm2.cluster:/tmp/

#No nó(mv) de destino copie a chave para o diretório desejado

#[root@vm2 tmp]# 

#mv fence_xvm.key /etc/cluster/fence_xvm.key

#Configure a chave para a utilização

#fence_virtd -c

#Neste tutorial se fez a configuração padrão, somente aceitando sem modificações

pcs stonith create fence_vm2 fence_xvm pcmk_host_list="vm1" port="vm1.cluster"

pcs stonith create fence_vm1 fence_xvm pcmk_host_list="vm2" port="vm2.cluster"

#https://www.unixarena.com/2016/01/rhel7-configuring-gfs2-on-pacemakercorosync-cluster.html/

#Uma configuração alternativa, este link apresenta uma configuração mais alternativa e simples.

#Agora vamos ativar o recurso do agente fence e stonith. 

pcs cluster fence_xvm enable

#pcs cluster fence_xvm enable

pcs property set no-quorum-pilocy=freeze

#Em todos os nos(mvs) do cluster. Aqui estaão somente os exemplos.

systemctl enable fence_virtd.service

systemctl start fence_virtd.service

firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="10.255.255.X" port port="1229" protocol="tcp" accept' 

firewall-cmd –reload

iptables -xnvL

pcs property set stonith-enabled=true

#Depois desta série de comandos o recurso de fence_xvm, stonith deverá startar. Para confirmar:

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

#DLM e CLVM e GFS2FS que também será instalado.(Nas duas maquinas)

yum install gfs2-utils lvm2-cluster dlm

# Antes de prosseguir é necessário que se mude ou confira a mudança nas seguinte propriedade do cluster:

pcs property set no-quorum-policy=freeze

#Verifique se o recurso dlm-clone[dlm] esta em modo ‘Started’ se não estiver verifique, pois deve haver algum erro na configuração.

#Configurando o recurso de CLVM.

grep locking_type /etc/lvm/lvm.conf | egrep -v '#' locking_type = 3

#..para alterar dinamicamente.

lvmconf –enable-cluster

systemctl disable lvm2-lvmetad --now

#Warning: Stopping lvm2-lvmetad.service, but it can still be activated by: lvm2-lvmetad.socket

#Crie o recurso clvm, e verifique se os recursos estarão ativos.

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

#A saída deverá ser de alguma forma parecida com a que está descrita acima. Caso não não esteja, verifique novamente a configuração. Mude a ordem de boot dos recursos.

pcs constraint order start dlm-clone then clvmd-clone

#Adding dlm-clone clvmd-clone (kind: Mandatory) (Options: first-action=start then-action=start)

pcs constraint colocation add clvmd-clone with dlm-clone

#Com estes recursos criados, configurados e organizados, configure agora o armazenamento compartilhado entre as duas maquinas virtuais(vm).

#Pare o cluster vm2.cluster

#pcs cluster stop

#Construa os volumes lógicos na primeira maquina virtual(mv1)

pvcreate /dev/xvdb1

vgcreate fileserver /dev/xvdb1

lvcreate --name r0 --size 9,9G fileserver

#Caso queira ver o status destes volumes

[root@vm1 ~]# pvs

[root@vm1 ~]# vgs

[root@vm1 ~]# lvs

#Reinicie o Cluster nas mvs/vms/servidos secundarios(vm2), e pare o da primeira(vm1), e repita.

#[root@vm2 ~]#

#pcs cluster start

#[root@vm1 ~]# 

pcs cluster stop

#[root@vm2 ~]# 

#pvcreate /dev/xvdb1

#vgcreate fileserver /dev/xvdb1

#lvcreate --name r0 --size 9,9G fileserver

#Verifique o status destes volumes

[root@vm2 ~]# pvs

[root@vm2 ~]# vgs

[root@vm2 ~]# lvs

#Agora vamos ativar o nosso DRBD e colocar em modo dual-primary.Nos dois nós(vms)

#[root@vm1 ~]# 

drbdadm create-md r0  #1º

drbdadm up r0         #2º

drbdadm primary r0    #3º

drbdadm adjust r0     #4º

watch cat /proc/drbd  #5º



#Monte o sistema de arquivos gfs2fs nos volumes criados (EM TODOS OS NÓS(VMS)

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
#Onde
#-t clustername: fsname: é usado para especificar o nome da tabela de bloqueio
#-j nn: especifica quantos diários (nós) são usados
#-J: permite especificar o tamanho de journal. se não especificado, o jounal terá um tamanho padrão de 128 MB. O tamanho mínimo é 8 MB (NÃO recomendado)
#No comando, clustername deve ser o nome do cluster pacemaker, pois usei mycluster, que é o nome do meu cluster.
#O retorno do comando deve ser algo similar ao descrito acima, se isto não ocorrer, é provável que existam erros de configuração.

#Crie manualmente o ponto de montagem em todos os nós(mvs) do cluster.

#[root@vm1 ~]#

mkdir /clusterfs

#Antes de criar o recurso de GFS2 valide manualmente se o sistema de arquivos ‘lvcluster’ esta funcionando c de forma apropriada.

#No nó(vm)1 faça:

mount /dev/drbd0 /clusterfs/

#No nó(vm)2 faça:

#mount | grep clusterfs

#Se não retornar nenhum resultado, monte a partição também nos outros nós(vms) e crie este novo recurso.

#root@vm1 ~]# 

pcs resource create gfs2fs Filesystem device="/dev/drbd0" directory="/clusterfs" fstype=gfs2 options=noatime op monitor interval=10s on-fail=fence clone interleave=true

#Assumed agent name 'ocf:heartbeat:Filesystem' (deduced from 'Filesystem')

#Verifique o status do serviço que foi criado e veja se ele esta ativo e rodando, veja se ele esta com o status esperado.

pcs status

#Cluster name: mycluster
#Stack: corosync
#Current DC: vm2.cluster (version 1.1.19-8.el7_6.4-c3c624ea3d) - partition with quorum
#Last updated: Thu Sep  5 11:17:00 2019
#Last change: Thu Sep  5 11:16:49 2019 by root via cibadmin on vm1.cluster

#2 nodes configured
#8 resources configured

#Online: [ vm1.cluster vm2.cluster ] e etc

#O resultado destes comandos deve ser algo similar a saída mostrada acima. Portanto, nosso serviço gfs2fs é iniciado automaticamente em todos os nossos nós(vms) do cluster.
#Agora organize a ordem de inicialização do recurso para GFS2 e CLVMD, para que, após a reinicialização de um nó, os serviços sejam iniciados na ordem correta, caso contrário,
#eles falharão ao iniciar

pcs constraint order start clvmd-clone then gfs2fs-clone
#Adding clvmd-clone gfs2fs-clone (kind: Mandatory) (Options: first-action=start then-action=start)

pcs constraint colocation add gfs2fs-clone with clvmd-clone

#Agora, já que nosso recurso / serviço está sendo executado corretamente. Crie um arquivo no primeiro nó(vm1).

#[root@vm1 ~]#

cd /clusterfs

touch file

#Agora verifique que os arquivos são replicados em tempo real para o segundo nó(vm2).

#[root@vm2 ~]#

#cd /clusterfs

#ls

#OBS.: Verificar modificação manual de arquivos contidas no script!!!