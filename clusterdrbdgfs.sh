#!/bin/sh
#
# Description: Startup script for clustredrbdgfs
#
# Copyright (C) 2029 - 2029 Asaph <asax.cal.97@gmail.com>
#
echo "Script para config de cluster DRBD com gfs e CLVM!"

#Este tutorial nada mais é do que um compilado com algumas modificações de diversos tutoriais pesquisados na internet, listarei abaixo alguns deles:

#- http://www.voleg.info/Linux_RedHat6_cluster_drbd_GFS2.html
#- https://www.tecmint.com/setup-drbd-storage-replication-on-centos-7/
#-https://clusterlabs.org/pacemaker/doc/en-US/Pacemaker/1.1/html/Clusters_from_Scratch/_initialize_drbd.html
#-https://www.learnitguide.net/2016/07/how-to-install-and-configure-drbd-on-linux.html
#-https://www.atlantic.net/cloud-hosting/how-to-drbd-replication-configuration/
#-https://clusterlabs.org/pacemaker/doc/en-US/Pacemaker/1.1/html/Clusters_from_Scratch/_initialize_drbd.html
#-https://www.golinuxcloud.com/ste-by-step-configure-high-availability-cluster-centos-7/
#-https://www.justinsilver.com/technology/linux/dual-primary-drbd-centos-6-gfs2-pacemaker/
#-https://www.ibm.com/developerworks/community/blogs/mhhaque/entry/how_to_configure_red_hat_cluster_with_fencing_of_two_kvm_guests_running_on_two_ibm_powerkvm_hosts?lang=en

#.. e muitos outros, conforme decorrermos citaremos mais links.

#Aqui esta uma representação quase gráfica do projeto com base no link
#-https://icicimov.github.io/blog/high-availability/Clustering-with-Pacemaker-DRBD-and-GFS2-on-Bare-Metal-servers-in-SoftLayer/


#+----------+  +----------+             +----------+  +----------+
#|  Service |  |  Service |             |  Service |  |  Service |
#+----------+  +----------+             +----------+  +----------+
#     ||            ||                       ||            ||
#+------------------------+  cluster FS +------------------------+
#|          gfs2          |<----------->|          gfs2          |
#+------------------------+ replication +------------------------+
#|        drbd r0         |<----------->|         drbd r0        |
#+------------------------+             +------------------------+
#|        lv_vol          |     c       |         lv_vol         |
#+------------------------+     l       +------------------------+
#|   volume group vg1     |     u       |    volume group vg1    |
#+------------------------+     s       +------------------------+
#|     physical volume    |     t       |     physical volume    |
#+------------------------+     e       +------------------------+
#|          xvdb1         |     r       |          xvdb1         |
#+------------------------+             +------------------------+
#         server01                               server02

#Configuração dos discos e das partições:

#Foram utilizadas duas maquinas virtuais virtuais com dois discos rígidos idênticos de 50,3Gb e juntamente com isso duas partições de 10,7Gb.
#IPC: Estas duas maquinas virtuais pertencem a mesma rede e é importante salientar que estas duas partições são idênticas!!
#Abaixo, encontram-se as saídas do comando lsblk em ambas maquinas virtuais.

#Já quanto ao sistema operacional, usamos a versão mais atual do CentOS, que nos momento que esta documentação esta sendo escrita é a 7.Juntamente com os programas Pacemaker,
#Corosync, Stonith, Fence, DLM, CLVM, gfs2fs e etc, todos em suas versoes mais atuais e estaveis lançadas até o momento. 
#Lembrando que toda esta configuração bem como seus resultados serão feitos via terminal, e os prints de cada configuração serão colocados neste arquivo. Antes de começarmos 
#colocarei os prints de como meu disco rígido esta organizado.Iniciando a configuração, primeiramente precisamos deixar essas duas maquinas prontas para receber a configuração
#inicial, e o primeiro passo é definirmos os seus IP’s como estáticos, para criarmos uma conexão ssh estável entre elas. 
#Acessaremos as maquinas via SSH para este tutorial. Caso você não saiba usar o SSH veja este tutorial:(http://rberaldo.com.br/usando-o-ssh/), usaremos somente SSH em nível 
#básico. Os ips das maquinas são:

