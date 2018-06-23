#!/bin/sh

TAG="remote-partitioner"
PARTURL=$(sed -n 's/.*part_script=\([^ ]\+\).*/\1/p' /proc/cmdline)
SCRIPT=partitioner

# make $TAG available to partitioning script
export TAG="$TAG"

sed -i -e 's/partman/#partman/' /var/lib/dpkg/info/partman-base.postinst
logger -t "$TAG" "Disabled partman."

logger -t "$TAG" "Starting disk partition."
logger -t "$TAG" "Downloading $SCRIPT from $SERVER."
wget $PARTURL -O "/tmp/$SCRIPT" \
    && chmod 755 "/tmp/$SCRIPT" \
    && "/tmp/$SCRIPT"

if [ $? -eq 0 ]; then
  logger -t "$TAG" "Finished disk partitioning."
else
  logger -t "$TAG" "Disk partitioning failed."
fi
