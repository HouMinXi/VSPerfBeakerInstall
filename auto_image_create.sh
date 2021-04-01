#!/bin/bash

rm -f /var/lib/libvirt/images/*
ls -al /var/lib/libvirt/images/

unset VM_NAME

virsh list --all --name | xargs -I {} virsh destroy  {}
virsh list --all --name | xargs -I {} virsh undefine {}

#url_76=http://download.eng.pek2.redhat.com/rhel-7/rel-eng/latest-RHEL-7.6/compose/Server/x86_64/os/
#url_77=http://download.eng.pek2.redhat.com/rhel-7/rel-eng/latest-RHEL-7.7/compose/Server/x86_64/os/
#url_78=http://download.eng.pek2.redhat.com/rhel-7/rel-eng/latest-RHEL-7.8/compose/Server/x86_64/os/
#url_80=http://download.eng.pek2.redhat.com/rhel-8/rel-eng/RHEL-8/latest-RHEL-8.0/compose/BaseOS/x86_64/os/
#url_81=http://download.eng.pek2.redhat.com/rhel-8/rel-eng/RHEL-8/latest-RHEL-8.1/compose/BaseOS/x86_64/os/
#url_82=http://download.eng.pek2.redhat.com/rhel-8/rel-eng/RHEL-8/latest-RHEL-8.2/compose/BaseOS/x86_64/os/
#url_79=http://download.eng.pek2.redhat.com/rhel-7/nightly/latest-RHEL-7.9/compose/Server/x86_64/os/
#url_83=http://download.eng.bos.redhat.com/rhel-8/rel-eng/RHEL-8/latest-RHEL-8.3/compose/BaseOS/x86_64/os/

#enable viommu and install specify rt-kernel
# sh vmcreate.sh -c $(( ${i%Q} * 2 + 1 )) -l $url -d -v -k -u -r http://download-node-02.eng.bos.redhat.com/brewroot/packages/dpdk/19.11.3/1.el8/x86_64/dpdk-19.11.3-1.el8.x86_64.rpm -k -b kernel-rt-
#4.18.0-240.15.1.rt7.69.el8_3 -e
url_84=http://download-node-02.eng.bos.redhat.com/nightly/rhel-8/RHEL-8/latest-RHEL-8.4.0/compose/BaseOS/x86_64/os/

for url in $url_84
do
    for i in 1Q 2Q 4Q
    do
        for j in viommu noviommu
        do
            echo $url
            rhel_ver=`echo ${url%/} | awk -F '/' '{print $(NF-4)}' | awk -F '-' '{print $NF}'`
            vm_name="rhel${rhel_ver}-vsperf"-${i}-${j}
            export VM_NAME=${vm_name}
            echo $VM_NAME
            if [[ $j == viommu ]]
            then
                cmd="sh vmcreate.sh -c $(( ${i%Q} * 2 + 1 )) -l $url -d -v -k -u -r http://download-node-02.eng.bos.redhat.com/brewroot/packages/dpdk/20.11/1.el8fdb.3/x86_64
/dpdk-20.11-1.el8fdb.3.x86_64.rpm  -e -b kernel-rt-4.18.0-240.15.1.rt7.69.el8_3"
            else
                cmd="sh vmcreate.sh -c $(( ${i%Q} * 2 + 1 )) -l $url -d -k -u -r http://download-node-02.eng.bos.redhat.com/brewroot/packages/dpdk/20.11/1.el8fdb.3/x86_64/dp
dk-20.11-1.el8fdb.3.x86_64.rpm -e -b kernel-rt-4.18.0-240.15.1.rt7.69.el8_3"

            echo $cmd
            eval $cmd
        done
    done
done

unset VM_NAME