#vm1 : 10.255.255.x → ssh cam@10.255.255.x
#vm2 : 10.255.255.x → ssh cam@10.255.255.x 

#Lembrete, mantenha sempre o seu sistema atualizado, um exemplo de comando que pode te ajudar é o: yum update .
#Para mudar o IP destas maquinas precisaremos acessar o arquivo: vi /etc/sysconfig/network-scripts/ifcfg-eth0 .
#E depois de acessar mude sua configuração para os seguintes estados:

#Neste caso, mudei o endereço IP's das mv1 e mv2 para: 10.255.255.x como modo para estático.

#Agora, com as placas de rede já configuradas, precisa-se redefinir o nome das maquinas virtuais no arquivo: /etc /hosts. Fiz isso com o comando: “hostname novonome”.
#Por exemplo: maquina1.drbdcluster

#IPC: Exitem varias formas, por exemplo: hostnamectl set-hostname “lalala.pc.uou”. Em que “lalala.pc.uou” é o novo hostname completo da minha maquina. Em caso de duvida,
#recomendo o link: -https://www.hostinger.com.br/tutoriais/como-mudar-hostname-ubuntu/
#Agora que a fase inicial da preparação terminou, vamos começar de vez a configuração. Primeiramente vou mostrar um layout de como o projeto foi desenvolvido por mim e a
#forma que achei mas comoda pra implementar a configuração. 
#Etapa 1: de inicio nos temos a preparação da maquina quanto a rede e nome, que acabei de mostrar. Juntamente com a instalação do DRBD e a sua configuração em modo
#(DUAL-PRIMARY).E depois a instalação e configuração dos gerenciadores de cluster, o COROSYNC e o PACEMAKER. 
#Etapa 2: prosseguindo  para etapa 2 temos as configurações para o funcionamento do CLUSTER PCS bem como a configuração deste cluster em conjunto com o Fence e Stonith
#utilizando um de seus agentes de segurança o (fence_xvm) que é voltado a maquinas virtuais, se você não esta utilizando maquinas virtuais ou virtualizadas, procure por seu
#agente especifico. Deve-se ter muito cuidado com a configuração deste recurso, por ele sera um apoio aos futuros recursos em todos os nós do cluster.
#Dando continuidade nos configuraremos os recursos de DLM, CLVM(LVM). O primeiro é uma parte obrigatória do cluster e tem a função de gerenciar os blocos assim como o nome
#sugere, porque, se um dos nós do cluster cair, é nosso dever manter o outo nó do cluster limpo.
#E o (LVM/CLVM) nada mais são que gerenciadores de volume lógico. Se vários nós do cluster exigirem acesso simultâneo de leitura / gravação a volumes LVM em um sistema ativo
#/ ativo, você deverá usar o CLVMD.
#O CLVMD fornece um sistema para coordenar a ativação e as alterações nos volumes de LVM nos nós de um cluster simultaneamente.
#O serviço de bloqueio em cluster da CLVMD fornece proteção aos metadados do LVM, pois vários nós do cluster interagem com os volumes e fazem alterações em seu layout.
#Etapa 3: Mesta etapa utilizaremos todos os recursos  e criaremos os ultimos recursos para a conclusão do projeto. Dentre eles temos o PV(Phisical Volume), o VG(Volume Group)
#e o LV(logical volume). No qual será montado o DRBD, e para isso mudaremos a configuração inical feita no arquivo de recurso que nele está. E agora por fim, como o ultimo
#passo da ultima etapa vou formatar o disco simulado pelo DRBD com um sistema de arquivos especial  chamado de GFS2FS e montando uma partição nele. Vale a pena mencionar que
#esta ultima etapa só deve ser feita em um dos servers(por que a mudança será replicada automaticamente).
#IPC: A montagem e a configuração do DRBD foi feita no inicio por preferência minha, ela pode ser feita no final quando for necessaria sua implementação no código.

#Adicionar o repositorio dos pacotes para o funcionamento do DRBD:(Nos dois servers)
rpm -ivh http://www.elrepo.org/elrepo-release-7.0-2.el7.elrepo.noarch.rpm

