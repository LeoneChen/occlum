#!/bin/bash
set -e

ROOT_DIR=$(realpath .)
KERNEL_IMAGE=/home/leone/linux/arch/x86/boot/bzImage
KAFL_DIR=/home/leone/kAFL

debug=0
seed=

OPTS=$(getopt -o ghs: -l help,seed -n 'parse-options' -- "$@")
if [ $? != 0 ]; then
  echo "Failed to parse options... exiting." >&2
  exit 1
fi
eval set -- "$OPTS"
while true; do
  case "$1" in
    -g ) debug=1;               shift 1 ;;
    -h|--help ) help=1;         shift 1 ;;
    -s|--seed ) seed=$2;        shift 2 ;;
    -- ) shift; break ;;
    * ) break ;;
  esac
done

source ${KAFL_DIR}/kafl/env.sh
if [ $debug -eq 1 ]; then
kafl debug \
    --action single \
    -w ${ROOT_DIR}/workdir_dbg \
    --kernel ${KERNEL_IMAGE} \
    --initrd ${ROOT_DIR}/target.cpio.gz \
    --memory 2100 \
    --sharedir ${ROOT_DIR}/sharedir \
    -t 0 --input $seed \
    --purge \
    --qemu-base "-enable-kvm -machine kAFL64-v1 -cpu kAFL64-Hypervisor-v1,+vmx,+rdrand -no-reboot -nic user,hostfwd=tcp::5555-:1234 -display none"
# 0x7FFFD2B92000 [0x00007fffd3415eca(enclave_entry's rip) - 0000000000883eca(objdump libocclum-libos.signed.so --disassemble=enclave_entry)] + 0000000000085040 (readelf -S libocclum-libos.signed.so|grep .text)
# -exec add-symbol-file /home/leone/occlum/demos/hello_c/occlum_workspace/build/lib/libocclum-libos.signed.so 0x00007fffd2c17040
else
kafl fuzz \
    -w ${ROOT_DIR}/workdir \
    --kernel ${KERNEL_IMAGE} \
    --initrd ${ROOT_DIR}/target.cpio.gz \
    --memory 2100 \
    --sharedir ${ROOT_DIR}/sharedir \
    --seed-dir ${ROOT_DIR}/seeds \
    -t 4 -ts 2 -tc -p 1 \
    --redqueen --grimoire --radamsa -D --funky \
    --purge --log-hprintf --abort-time 24 --cpu-offset 0 \
    --qemu-base "-enable-kvm -machine kAFL64-v1 -cpu kAFL64-Hypervisor-v1,+vmx,+rdrand -no-reboot -net none -display none"
fi
