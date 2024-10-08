#!/bin/bash
set -e

ROOT_DIR=$(realpath .)
KERNEL_IMAGE=/home/leone/linux/arch/x86/boot/bzImage
KAFL_DIR=/home/leone/kAFL

source ${KAFL_DIR}/kafl/env.sh
kafl fuzz \
    -w ${ROOT_DIR}/workdir \
    --kernel ${KERNEL_IMAGE} \
    --initrd ${ROOT_DIR}/target.cpio.gz \
    --memory 10500 \
    --sharedir ${ROOT_DIR}/sharedir \
    --seed-dir ${ROOT_DIR}/seeds \
    -t 4 -ts 2 -tc -p 1 \
    --redqueen --grimoire --radamsa -D --funky \
    --purge --log-hprintf --abort-time 24 --cpu-offset 0 \
    --qemu-base "-enable-kvm -machine kAFL64-v1 -cpu kAFL64-Hypervisor-v1,+vmx,+rdrand -no-reboot -net none -display none"

# kafl debug \
#     --action single \
#     -w ${ROOT_DIR}/workdir_dbg \
#     --kernel ${KERNEL_IMAGE} \
#     --initrd ${ROOT_DIR}/target.cpio.gz \
#     --memory 16384 \
#     --sharedir ${ROOT_DIR}/sharedir \
#     -t 200 --input $1 \
#     --purge \
#     --qemu-base "-enable-kvm -machine kAFL64-v1 -cpu kAFL64-Hypervisor-v1,+vmx,+rdrand -no-reboot -nic user,hostfwd=tcp::5555-:1234 -display none"
# -exec add-symbol-file /root/occlum/demos/hello_c/occlum_workspace/build/lib/libocclum-libos.signed.so 0x00007fffd2bd0040