#Instalar o DRBD, depois de importar o repositório no qual ele se encontra usando os seguintes comandos.(nos dois servers)

rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-elrepo.org
yum install drbd kmod-drbd

#Instale também as dependencias abaixo com o comando: 
yum install drbd90-utils.x86_64 drbd84-utils-sysvinit.x86_64 kmod-drbd84.x86_64

#Este comando deverá, depois de uma pergunta que deve ser respondida com (y), exibir uma resposta do tipo “Concluído”.

#Agora o DRBD já está instalado, prepare o disco e as partiçoes para fazerem parte de meu arquivo de configuração do recurso (não precisa se preocupar com a identificação
#do modulo o mesmo será carregado no próximo boot e se os arquivos de configurção estiverem corretos, tudo funcionará). Faça isso nos dois servers usando o comando:

cfdisk /dev /xvdb 

#Atente-se ao nome de seu disco pode ser diferente dependendo da distribuição linux que esta sendo usada.

#Depois de acionar esse comado, selecione a opção, NOVA (para criar uma nova partição), e depois a opção GRAVAR, para confirmar a criação dessa nova partição em disco.
#Mude a saida do comando: “lsblk” para este estado.(Nos dois servers) pode se usar o comado: fdisk também.
#Agora. configure a utilização dos arquivos instalados junto com o pacote drdb. Acessando o arquivo: “ cat /etc/selinux/config ” e mudando o status de SELINUX para (disabled),
#no arquivo.

#Mude o estado do SELinux para permissivo, com os comandos abaixo.

setenforce permissive

#Pode se verificar se esta correto com:

sestatus

#Desative o SElinux permanentemente com a sequencia de comandos.

Disabling SELinux permanently
Edit the /etc/selinux/config file, run:
sudo vi /etc/selinux/config
Set SELINUX to disabled:
SELINUX=disabled
Save and close the file in vi/vim. Reboot the Linux system:
sudo reboot

#Para saber mais acesse o link: https://www.cyberciti.biz/faq/disable-selinux-on-centos-7-rhel-7-fedora-linux/

#Configuração de Firewall

#Consulte a documentação do seu firewall para saber como abrir / permitir portas. Você precisará das seguintes portas abertas para seu cluster funcionar corretamente. 
#Portas:
#Component  ----------------------------------  Protocol  -----------------------------------    Port
#DRBD       ----------------------------------    TCP     -----------------------------------    7788
#Corosync   ----------------------------------    UDP     -----------------------------------   5404, 5405
#GFS2       ----------------------------------    TCP     -----------------------------------   2224, 3121, 21064

iptables -I INPUT -p tcp --dport 2224 -j ACCEPT   ---   iptables -nL | grep 2224
iptables -I INPUT -p tcp --dport 3121 -j ACCEPT   ---   iptables -nL | grep 3121
iptables -I INPUT -p tcp --dport 21064 -j ACCEPT ---   iptables -nL | grep 21064
iptables -I INPUT -p udp --dport 5404 -j ACCEPT  ---   iptables -nL | grep 5404
iptables -I INPUT -p udp --dport 5405 -j ACCEPT  ---   iptables -nL | grep 5405

#Tambem habilite a porta 7788 no firewall, de ambas as maquinas para não sofrer futuros erros de validação, faça os comandos abaixos em todos os nós do projeto.

firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="10.255.255.x" port port="7788" protocol="tcp" accept'
firewall-cmd reload

#Os links usados até aqui, e os que ainda serão usados. 

