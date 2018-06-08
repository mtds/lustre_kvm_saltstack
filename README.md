# Lustre Installation on KVM based VMs

## Introduction

The following tutorial aim to show how to create a small virtualized environment (based on Libvirt/KVM) to deploy a [Lustre filesystem](https://wiki.hpdd.intel.com/display/PUB/HPDD+Wiki+Front+Page), with the help of **SaltStack**. More info about Lustre can be found in the 'Lustre Resources' section at the end of this document (it is assumed that you already have a basic knowledge of Lustre and its components).

## Prerequisites

Use the [VM Tools](https://github.com/vpenso/vm-tools) to create, deploy and interact with the (KVM based) Virtual Machines:

* [Virtual Machine images](https://github.com/vpenso/vm-tools/blob/master/docs/image.md)
* [Creates new VM instances](https://github.com/vpenso/vm-tools/blob/master/docs/instance.md)
* [Provide a workflow on how to interact with the VMs instances](https://github.com/vpenso/vm-tools/blob/master/docs/workflow.md)

An additional tutorial on creating a small **SLURM cluster** on VMs and managing it with Saltstack is available [here](https://github.com/vpenso/saltstack-slurm-example).

## Overview
 
Component  | Description                   | Cf.
-----------|-------------------------------|-----------------------
CentOS     | Linux Operating System        | <https://www.centos.org/>
Lustre     | HPC Parallel File System      | <http://lustre.org>
SaltStack  | Infrastructure orchestration  | <https://saltstack.com/>

Version of the components used in this tutorial:
* Linux Distribution: CentOS 7.5
* Lustre version: 2.10.4
* SaltStack: 2018.3.0

## Lustre deployment

For the sake of simplicity in this scenario, all the OSTs are formatted using **ldiskfs**. The Lustre FS cluster is composed in the following way:

* 4 total nodes
    * 1 MDS (Lustre Metadata Server): this VM will combine the MDT (Metadata Target) and the MGS (Management Service).
    * 2 OSSs (Lustre Object Storage Servers): lxfs01 and lxfs02 which will mount one OST each. 
    * 1 Client which will mount the Lustre FS (a combination of OST0000 and OST0001).

Future version of this document will possibly include:
* A second MDS node as failover.
* ZFS pools to be used by Lustre OSS.

## Create a CentOS VM

The following command will be used to create a VM which will serve as a base for creating all the other nodes. Note that *two* disks in QCOW2 format will be created, one for the OS and the second one which will be used by the MDS and the OSS nodes.

```bash
>>> virt-install --name centos7 --ram 2048 --os-type linux --virt-type kvm --network bridge=nbr0 \
            --disk path=disk.img,size=15,format=qcow2,sparse=true,bus=virtio \
            --disk path=disk1.img,size=2,format=qcow2,sparse=true,bus=virtio \
            --location http://mirror.centos.org/centos-7/7/os/x86_64/ --graphics none --console pty,target_type=serial \
            --noreboot --initrd-inject=$VM_TOOLS/var/centos/7/kickstart.cfg --extra-args 'console=ttyS0,115200n8 serial inst.repo=http://mirror.centos.org/centos-7/7/os/x86_64/ inst.text inst.ks=file:/kickstart.cfg'
```

For more details about this operation, please refer to the ['Image'](https://github.com/vpenso/vm-tools/blob/master/docs/image.md) documentation of the **vm-tools**.

Once the VM is up and running, include the [SaltStack package repository][spr] into the **centos7** virtual machine:

[spr]: https://docs.saltstack.com/en/latest/topics/installation/rhel.html

```bash
>>> cat /etc/yum.repos.d/salt.repo
[saltstack-repo]
name=SaltStack repo for Red Hat Enterprise Linux $releasever
baseurl=https://repo.saltstack.com/yum/redhat/$releasever/$basearch/latest
enabled=1
gpgcheck=1
gpgkey=https://repo.saltstack.com/yum/redhat/$releasever/$basearch/latest/SALTSTACK-GPG-KEY.pub
       https://repo.saltstack.com/yum/redhat/$releasever/$basearch/latest/base/RPM-GPG-KEY-CentOS-7
```

Just to be as much as up to date as possible, just launch an ``yum -y update`` before you shutdown this VM.


## Create the VMs

These virtual machines are created  with [vm-tools](https://github.com/vpenso/vm-tools).

The shell script ↴ [source_me.sh](source_me.sh) adds the tool-chain in this repository to your shell environment:

```bash
# load the environment
>>> source source_me.sh
NODES=lxcm01,lxmds01,lxfs0[1,2],lxb001
```

**NOTE**: the ``$NODES`` environment variable will influence some of the shell aliases which comes with the **vm-tools**. In the following example, the new VMs which will be spawned are exactly those that are defined by this environment variable.

```bash
# start new VM instances using `centos7` as source image
>>> vn s centos7
# clean up everything and start from scratch (only if you don't need these VMs anymore).
>>> vn r
```


## VM tasks distribution

Node         | Description
-------------|-----------------------
lxcm01       | SaltStack Master
lxmds01      | Lustre Metadata Server
lxfs0[1,2]   | Lustre OSS (file server)
lxb001       | Lustre Client


## SaltStack Deployment

Install Saltstack on all nodes (cf. [Salt configuration](https://docs.saltstack.com/en/latest/ref/configuration/index.html)):

```bash
# install the SaltStack master
>>> vm ex lxcm01 -r '
  yum install -y salt-master;
  firewall-cmd --permanent --zone=public --add-port=4505-4506/tcp;
  firewall-cmd --reload;
  systemctl enable --now salt-master && systemctl status salt-master
'
# install the SaltStack minions on all nodes
>>> vn ex '
  yum install -y salt-minion;
  echo "master: 10.1.1.7" > /etc/salt/minion;
  systemctl enable --now salt-minion && systemctl status salt-minion
'
```


## SaltStack Configuration

Sync the Salt configuration to the master:

* [srv/salt/](srv/salt/) - The **state tree** includes all SLS (SaLt State file) representing the state in which all nodes should be
* [etc/salt/master](etc/salt/master) - Salt master configuration (`file_roots` defines to location of the state tree)
* [srv/salt/top.sls](srv/salt/top.sls) - Maps nodes to SLS configuration files (cf. [top file](https://docs.saltstack.com/en/latest/ref/states/top.html))

```bash
# upload the salt-master service configuration files
vm sy lxcm01 -r $SALTSTACK_EXAMPLE/etc/salt/master :/etc/salt/
# upload the salt configuration reposiotry
vm sy lxcm01 -r $SALTSTACK_EXAMPLE/srv/salt :/srv/
# accept all Salt minions
vm ex lxcm01 -r 'systemctl restart salt-master ; salt-key -A -y'
```

Commands to use on the **master**:

```bash
systemctl restart salt-master           # restart the master 
/var/log/salt/master                    # master log-file
salt-key -A -y                          # accept all (unaccpeted) Salt minions
salt-key -d <minion>                    # remove a minion key
salt-key -a <minion>                    # add a single minion key
salt <target> test.ping                 # check if a minion repsonds
salt <target> state.apply               # configure a node
salt <target> state.apply <sls>         # limit configuration to a single SLS file
salt <target> cmd.run <command> ...     # execute a shell command on nodes
salt-run jobs.active                    # list active jobs
salt-run jobs.exit_success <jid>        # check if a job has finished
```

Commands used on a **minion**:

```bash
systemctl restart salt-minion           # restart minion
journalctl -f -u salt-minion            # read the minion log
salt-minion -l debug                    # start minion in forground
salt-call state.apply <sls>             # limit configuration to a single SLS file
salt-call -l debug state.apply          # debug minion states
```

## VMs Configuration

The following configuration steps will be performed through [SaltStack state files](https://docs.saltstack.com/en/latest/topics/tutorials/starting_states.html), provided in this repository.

### MDS

Configure `lxmds01` with:

| Node     | SLS                                               | Description                               |
|----------|---------------------------------------------------|-------------------------------------------|
| lxmds01  | [lustre_mds_oss.sls](srv/salt/lustre_mds_oss.sls) | Configure the Lustre Metadata server      |

```bash
# configure the MDS
>>> vm ex lxcm01 -r 'salt lxmds01* state.apply'
# reboot the MDS (once the Lustre packages are installed)
>>> vm ex lxcm01 -r 'salt lxmds01* cmd.run systemctl reboot'
# after reboot, install the Lustre userspace tools
>>> vm ex lxcm01 -r 'salt lxmds01* state.apply'
```

**NOTE**: Why run the ``state.apply`` twice?  The reason is related to the fact that the Lustre userspace tools has a strong dependency on the kernel running on the host: until there's a Lustre enabled kernel, the ``lustre.x86-64`` package cannot be installed.

Create and format the MGS/MDT file system:
```bash
# Note that the Lustre filesystem name is 'testfs'
>>> vm ex lxcm01 -r 'salt lxmds01* cmd.run mkfs.lustre --reformat --fsname=testfs --mdt --mgs /dev/vdb'
# Mount the filesystem
>>> vm ex lxcm01 -r 'salt lxmds01* cmd.run mount -t lustre /dev/vdb /lustre/testfs/mdt'
# Show mount info
>>> vm ex lxmds01 -r 'mount -t lustre'
/dev/vdb on /lustre/testfs/mdt type lustre (ro,context=system_u:object_r:tmp_t:s0)
```

Firewall issues:
```bash
# Enable traffic from the OSSs:
>>> vm ex lxmds01 -r 'firewall-cmd --zone=public --add-source=10.10.1.32'
>>> vm ex lxmds01 -r 'firewall-cmd --zone=public --add-source=10.10.1.33'
# Enable traffic from the client:
>>> vm ex lxmds01 -r 'firewall-cmd --zone=public --add-source=10.10.1.13'
# Apply FW rules permanently:
>>> vm ex lxmds01 -r 'firewall-cmd --runtime-to-permanent'
```

### OSS

Configure `lxfs0[1,2]` with:

| Node        | SLS                                               | Description                                     |
|-------------|---------------------------------------------------|-------------------------------------------------|
| lxfs0[1,2]  | [lustre_mds_oss.sls](srv/salt/lustre_mds_oss.sls) | Configure the Lustre Object Storage Server      |

```bash
# configure the OSSs
>>> vm ex lxcm01 -r 'salt lxfs0* state.apply'
# reboot the OSS (once the Lustre packages are installed)
>>> vm ex lxcm01 -r 'salt lxfs0* cmd.run systemctl reboot'
# after reboot, install the Lustre userspace tools
>>> vm ex lxcm01 -r 'salt lxfs0* state.apply'
```

Create and format the OSTs:

```bash
# lxfs01
>>>  vm ex lxcm01 -r 'salt lxfs01* cmd.run mkfs.lustre --reformat --fsname=testfs --ost --index=0 --mgsnode=lxmds01@tcp0 /dev/vdb'
# lxfs02
>>>  vm ex lxcm01 -r 'salt lxfs02* cmd.run mkfs.lustre --reformat --fsname=testfs --ost --index=1 --mgsnode=lxmds01@tcp0 /dev/vdb'
# Mount the OSTs
>>> vm ex lxcm01 -r 'salt lxfs0* cmd.run mount -t lustre /dev/vdb /lustre/OST'
# Show mount info
>>> vm ex lxfs01 -r 'mount -t lustre'
/dev/vdb on /lustre/OST type lustre (ro,context=system_u:object_r:tmp_t:s0)
```

Firewall issues:
```bash
# Enable traffic from OSS and MDS:
>>> vm ex lxfs01 -r 'firewall-cmd --zone=public --add-source=10.10.1.47'
>>> vm ex lxfs01 -r 'firewall-cmd --zone=public --add-source=10.10.1.33'
>>> vm ex lxfs02 -r 'firewall-cmd --zone=public --add-source=10.10.1.47'
>>> vm ex lxfs02 -r 'firewall-cmd --zone=public --add-source=10.10.1.32'
# Enable traffic from the client:
>>> vm ex lxfs01 -r 'firewall-cmd --zone=public --add-source=10.10.1.13'
>>> vm ex lxfs02 -r 'firewall-cmd --zone=public --add-source=10.10.1.13'
# Apply FW rules permanently:
>>> vm ex lxfs01 -r 'firewall-cmd --runtime-to-permanent'
>>> vm ex lxfs02 -r 'firewall-cmd --runtime-to-permanent'
```

*NOTE*: increase the ``--index`` parameter consistently whenever you add a new OST on additional OSS otherwise the size of the entire Lustre FS will not be the sum of all the OSTs available.

### Client

| Node      | SLS                                             | Description                      |
|-----------|-------------------------------------------------|----------------------------------|
| lxb001    | [lustre_client.sls](srv/salt/lustre_client.sls) | Configure the Lustre client      |

```bash
# configure the Lustre client
>>> vm ex lxcm01 -r 'salt lxb001* state.apply'
# reboot
>>> vm ex lxcm01 -r 'salt lxb001* cmd.run systemctl reboot'
```

**NOTE**: after reboot it would be necessary to verify if the ``lnet`` kernel module is properly loaded otherwise the Lustre FS **cannot be mounted**.

```bash
>>> vm ex lxb001 -r 'lsmod | grep lnet'
```

It should report a similar output:
```
lnet                  484580  6 mgc,osc,lustre,obdclass,ptlrpc,ksocklnd
libcfs                415815  12 fid,fld,lmv,mdc,lov,mgc,osc,lnet,lustre,obdclass,ptlrpc,ksocklnd
```

The SaltStack file for the client will took care to create a proper LNET configuration file under: ``/etc/modprobe.d/lnet.conf``.

Firewall issues:
```bash
>>> vm ex lxb001 -r 'firewall-cmd --zone=public --add-source=10.10.1.47'
>>> vm ex lxb001 -r 'firewall-cmd --zone=public --add-source=10.10.1.32'
>>> vm ex lxb001 -r 'firewall-cmd --zone=public --add-source=10.10.1.33'
# Apply FW rules permanently:
>>> vm ex lxb001 -r 'firewall-cmd --runtime-to-permanent'
```

Mount the filesystem:
```bash
>>> vm ex lxb001 -r 'mount -t lustre lxmds01@tcp0:/testfs /lustre/testfs'
>>> vm ex lxb001 -r 'mount -t lustre'
10.1.1.47@tcp:/testfs on /lustre/testfs type lustre (rw,seclabel,lazystatfs)
```

In case the ``mount`` operation did not succeed, it is higly likely there's a firewall and/or a network issue. In this case, ``dmesg -kT`` on the Lustre client reports something similar to the following error message:
```
[...]
[Tue Jun  5 17:20:02 2018] Lustre: 883:0:(client.c:2114:ptlrpc_expire_one_request()) @@@ Request sent has failed due to network error: [sent 1528211990/real 1528211990]  req@ffff880034da8000 x1600707912823280/t0(0) o250->MGC10.1.1.47@tcp@10.1.1.47@tcp:26/25 lens 520/544 e 0 to 1 dl 1528211995 ref 1 fl Rpc:eXN/0/ffffffff rc 0/-1
```

Shows Lustre disk space usage (unprivileged users can also run this command):
```bash
>>> vm ex lxb001 'lfs df -h'
UUID                       bytes        Used   Available Use% Mounted on
testfs-MDT0000_UUID         1.1G        7.2M        1.0G   1% /lustre/testfs[MDT:0]
testfs-OST0000_UUID         1.8G       25.2M        1.7G   1% /lustre/testfs[OST:0]
testfs-OST0001_UUID         1.8G       25.2M        1.7G   1% /lustre/testfs[OST:1]

filesystem_summary:         3.7G       50.3M        3.4G   1% /lustre/testfs
```


## I/O Test

Run an IOzone test on the Lustre filesystem mounted on the client:

```bash
>>> yum -y install iozone
>>> cd /lustre/testfs
>>> iozone -l 32 -O -i 0 -i 1 -i 2 -e -+n -r 4K -s 4G
```


## Lustre Resources

Official documentation from the **Lustre and Intel Wiki pages**:
* [Putting together a Lustre FS](https://wiki.hpdd.intel.com/display/PUB/Putting+together+a+Lustre+filesystem)
* [Components of a Lustre FS (MDT,MGS,OSS,OST,etc.)](https://wiki.hpdd.intel.com/display/PUB/Components+of+a+Lustre+filesystem)
* [Lustre Networking overview](http://wiki.lustre.org/Lustre_Networking_(LNET)_Overview)
* [Lustre Benchmarking](http://wiki.lustre.org/Category:Benchmarking)
* [Lustre deployment on KVM](http://wiki.lustre.org/KVM_Quick_Start_Guide)
* [Lustre deployment with Vagrant/Virtualbox](http://wiki.lustre.org/Create_a_Virtual_HPC_Storage_Cluster_with_Vagrant)
* [Managing Lustre as an HA service](http://wiki.lustre.org/Managing_Lustre_as_a_High_Availability_Service)

Long and detailed tutorials:
* [The Lustre Distributed Filesystem (LinuxJournal, Nov. 28/2011)](https://www.linuxjournal.com/content/lustre-distributed-filesystem)
* [Deploy Lustre on top of ZFS (includes: HW/network schema, Corosync config, etc.)](https://homerl.github.io/2015/11/06/Deploy%20Lustre%20and%20OpenZFS/)
* [Deploy Lustre 2.10 on Virtualbox (Github repo)](https://github.com/lrahmani/lustre-on-virtualbox)


## Lustre Support Matrix

* [Which version of Lustre is supported by which version of RHEL/CentOS (server/client)](https://wiki.hpdd.intel.com/display/PUB/Lustre+Support+Matrix)


## License

Copyright 2012-2018 Matteo Dessalvi

This is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

