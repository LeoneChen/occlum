#!/bin/bash
set -e

INSTANCE_DIR="/root/occlum/demos/hello_c/occlum_workspace"
KAFL_DIR="/home/leone/kAFL"
export EXAMPLES_ROOT="${KAFL_DIR}/kafl/examples"

${EXAMPLES_ROOT}/linux-user/scripts/gen_initrd.sh \
    ./target.cpio.gz \
    ${EXAMPLES_ROOT}/linux-user/vmcall/vmcall /bin/bash /bin/pgrep /bin/lscpu /bin/gdbserver /etc/hostname /etc/hosts /etc/resolv.conf \
    ${INSTANCE_DIR} /opt/intel/sgxsdk /opt/occlum /usr/lib/x86_64-linux-gnu