# https://www.osradar.com/installing-and-configuring-a-drbd-cluster-in-centos-7/
# http://www.tadeubernacchi.com.br/desabilitando-o-firewalld-centos-7/ing_SELinux_Modes
# https://www.learnitguide.net/2016/07/how-to-install-and-configure-drbd-on-linux.html
# https://www.atlantic.net/cloud-hosting/how-to-drbd-replication-configuration/
# https://www.tecmint.com/setup-drbd-storage-replication-on-centos-7/
# https://major.io/2011/02/13/dual-primary-drbd-with-ocfs2/
# https://www.golinuxcloud.com/configure-gfs2-setup-cluster-linux-rhel-centos-7/
# https://clusterlabs.org/pacemaker/doc/en-US/Pacemaker/1.1/html/Clusters_from_Scratch/ch09.html
# https://www.lisenet.com/2016/o2cb-cluster-with-dual-primary-drbd-and-ocfs2-on-oracle-linux-7/
# http://www.voleg.info/stretch-nfs-cluster-centos-drbd-gfs2.html
# http://jensd.be/186/linux/use-drbd-in-a-cluster-with-corosync-and-pacemaker-on-centos-7
# https://icicimov.github.io/blog/high-availability/Clustering-with-Pacemaker-DRBD-and-GFS2-on-Bare-Metal-servers-in-SoftLayer/
# https://www.justinsilver.com/technology/linux/dual-primary-drbd-centos-6-gfs2-pacemaker/
# http://www.tadeubernacchi.com.br/desabilitando-o-firewalld-centos-7/
# http://tutoriaisgnulinux.com/2013/06/08/_redhat-cluster-configurando-fence_virt/
# https://www.ntppool.org/zone/br
# https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/html/selinux_users_and_administrators_guide/sect-Security-Enhanced_Linux-Working_with_SELinux-
# Changing_SELinux_Modes

#Enfim, o DRBD:

rpm -ivh http://www.elrepo.org/elrepo-release-7.0-2.el7.elrepo.noarch.rpm

lsmod | grep -i drbd

#Verifique se todos os hosts estão com os nomes e ips devidamente configurados.

#Edite o arquivo “/etc/drbd.d/global_common.conf” e modifique a opção “usage-count de yes para no” e salve o arquivo, em todos os nós(mvs) do DRBD.


#global {
#	usage-count no;
#}    
#
#E nos dois nós do cluster crie o arquivo, “r0.res” dentro do diretório, “/etc/drbd.d/”.
#
#
#resource r0 {
#        protocol C;
#
#        syncer {
#	  #rate 100M;
#		verify-alg sha1;
#        }
#        startup {
#                wfc-timeout 0;
#                # non-zero wfc-timeout can be dangerous
#                degr-wfc-timeout 120;
#                outdated-wfc-timeout 120;
#                become-primary-on both;
#        }
#        disk {
#                resync-rate
#               33M;
#                c-max-rate 110M;
#                c-min-rate 10M;
#                c-fill-target 16M;
#                #fencing resource-and-stonith;
#                no-disk-barrier;
#                no-disk-flushes;
#        }
#        net {
#                cram-hmac-alg sha1;
#                shared-secret "my-secret";
#                use-rle yes;
#                allow-two-primaries yes;
#                after-sb-0pri discard-zero-changes;
#                after-sb-1pri discard-secondary;
#                after-sb-2pri disconnect;
#        }
#        handlers {
#                fence-peer"/usr/lib/drbd/rhcs_fence";
#}
#        on vm1.cluster {
#                        device /dev/drbd0;
#                        disk /dev/fileserver/r0;
#                        address 10.255.255.x:7788;
#                        meta-disk internal;
#        }
#        on vm2.cluster {
#                        device /dev/drbd0;
#                        disk /dev/fileserver/r0;
#                        address 10.255.255.x:7788;
#                        meta-disk internal;
#        }
#}

#Já este arquivo deve ficar oo diretório: “/etc/init.d/loop-for-drbd” Para manter o modo dual-primary após o reboot.

##!/bin/sh
#
# Startup script for drbd loop device setup
#
# chkconfig: 2345 50 50
# description: Startup script for drbd loop device setup
#
### BEGIN INIT INFO
# Provides: drbdloop
# Required-Start:
# Required-Stop:
# Default-Start: 2 3 4 5
# Default-Stop: 0 1 6
# Short-Description: set up drbd loop devices
# Description: Startup script for drbd loop device setup
### END INIT INFO
 
#DRBD_FILEDATA_SRC="/drbd-loop.img"
#DRBD_FILEDATA_DEVICE="/dev/loop7"
#LOSETUP_CMD=/sbin/losetup
 
## Source function library
#. /etc/rc.d/init.d/functions 
 
