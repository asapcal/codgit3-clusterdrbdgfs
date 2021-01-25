ClusterHA com DRBD(Dual-primary),Pacemaker/Corosync/Stonith-fence_xvm, DLM/CLVM e gfs2fs
========================================================================================

Tutorial com base em algumas modificações de diversas pesquisas nos links:

- http://www.voleg.info/Linux_RedHat6_cluster_drbd_GFS2.html
- https://www.tecmint.com/setup-drbd-storage-replication-on-centos-7/
-https://clusterlabs.org/pacemaker/doc/en-US/Pacemaker/1.1/html/Clusters_from_Scratch/_initialize_drbd.html
-https://www.learnitguide.net/2016/07/how-to-install-and-configure-drbd-on-linux.html
-https://www.atlantic.net/cloud-hosting/how-to-drbd-replication-configuration/
-https://clusterlabs.org/pacemaker/doc/en-US/Pacemaker/1.1/html/Clusters_from_Scratch/_initialize_drbd.html
-https://www.golinuxcloud.com/ste-by-step-configure-high-availability-cluster-centos-7/
-https://www.justinsilver.com/technology/linux/dual-primary-drbd-centos-6-gfs2-pacemaker/
-https://www.ibm.com/developerworks/community/blogs/mhhaque/entry/how_to_configure_red_hat_cluster_with_fencing_of_two_kvm_guests_running_on_two_ibm_powerkvm_hosts?lang=en
Esquema abaixo no link -https://icicimov.github.io/blog/high-availability/Clustering-with-Pacemaker-DRBD-and-GFS2-on-Bare-Metal-servers-in-SoftLayer/

## 1. Esquema 

------------  ------------             ------------  ------------
|  Service |  |  Service |             |  Service |  |  Service |
------------  ------------             ------------  ------------
     ||            ||                       ||            ||
--------------------------  cluster FS --------------------------
|          gfs2          |<- - - - - ->|          gfs2          |
-------------------------- replication --------------------------
|        drbd r0         |<- - - - - ->|         drbd r0        |
--------------------------             --------------------------
|        lv_vol          |     c       |         lv_vol         |
--------------------------     l       --------------------------
|   volume group vg1     |     u       |    volume group vg2    |
--------------------------     s       --------------------------
|     physical volume    |     t       |     physical volume    |
--------------------------     e       --------------------------
|          xvdb1         |     r       |          xvdb2         |
--------------------------             --------------------------
         server01                               server0x

## 2. Configuração dos "discos,partições,progs,ferramentas" usados:

Foi utilizado para o esquema, 2 mvs/vms de 50,3Gb com partições de 10,7Gb cada. Na mesma rede via SHELL/BASH/via SSH
CentOS 7, Pacemaker, Corosync, Stonith, Fence, DLM, CLVM, gfs2fs. 

## 3. Configuções de rede

Iniciando a configuração, primeiramente precisamos deixar essas duas maquinas prontas para receber a configuração inicial, e o primeiro passo é definirmos os seus IP’s como estáticos, para criarmos uma conexão ssh estável entre elas.

