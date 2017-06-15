#!/bin/bash

MASTER_NAME=$1
echo $MASTER_NAME

# disable selinux
    sed -i 's/enforcing/disabled/g' /etc/selinux/config
    setenforce permissive

# Shares
SHARE_HOMES=/home
SHARE_APPS=/apps
SHARE_SHARED=/cm/shared

mkdir -p /cm/local
mkdir -p $SHARE_HOMES; chmod 0000 $SHARE_HOMES
mkdir -p $SHARE_APPS;  chmod 0000 $SHARE_APPS
mkdir -p $SHARE_SHARED;chmod 0000 $SHARE_SHARED

# User
HPC_USER=hpcuser
HPC_UID=7007
HPC_GROUP=hpc
HPC_GID=7007

mount_nfs()
{

	yum -y install nfs-utils nfs-utils-lib
	
	showmount -e ${MASTER_NAME}
	mount -t nfs ${MASTER_NAME}:${SHARE_APPS} ${SHARE_APPS}
        mount -t nfs ${MASTER_NAME}:${SHARE_HOMES} ${SHARE_HOMES}
	mount -t nfs ${MASTER_NAME}:${SHARE_SHARED} ${SHARE_SHARED}
	
	echo "${MASTER_NAME}:${SHARE_HOMES} ${SHARE_HOMES} nfs defaults,nofail  0 0" >> /etc/fstab
        echo "${MASTER_NAME}:${SHARE_APPS} ${SHARE_APPS} nfs defaults,nofail  0 0" >> /etc/fstab
        echo "${MASTER_NAME}:${SHARE_SHARED} ${SHARE_SHARED} nfs defaults,nofail  0 0" >> /etc/fstab

}

setup_user()
{  
   
    groupadd -g $HPC_GID $HPC_GROUP

    # Don't require password for HPC user sudo
    echo "$HPC_USER ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
    
    # Disable tty requirement for sudo
    sed -i 's/^Defaults[ ]*requiretty/# Defaults requiretty/g' /etc/sudoers

    useradd -c "HPC User" -g $HPC_GROUP -u $HPC_UID $HPC_USER

}



# Downloads and installs PBS Pro OSS on the node.
# Starts the PBS Pro control daemon on the master node and
# the mom agent on worker nodes.
#
install_pbspro()
{
 
	yum install -y libXt-devel libXext


    wget -O /mnt/CentOS_7.zip  http://wpc.23a7.iotacdn.net/8023A7/origin2/rl/PBS-Open/CentOS_7.zip
    unzip /mnt/CentOS_7.zip -d /mnt
       
    


		yum install -y hwloc-devel expat-devel tcl-devel expat


	    rpm -ivh --nodeps /mnt/CentOS_7/pbspro-execution-14.1.0-13.1.x86_64.rpm

        cat > /etc/pbs.conf <<-EOF
	PBS_SERVER=$MASTER_HOSTNAME
	PBS_START_SERVER=0
	PBS_START_SCHED=0
	PBS_START_COMM=0
	PBS_START_MOM=1
	PBS_EXEC=/opt/pbs
	PBS_HOME=/cm/shared/var/spool/pbs
	PBS_CORE_LIMIT=unlimited
	PBS_SCP=/bin/scp
	EOF

	echo '$clienthost '$MASTER_NAME > /var/spool/pbs/mom_priv/config
        /etc/init.d/pbs start

		# setup the self register script
		cp pbs_selfregister.sh /etc/init.d/pbs_selfregister
		chmod +x /etc/init.d/pbs_selfregister
		chown root /etc/init.d/pbs_selfregister
		chkconfig --add pbs_selfregister

		# if queue name is set update the self register script
		if [ -n "$QNAME" ]; then
			sed -i '/qname=/ s/=.*/='$QNAME'/' /etc/init.d/pbs_selfregister
		fi

		# register node
		/etc/init.d/pbs_selfregister start



    echo 'export PATH=/opt/pbs/bin:$PATH' >> /etc/profile.d/pbs.sh
    echo 'export PATH=/opt/pbs/sbin:$PATH' >> /etc/profile.d/pbs.sh

    cd ..
}


mount_nfs
setup_user


# install_pbspro

exit 0