#start () {
#  echo -n $"Setting up DRBD loop devices..."
#  $LOSETUP_CMD $DRBD_FILEDATA_DEVICE $DRBD_FILEDATA_SRC
#  echo
#}
# 
#stop() {
#  echo -n $"Tearing down DRBD loop devices..."
#  $LOSETUP_CMD -d $DRBD_FILEDATA_DEVICE
#  echo
#}
# 
#restart() {
#  stop
#  start
#}
# 
#case "$1" in
#  start)
#      start
#      RETVAL=$?
#    ;;
#  stop)
#      stop
#      RETVAL=$?
#    ;;
#  restart)
#      restart
#      RETVAL=$?
#    ;;
#  *)
#    echo $"Usage: $0 {start|stop}" 
#    exit 1
#esac
# 
#exit $RETVAL

#Com esses arquivos em seus respectivos lugares, inicia-se a configuração do DRBD para uso em modo (DUAL-PRIMARY).
#Não ativaremos o DRBD nesta etapa, por isso atense-se a configuração para que nada dê errado no momento da ativação do banco.
#Para para os próximos passos use tambem os links como apoio:  https://www.golinuxcloud.com/ste-by-step-configure-high-availability-cluster-centos-7/,
#https://clusterlabs.org/pacemaker/doc/en-US/Pacemaker/1.1/html/Clusters_from_Scratch/_install_the_cluster_software.html,  as instruções devem ser implementadas
#em todas as mvs/nós. Embora, neste guia só seja mostrado rodando o comando em uma só maquina.

#Proceda a instalação do corosync e pacemaker. Verifique se os hosts estão corretamente identificados no arquivo: “/etc/hosts”

#[root@n1drbd ~]# cat /etc/hosts
#127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
#::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
#novos nomes e ips
#10.255.255.x    vm1drbd.cluster vm1
#10.255.255.x    vm2drbd.cluster vm2

#Pare e desative o Network Manager em todos os pcs envolvidos.
#[vm1]
systemctl disable NetworkManager
#Removed symlink /etc/systemd/system/multi-user.target.wants/NetworkManager.service.
#Removed symlink /etc/systemd/system/dbus-org.freedesktop.NetworkManager.service.
#Removed symlink /etc/systemd/system/dbus-org.freedesktop.nm-dispatcher.service.
#Removed symlink /etc/systemd/system/network-online.target.wants/NetworkManager-wait-online.service.

#Configure o servidor NTP
#[vm2]
systemctl enable ntpd
Created symlink from /etc/systemd/system/multi-user.target.wants/ntpd.service to /usr/lib/systemd/system/ntpd.service.
#[vm2]
firewall-cmd --add-service=high-availability
#Warning: ALREADY_ENABLED: 'high-availability' already in 'public'
#success
#[vm2]
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

#[root@n1drbd ~]# iptables -nL | grep <porta>

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

[root@n1drbd ~]# sudo pcs cluster setup --force n1drbd n2drbd --name mycluster

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


pcs stonith create fence_n2 fence_xvm pcmk_host_list="vm2" port="n2drbd.camcluster"

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

mv fence_xvm.key /etc/cluster/fence_xvm.key

#Configure a chave para a utilização

fence_virtd -c

#Neste tutorial se fez a configuração padrão, somente aceitando sem modificações

pcs stonith create fence_n2drbd fence_xvm pcmk_host_list="n1drbd" port="n1drbd.camcluster"

pcs stonith create fence_n1drbd fence_xvm pcmk_host_list="n2drbd" port="n2drbd.camcluster"

#https://www.unixarena.com/2016/01/rhel7-configuring-gfs2-on-pacemakercorosync-cluster.html/

#Uma configuração alternativa, este link apresenta uma configuração mais alternativa e simples.

#Agora vamos ativar o recurso do agente fence e stonith. 

pcs cluster fence_xvm enable

pcs cluster fence_xvm enable

pcs property set no-quorum-pilocy=freeze

#Em todos os nos(mvs) do cluster. Aqui estaão somente os exemplos.

systemctl enable fence_virtd.service

systemctl start fence_virtd.service

firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="10.255.255.213" port port="1229" protocol="tcp" accept' 

