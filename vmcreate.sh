#!/bin/bash

set -x
yum install -y virt-install libvirt virt-manager util-linux virt-viewer
systemctl start libvirtd

enforce_status=`getenforce`

setenforce permissive

#LOCATION="http://download-node-02.eng.bos.redhat.com/released/RHEL-7/7.3/Server/x86_64/os/"
#CPUS=3
#DEBUG="no"
#VIOMMU="NO"
#DPDK_BUILD="NO"
#DPDK_URL="http://download.eng.bos.redhat.com/brewroot/packages/dpdk/18.11/2.el7_6/x86_64/dpdk-18.11-2.el7_6.x86_64.rpm"
#DPDK_URL=""

progname=$0

function usage () {
   cat <<EOF
Usage: $progname [-c cpus] [-l url to compose] [-r dpdk package location for guest]  [-n name for disk filename]
[-b brew install kernel package] [-d debug output to screen ] [-v enable viommu] [-u Building upstream DPDK]
[-k enable rt kernel for guest]  [-e enable brew install]
EOF
   exit 0
}

while getopts c:l:r:n:b:dhvuke FLAG; do
   case $FLAG in

   c)  echo "Creating VM with $OPTARG cpus" 
       CPUS=$OPTARG
       ;;
   l)  echo "Using Location for VM install $OPTARG"
       LOCATION=$OPTARG
       ;;
   r)  echo "DPDK release verison $OPTARG"
       DPDK_URL=$OPTARG
       ;;
   n) echo "set $OPTARG name from disk filename"
      dist=$OPTARG
      ;;
   b) echo "install $OPTARG kernel version from brew"
       kernel_version=$OPTARG
      ;;
   d)  echo "debug enabled"
       DEBUG="yes"
      ;;
   h)  echo "found $opt" ; usage ;;
   v)  echo "VIOMMU is enabled"
       VIOMMU="yes";;
   u)  echo "Building upstream DPDK"
       DPDK_BUILD="yes";;
   k) echo "Enable rt kernel installation"
      RT_KERNEL="yes"
     ;;
   e) echo "enable brew installation"
     enable_brew="yes"
     ;;
   \?)  usage ;;
   esac
done

shift $(($OPTIND - 1))
CPUS=${CPUS:-"2"}
location=$LOCATION
VM_NAME=${VM_NAME:-"master"}
vm=${VM_NAME}
bridge=virbr0
master_image=${vm}.qcow2
image_path=/var/lib/libvirt/images/
DEBUG=${DEBUG:-"no"}
VIOMMU=${VIOMMU:-"no"}
dist=${dist:-"rhel82"}
RT_KERNEL=${RT_KERNEL:-"no"}
DPDK_BUILD=${DPDK_BUILD:-"no"}
enable_brew=${enable_brew:-"no"}

if [[ ${location: -1} == "/" ]]
then
    location=${location: :-1}
fi

#echo $DPDK_URL
temp_str=$(basename $DPDK_URL)
DPDK_TOOL_URL=$(dirname $DPDK_URL)/${temp_str/dpdk/dpdk-tools}
# fix can't grep dpdk20 veriosn,http://download-node-02.eng.bos.redhat.com/brewroot/packages/dpdk/20.11/1.el8fdb.3/x86_64/dpdk-20.11-1.el8fdb.3.x86_64.rpm
# DPDK_VERSION=`echo $temp_str | grep -oP "[1-9]+\.[1-9]+\-[1-9]+" | sed -n 's/\.//p'`
DPDK_VERSION=`echo $temp_str | grep -oP "\d+\.\d+\-\d+" | sed -n 's/\.//p'`
echo "DPDK VERISON IS "$DPDK_VERSION

extra1="ks=file:/${dist}-vm.ks"
extra2="console=ttyS0,115200"

master_exists=`virsh list --all | awk '{print $2}' | grep master`
if [ -z $master_exists ]; then
    master_exists='None'
fi

if [ $master_exists == "master" ]; then
    virsh destroy $vm
    virsh undefine $vm
fi

echo deleting master image
/bin/rm -f $image_path/$master_image