Acessaremos as maquinas apenas via SSH para este tutorial. Caso você não saiba usar o SSH veja este tutorial:(http://rberaldo.com.br/usando-o-ssh/):

Ex:

```
vm1 : 10.255.255.xxx → ssh vm1@10.255.255.xxx
```

Lembrete, mantenha sempre o seu sistema atualizado, um exemplo de comando que pode te ajudar é o: yum update .

Mudar o IP destas maquinas precisaremos acessar o arquivo: vi /etc/sysconfig/network-scripts/ifcfg-eth0 . E mudar para o modo para estático.

Agora, com as placas de rede já configuradas, precisa-se redefinir o nome das maquinas virtuais no arquivo: /etc /hosts.

IPC: Exitem varias formas, por exemplo: hostnamectl set-hostname “lalala.pc.uou”. Em que “lalala.pc.uou” é o novo hostname completo da minha maquina. Em caso de duvida, recomendo o link: -https://www.hostinger.com.br/tutoriais/como-mudar-hostname-ubuntu/

Começar de vez a configuração. Primeiramente vou mostrar um layout de como o projeto foi desenvolvido e a forma que achei mas fácil pra implementar a configuração.

## 4. Etapas da configuração

Etapa 1: de inicio nos temos a preparação da maquina quanto a rede e nome, que acabei de mostrar. Juntamente com a instalação do DRBD e a sua configuração em modo (DUAL-PRIMARY).E depois a instalação e configuração dos gerenciadores de cluster, o COROSYNC e o PACEMAKER. 

Etapa 2: prosseguindo  para etapa 2 temos as configurações para o funcionamento do CLUSTER PCS bem como a configuração deste cluster em conjunto com o Fence e Stonith utilizando um de seus agentes de segurança o (fence_xvm) que é voltado a maquinas virtuais, se você não esta utilizando maquinas virtuais ou virtualizadas, procure por seu agente especifico. Deve-se ter muito cuidado com a configuração deste recurso, por ele sera um apoio aos futuros recursos em todos os nós do cluster.
Dando continuidade nos configuraremos os recursos de DLM, CLVM(LVM). O primeiro é uma parte obrigatória do cluster e tem a função de gerenciar os blocos assim como o nome sugere, porque, se um dos nós do cluster cair, é nosso dever manter o outo nó do cluster limpo.
E o (LVM/CLVM) nada mais são que gerenciadores de volume lógico. Se vários nós do cluster exigirem acesso simultâneo de leitura / gravação a volumes LVM em um sistema ativo / ativo, você deverá usar o CLVMD.
O CLVMD fornece um sistema para coordenar a ativação e as alterações nos volumes de LVM nos nós de um cluster simultaneamente.
O serviço de bloqueio em cluster da CLVMD fornece proteção aos metadados do LVM, pois vários nós do cluster interagem com os volumes e fazem alterações em seu layout.

Etapa 3: Mesta etapa utilizaremos todos os recursos  e criaremos os ultimos recursos para a conclusão do projeto. Dentre eles temos o PV(Phisical Volume), o VG(Volume Group) e o LV(logical volume). No qual será montado o DRBD, e para isso mudaremos a configuração inical feita no arquivo de recurso que nele está. E agora por fim, como o ultimo passo da ultima etapa vou formatar o disco simulado pelo DRBD com um sistema de arquivos especial  chamado de GFS2FS e montando uma partição nele. Vale a pena mencionar que esta ultima etapa só deve ser feita em um dos servers(por que a mudança será replicada automaticamente).
IPC: A montagem e a configuração do DRBD foi feita no inicio por preferência minha, ela pode ser feita no final quando for necessaria sua implementação no código.

## 5. Instalação das dependencias DRBD

Adicionar o repositorio dos pacotes para o funcionamento do DRBD(Em todos servers/mvs/vms/nós!):

```
$ sudo rpm -ivh http://www.elrepo.org/elrepo-release-7.0-2.el7.elrepo.noarch.rpm
$ sudo rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-elrepo.org
$ sudo yum install drbd kmod-drbd
$ sudo yum install drbd90-utils.x86_64 drbd84-utils-sysvinit.x86_64 kmod-drbd84.x86_64”
```

Este ultimo comando deverá, depois de uma pergunta que deve ser respondida com (y), exibir uma resposta do tipo “Concluído”. 

## 6. Preparando os discos e partições(Replicar em todos servers/mvs/vms/nós!)

Agora o DRBD já está instalado, prepare o disco e as partiçoes para o arquivo de configuração do recurso (não precisa se preocupar com a identificação do modulo o mesmo será carregado no próximo boot e se os arquivos de configurção estiverem corretos, tudo funcionará).

```
$ sudo cfdisk /dev /nomedapartição 
```
Atente-se ao nome de seu disco/partição que pode ser diferente dependendo da distribuição linux que esta sendo usada("No meu caso era xvdb").
Depois de acionar esse comado, selecione a opção, NOVA (para criar uma nova partição), e depois a opção GRAVAR, para confirmar a criação dessa nova partição em disco. Mude a saida do comando: “lsblk” para este estado, pode se usar o comado: fdisk também.

## 7. SELinux permissivo ou desativado(Replicar em todos servers/mvs/vms/nós!)

Ou mude o estado do SELinux para permissivo, com os comandos abaixo.

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

Ou desative o SElinux permanentemente com a sequencia de comandos.

```
Disabling SELinux permanently
Edit the /etc/selinux/config file, run:
$ sudo vi /etc/selinux/config
Set SELINUX to disabled:
SELINUX=disabled
Save and close the file in vi/vim. Reboot the Linux system:
$ sudo reboot
```
Para saber mais acesse o link: https://www.cyberciti.biz/faq/disable-selinux-on-centos-7-rhel-7-fedora-linux/

Revisando toda configuração até aqui.

## 8. Revisando toda configuração até aqui.Firewall(Replicar em todos servers/mvs/vms/nós!)

 Configuração de Firewall

Consulte a documentação do seu firewall para saber como abrir / permitir portas. Você precisará das seguintes portas abertas para seu cluster funcionar corretamente. 
Portas:

Component   --------------------------------  Protocol   ----------------------------           Port
DRBD        --------------------------------    TCP      ----------------------------           7788
Corosync    --------------------------------    UDP      ----------------------------        5404, 5405
GFS2        --------------------------------    TCP      ----------------------------    2224, 3121, 21064
```
$ iptables -I INPUT -p tcp --dport 2224 -j ACCEPT   ---   iptables -nL | grep 2224
$ iptables -I INPUT -p tcp --dport 3121 -j ACCEPT   ---   iptables -nL | grep 3121
$ iptables -I INPUT -p tcp --dport 21064 -j ACCEPT ---   iptables -nL | grep 21064
$ iptables -I INPUT -p udp --dport 5404 -j ACCEPT  ---   iptables -nL | grep 5404
$ iptables -I INPUT -p udp --dport 5405 -j ACCEPT  ---   iptables -nL | grep 5405
```

Tambem habilite a porta 7788 no firewall, de ambas as maquinas para não sofrer futuros erros de validação, faça os comandos abaixos em todos os nós do projeto.

```
$ sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="10.255.255.231" port port="7788" protocol="tcp" accept'
$ sudo firewall-cmd reload
```

Os links usados até aqui, e os que ainda serão usados. 

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


## 9. Instale o DRBD:(Replicar em todos servers/mvs/vms/nós!)

'$ sudo rpm -ivh http://www.elrepo.org/elrepo-release-7.0-2.el7.elrepo.noarch.rpm

'$ lsmod | grep -i drbd

Verifique se todos os hosts estão com os nomes e ips devidamente configurados.

'$ cat /etc/hostname

'$ cat /etc/hosts

## 10. Arquivos de configuração(Replicar em todos servers/mvs/vms/nós!)

Edite o arquivo “/etc/drbd.d/global_common.conf” e modifique a opção “usage-count de yes para no” e salve o arquivo, em todos os nós(mvs) do DRBD.
E nos dois nós do cluster crie o arquivo, “r0.res” dentro do diretório, “/etc/drbd.d/”.
Mova o arquivo de loop que deve ficar oo diretório: “/etc/init.d/loop-for-drbd” Para manter o modo dual-primary após o reboot.

## 11. Execução do script

Com esses arquivos em seus respectivos lugares, inicia-se a configuração do DRBD para uso em modo (DUAL-PRIMARY).
Não ativaremos o DRBD nesta etapa, por isso atense-se a configuração para que nada dê errado no momento da ativação do esquema.
As instruções devem ser implementadas em todas as mvs/nós e etc. Embora, neste guia só seja mostrado rodando em um conjunto de 2 maquinas.

*Execute o script de cluster lendo antes para fazer a devidas modificações de acordo com seu cenário.*


## 12. That's all folks

![That's all folks](https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcRjTP8kaxaOmV1_V4FYGLwJ27se8-5WUl-IyQ&usqp=CAU)
