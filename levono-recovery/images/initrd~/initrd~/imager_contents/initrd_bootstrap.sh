#!/bin/sh

# This is a 'bootstrap' script called by the initial ramdisk, that allows the application component
# to perform initialization operations in initrd context (i.e., before we are fully booted). We
# are called last to guarantee that the appropriate partitions are mounted, directory structure
# created, etc.

mount -a