#rhel_version=`echo $location | awk -F '/' '{print $(NF-3)}' | awk -F '-' '{print $1}' | tr -d '.'`
#fix this rhel7 and rhel8 location different use regex get version info 
#rhel_version=`echo $location | grep -oP "\/RHEL-\d+\.\d+|\/\d+\.\d+|\/latest-RHEL-\d+\.\d+" | tr -d '\.\/\-[a-zA-Z]'`
# fix can't install stable kernel. i.g http://download-01.eng.brq.redhat.com/rhel-8/rel-eng/RHEL-8/latest-RHEL-8/compose/BaseOS/x86_64/os/
compose_link=`sed "s/compose\/.*/COMPOSE_ID/g" <<< "$location"`
echo $compose_link
curl -I $compose_link
rhel_version=`curl -s $compose_link | grep -oP "RHEL-\d+\.\d+" | tr -d '\.\/\-[a-zA-Z]'`
if (( $rhel_version >= 80 ))
then
    base_repo='repo --name="beaker-BaseOS" --baseurl='$location
    app_repo='repo --name="beaker-AppStream" --baseurl='${location/BaseOS/AppStream}
    highavail_repo='repo --name="beaker-HighAvailability" --baseurl='${location/BaseOS/HighAvailability}
    nfv_repo='repo --name="beaker-NFV" --baseurl='${location/BaseOS/NFV}
    storage_repo='repo --name="beaker-ResilientStorage" --baseurl='${location/BaseOS/ResilientStorage}
    rt_repo='repo --name="beaker-RT" --baseurl='${location/BaseOS/RT}
else
    base_repo='#'
    app_repo='#'
    highavail_repo='#'
    nfv_repo='#'
    storage_repo='#'
    rt_repo='#'
fi

cat << KS_CFG > $dist-vm.ks
# System authorization information
auth --enableshadow --passalgo=sha512

# Use network installation
url --url=$location

# Use text mode install
text
#graphical
$base_repo
$app_repo
$highavail_repo
$nfv_repo
$storage_repo
$rt_repo

# Run the Setup Agent on first boot
#firstboot --enable
firstboot --disabled
ignoredisk --only-use=vda
# Keyboard layouts
keyboard --vckeymap=us --xlayouts='us'
# System language
lang en_US.UTF-8

# Network information
#network  --bootproto=dhcp --device=eth0 --ipv6=auto --activate
network  --bootproto=dhcp --ipv6=auto --activate

# Root password
rootpw  redhat

# Do not configure the X Window System
skipx

# System timezone
timezone US/Eastern --isUtc --ntpservers=10.16.31.254,clock.util.phx2.redhat.com,clock02.util.phx2.redhat.com

# System bootloader configuration
bootloader --location=mbr --timeout=5 --append="crashkernel=auto rhgb quiet console=ttyS0,115200"

# Partition clearing information
autopart --type=plain
clearpart --all --initlabel --drives=vda
zerombr

#firewall and selinux config
firewall --enabled
#selinux --permissive
selinux --enforcing


%packages --ignoremissing
@base
@core
@network-tools
%end

%post --logfile=/dev/console --interpreter=/usr/bin/bash

cat >/etc/yum.repos.d/beaker-Server-optional.repo <<REPO
[beaker-Server-optional]
name=beaker-Server-optional
baseurl=$location
enabled=1
gpgcheck=0
skip_if_unavailable=1
REPO


if (( $rhel_version >= 80 ))
then

touch /etc/yum.repos.d/rhel8.repo

cat > /etc/yum.repos.d/rhel8.repo << REPO
[RHEL-8-BaseOS]
name=RHEL-8-BaseOS
baseurl=$location
enabled=1
gpgcheck=0
skip_if_unavailable=1

[RHEL-8-AppStream]
name=RHEL-8-AppStream
baseurl=${location/BaseOS/AppStream}
enabled=1
gpgcheck=0
skip_if_unavailable=1

[RHEL-8-Highavail]
name=RHEL-8-buildroot
baseurl=${location/BaseOS/HighAvailability}
enabled=1
gpgcheck=0
skip_if_unavailable=1

[RHEL-8-Storage]
name=RHEL-8-Storage
baseurl=${location/BaseOS/ResilientStorage}
enabled=1
gpgcheck=0
skip_if_unavailable=1

[RHEL-8-NFV]
name=RHEL-8-NFV
baseurl=${location/BaseOS/NFV}
enabled=1
gpgcheck=0
skip_if_unavailable=1

[RHEL-8-RT]
name=RHEL-8-RT
baseurl=${location/BaseOS/RT}
enabled=1
gpgcheck=0
skip_if_unavailable=1"

REPO

fi

if [ $RT_KERNEL == 'yes' ] && [ $enable_brew == 'no' ]; then
  yum install -y kernel-rt*
fi

# if (( $rhel_version >= 80 ))
# then
#        yum -y install iperf3
#        ln -s /usr/bin/iperf3 /usr/bin/iperf
# else
#        yum -y install iperf
# fi

