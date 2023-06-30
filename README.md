# HyperVCluser-VMCreator
Script that automates the creation of Hyper-V Virtual Machines on a Hyper-V Cluster

2 Lines that need to be edited are :

- 82 - Specify the location of your Template VHDX

- 146 - Specify the name of your Hyper-V Virtual Switch Adapter.

*Current Promtps*

Basic VM details
- Enter Machine Hostname
- Enter the generation of the virtual machine (1 or 2)
- Enter the number of virtual CPUs
- Enter the amount of RAM (Numeic Value only in GB)
- Enter the number of virtual network adapters
- Enter the VLAN for network adapter X
- Lists Available cluster storage volumes with their respective free space.
- Enter the number of the Failover Cluster volume for the virtual machine

OS Disk
- Do you want to apply the Windows Server 2019 template? (yes/no) (If yes it copies a template VHDX from the location set on line 85)

If Yes to template:
- The Template Disk Size is XXXGB. Do you want to extend the virtual hard disk size? (yes/no)
- Enter the new hard disk size (Numeic Value only in GB)

If No to the template:
- Enter the hard disk size (Numeic Value only in GB)

Data Disk
- Do you want to another Drive for Data? (yes/no)
- Enter the hard disk size (Numeic Value only in GB)

Host Node
- Prompt for which Node the VM should be started on.

Launch Console
- Do you want to connect to the VM console? (yes/no)