firewall-cmd –reload

iptables -xnvL

pcs property set stonith-enabled=true

#Depois desta série de comandos o recurso de fence_xvm, stonith deverá startar. Para confirmar:

pcs status

#Cluster name: mycluster
#Stack: corosync
#Current DC: n2drbd.camcluster (version 1.1.19-8.el7_6.4-c3c624ea3d) - partition with quorum
#Last updated: Wed Sep  4 09:55:17 2019
#Last change: Wed Sep  4 08:54:31 2019 by root via cibadmin on n1drbd.camcluster

#2 nodes configured
#2 resources configured

#Online: [ n1drbd.camcluster n2drbd.camcluster ]

#Full list of resources:

# xvmfence_n1	(stonith:fence_xvm):	Started n1drbd.camcluster
# xvmfence_n2	(stonith:fence_xvm):	Started n2drbd.camcluster

#Daemon Status:
#  corosync: active/enabled
#  pacemaker: active/enabled
#  pcsd: active/enabled
  
pcs stonith show
  
# xvmfence_n1	(stonith:fence_xvm):	Started n1drbd.camcluster
# xvmfence_n2	(stonith:fence_xvm):	Started n2drbd.camcluster

#O resultado obtido deve ser algo próximo do descrito acima. Se não for, existe algo errado com a configuração feita, revise os passos até aqui,
#ou veja os links de apoio. De agora em diante, por mais que use outros sites e artigos para pesquisa, o tutorial segue principalmente o link:
#https://www.golinuxcloud.com/configure-gfs2-setup-cluster-linux-rhel-centos-7/  

#Agora instale os recursos de DLM e CLVM que ão pré-requisitos  para montagem do sistema de arquivos especial GFS2FS que também será instalado.(Nas duas maquinas)

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

#Online: [ n1drbd.camcluster n2drbd.camcluster ]

#Full list of resources:

# xvmfence_n1	(stonith:fence_xvm):	Started n1drbd.camcluster
# xvmfence_n2	(stonith:fence_xvm):	Started n2drbd.camcluster
# Clone Set: dlm-clone [dlm]
#     Started: [ n1drbd.camcluster n2drbd.camcluster ]
# Clone Set: clvmd-clone [clvmd]
#     Started: [ n1drbd.camcluster n2drbd.camcluster ]
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

pcs cluster stop

#Construa os volumes lógicos na primeira maquina virtual(mv1)

pvcreate /dev/xvdb1

vgcreate fileserver /dev/xvdb1

lvcreate --name r0 --size 9,9G fileserver

#Verifique o status destes volumes

[root@vm1 ~]# pvs

[root@vm1 ~]# vgs

[root@vm1 ~]# lvs

#Reinicie o Cluster na segunda maquina virtual(mv2), e pare o da primeira, e repita.

#[root@vm2 ~]#

pcs cluster start

#[root@vm1 ~]# 

pcs cluster stop

#[root@vm2 ~]# 

pvcreate /dev/xvdb1

vgcreate fileserver /dev/xvdb1

lvcreate --name r0 --size 9,9G fileserver

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

mount | grep clusterfs

#Se não retornar nenhum resultado, monte a partição também nos outros nós(vms) e crie este novo recurso.

#root@vm1 ~]# 

pcs resource create gfs2fs Filesystem device="/dev/drbd0" directory="/clusterfs" fstype=gfs2 options=noatime op monitor interval=10s on-fail=fence clone interleave=true

#Assumed agent name 'ocf:heartbeat:Filesystem' (deduced from 'Filesystem')

#Verifique o status do serviço que foi criado e veja se ele esta ativo e rodando, veja se ele esta com o status esperado.

pcs status

#Cluster name: mycluster
#Stack: corosync
#Current DC: n2drbd.camcluster (version 1.1.19-8.el7_6.4-c3c624ea3d) - partition with quorum
#Last updated: Thu Sep  5 11:17:00 2019
#Last change: Thu Sep  5 11:16:49 2019 by root via cibadmin on n1drbd.camcluster

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

cd /clusterfs

ls

 #OBS.: Verificar modificação manual de arquivos contidas no script!!!
