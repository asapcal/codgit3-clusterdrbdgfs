# Script para config de cluster DRBD com gfs e CLVM

Este tutorial nada mais é do que um compilado com algumas modificações de diversos tutoriais pesquisados na internet, listarei abaixo alguns deles:
- http://www.voleg.info/Linux_RedHat6_cluster_drbd_GFS2.html
- https://www.tecmint.com/setup-drbd-storage-replication-on-centos-7/
- https://clusterlabs.org/pacemaker/doc/en-US/Pacemaker/1.1/html/Clusters_from_Scratch/_initialize_drbd.html
- https://www.learnitguide.net/2016/07/how-to-install-and-configure-drbd-on-linux.html
- https://www.atlantic.net/cloud-hosting/how-to-drbd-replication-configuration/
- https://clusterlabs.org/pacemaker/doc/en-US/Pacemaker/1.1/html/Clusters_from_Scratch/_initialize_drbd.html
- https://www.golinuxcloud.com/ste-by-step-configure-high-availability-cluster-centos-7/
- https://www.justinsilver.com/technology/linux/dual-primary-drbd-centos-6-gfs2-pacemaker/
- https://www.ibm.com/developerworks/community/blogs/mhhaque/entry/how_to_configure_red_hat_cluster_with_fencing_of_two_kvm_guests_running_on_two_ibm_powerkvm_hosts?lang=en
.. e etc.

Foram utilizadas duas maquinas virtuais com dois discos rígidos idênticos de 50,3Gb e juntamente com isso duas partições de 10,7Gb.
IPC: Estas duas maquinas virtuais pertencem a mesma rede e é importante salientar que estas duas partições são idênticas!!

Já quanto ao sistema operacional, usamos a versão mais atual do CentOS, que nos momento que esta documentação esta sendo escrita é a 7.Juntamente com os programas Pacemaker,
Corosync, Stonith, Fence, DLM, CLVM, gfs2fs e etc, todos em suas versoes mais atuais e estaveis lançadas até o momento. 
Lembrando que toda esta configuração bem como seus resultados serão feitos via terminal, e os prints de cada configuração serão colocados neste arquivo. Antes de começarmos 
colocarei os prints de como meu disco rígido esta organizado.Iniciando a configuração, primeiramente precisamos deixar essas duas maquinas prontas para receber a configuração
inicial, e o primeiro passo é definirmos os seus IP’s como estáticos, para criarmos uma conexão ssh estável entre elas. 
Acessaremos as maquinas via SSH para este tutorial. Caso você não saiba usar o SSH veja este tutorial:(http://rberaldo.com.br/usando-o-ssh/), usaremos somente SSH.
