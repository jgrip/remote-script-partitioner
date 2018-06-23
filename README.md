# Remote Script Partitioner

Partition Debian disks with PXE and shell script instead of complex
preseed templates.

Advanced partitioning of Debian boxes with preseed templates can be a
challange.  `remote-script-partitioner` makes it easy to bypass the
built-in templates and write a shell script to partition your disks.

This package disables `partman` in the Debian installer, downloads
your `partitioner` script via wget and executes it.

### Building

Packages are built with Jordan Sissel's `fpm` so install it first,
e.g. `gem install fpm`.

```bash
make udeb
```

### Configuration

The partitioner expects `part_script` to be set on the kernel
command line.  It downloads and executes a script named
`partitioner` from the root using wget.

```bash
$ cat /proc/cmdline
[..] part_script=http://pxe.example.com/script/partition.sh
```

The partitioner package can be downloaded and run from
`preseed/early_command`, e.g.:

```bash
d-i preseed/early_command string \
  wget http://pxe.example.com/udeb/remote-script-partitioner_0.0.1_all.udeb -O /tmp/partitioner.udeb \
  && udpkg --unpack /tmp/partitioner.udeb
```

### Script Example

Below is an example script for GPT + dm-crypt + LVM.  This script:

Below is an example using two disks.
One disk holds /boot, the other disk is a LVM2 PV without parition table,
allowing resized without rebooting when running as a VM.

* Requires two harddisks in fixed order, first disk is /boot with 1GB,
  second disk is 10GB+ and holds the LVM PV.
* Hardwired with ext3 for /boot, FSTYPE controls the other partitions.

```bash
#!/bin/sh

logger -t "$TAG" "Detecting disks"
BOOT=$(list-devices disk | head -n1)
MAIN=$(list-devices disk | tail -n1)
FSTYPE=ext4

logger -t "$TAG" "Bootdisk $BOOT, Main disk $MAIN"

# Create /boot
logger -t "$TAG" "Creating /boot"
anna-install parted-udeb
log-output -t "$TAG" parted -s --align=opt $BOOT -- mklabel msdos mkpart primary 1M 1000M

# Create volume group
logger -t "$TAG" "Installing LVM2"
anna-install lvm2-udeb
logger -t "$TAG" "Creating PV"
log-output -t "$TAG" pvcreate $MAIN
logger -t "$TAG" "Creating VG"
log-output -t "$TAG" vgcreate vg0 $MAIN

# Create logical volumes
logger -t "$TAG" "Creating LVs"
sleep 2
log-output -t "$TAG" lvcreate -n root -L 2G vg0
log-output -t "$TAG" lvcreate -n var -L 3G vg0
log-output -t "$TAG" lvcreate -n varlog -L 2G vg0
log-output -t "$TAG" lvcreate -n tmp -L 1G vg0
log-output -t "$TAG" lvcreate -n home -L 1G vg0

# Create filesystems
log-output -t "$TAG" mkfs.ext3 -q ${BOOT}1 -L boot

for F in root var tmp home; do
    log-output -t "$TAG" mkfs.${FSTYPE} -q -L $F /dev/mapper/vg0-$F
done;

log-output -t "$TAG" mkfs.ext3 -q /dev/mapper/vg0-varlog -L varlog

# Mount filesystems
log-output -t "$TAG" mkdir /target
log-output -t "$TAG" mount -t ${FSTYPE} /dev/mapper/vg0-root /target
log-output -t "$TAG" mkdir /target/boot
log-output -t "$TAG" mount -t ext3 ${BOOT}1 /target/boot

for F in var tmp home; do
    log-output -t "$TAG" mkdir /target/$F
    log-output -t "$TAG" mount -t ${FSTYPE} /dev/mapper/vg0-$F /target/$F
done

log-output -t "$TAG" mkdir /target/var/log
log-output -t "$TAG" mount -t ${FSTYPE} /dev/mapper/vg0-varlog /target/var/log

# Create fstab
mkdir /target/etc
cat <<EOF >/target/etc/fstab
/dev/mapper/vg0-root   /           ${FSTYPE}    defaults,relatime   0   0
/dev/mapper/vg0-home   /home       ${FSTYPE}    defaults,relatime   0   1
/dev/mapper/vg0-var    /var        ${FSTYPE}    defaults,relatime   0   1
/dev/mapper/vg0-varlog /var/log    ${FSTYPE}    defaults,relatime   0   1
/dev/mapper/vg0-tmp    /tmp        ${FSTYPE}    defaults,relatime   0   1
${BOOT}1       /boot       ext3    defaults,relatime   0   1
EOF

# Set bootloader disk
debconf-set grub-installer/bootdev $BOOT

# Trigger lvm2 package to be installed so we can boot
logger -t "$TAG" "Installing lvm2 on target"
log-output -t "$TAG" apt-install lvm2 || true

# long sleep can be handy for debugging, e.g. to inspect /var/log/syslog
# sleep 180
```