yum -y install iperf3
ln -s /usr/bin/iperf3 /usr/bin/iperf
if [ $RT_KERNEL == 'yes' ]; then
  yum install -y numactl-devel
  yum install -y libibverbs rdma-core tuna git nano ftp wget sysstat tuned-profiles* 1>/root/post_install.log 2>&1
else
  yum install -y kernel-devel numactl-devel
  yum install -y tuna git nano ftp wget sysstat libibverbs rdma-core tuned-profiles* 1>/root/post_install.log 2>&1
fi

yum install -y java-headless wget
wget http://hdn.corp.redhat.com/rhel7-csb-stage/RPMS/noarch/redhat-internal-cert-install-0.1-23.el7.csb.noarch.rpm
rpm -ivh http://hdn.corp.redhat.com/rhel7-csb-stage/RPMS/noarch/redhat-internal-cert-install-0.1-23.el7.csb.noarch.rpm
pushd /etc/yum.repos.d/
wget https://download.devel.redhat.com/rel-eng/RCMTOOLS/rcm-tools-rhel-8-baseos.repo
popd
yum install -y brewkoji

if [ $RT_KERNEL == 'yes' ] && [ $enable_brew == 'yes' ]; then
mkdir -p /root/$kernel_version
pushd /root/$kernel_version
brew download-build $kernel_version --arch x86_64 --arch noarch
yum localinstall -y ./kernel*
popd
fi


#echo -e "isolate_managed_irq=Y" >> /etc/tuned/cpu-partitioning-variables.conf
#echo -e "isolated_cores=0-$(($CPUS-1))" >> /etc/tuned/cpu-partitioning-variables.conf
#tuned-adm profile cpu-partitioning
#systemctl stop irqbalance.service
#chkconfig irqbalance off
#/usr/sbin/swapoff -a
#grub2-editenv - set kernelopts="$kernelopts mitigations=off"



#Here mkdir and download dpdk
if [ $DPDK_URL ]
then
  mkdir -p /root/dpdkrpms/$DPDK_VERSION
  wget $DPDK_URL -P /root/dpdkrpms/$DPDK_VERSION/.
  wget $DPDK_TOOL_URL -P /root/dpdkrpms/$DPDK_VERSION/.
fi

wget -P /root http://netqe-bj.usersys.redhat.com/share/mhou/vmscripts.tar.gz 1>/root/post_install.log 2>&1
tar zxvf /root/vmscripts.tar.gz -C /root 1>/root/post_install.log 2>&1


if [ "$VIOMMU" == "no" ] && [ "$DPDK_BUILD" == "no" ]; then
    /root/setup_rpms.sh 1>/root/post_install.log 2>&1
elif [ "$VIOMMU" == "yes" ] && [ "$DPDK_BUILD" == "no" ]; then
    /root/setup_rpms.sh -v 1>/root/post_install.log 2>&1
elif [ "$VIOMMU" == "no" ] && [ "$DPDK_BUILD" == "yes" ]; then
    /root/setup_rpms.sh -u 1>/root/post_install.log 2>&1
elif [ "$VIOMMU" == "yes" ] && [ "$DPDK_BUILD" == "yes" ]; then
    /root/setup_rpms.sh -u -v 1>/root/post_install.log 2>&1
fi

grubby --set-default-index=1

%end

shutdown


KS_CFG

virsh net-destroy default
virsh net-start default

echo creating new master image
qemu-img create -f qcow2 $image_path/$master_image 100G
echo undefining master xml
virsh list --all | grep master && virsh undefine master
echo calling virt-install

if [ $DEBUG == "yes" ]; then
virt-install --name=$vm\
    --virt-type=kvm\
    --disk path=$image_path/$master_image,format=qcow2,,size=8,bus=virtio\
    --vcpus=$CPUS\
    --ram=8192\
    --network bridge=$bridge\
    --extra-args="$extra1"\
    --initrd-inject `pwd`/$dist-vm.ks \
    --location=$location\
    --noreboot\
    --graphics none\
    --console pty\
    --extra-args "$extra2"
else
virt-install --name=$vm\
    --virt-type=kvm\
    --disk path=$image_path/$master_image,format=qcow2,,size=8,bus=virtio\
    --vcpus=$CPUS\
    --ram=8192\
    --network bridge=$bridge\
    --extra-args="$extra1"\
    --initrd-inject `pwd`/$dist-vm.ks \
    --location=$location\
    --noreboot\
    --graphics none\
    --console pty\
    --extra-args "$extra2" &> vminstaller.log
fi

rm $dist-vm.ks

setenforce $enforce_status
