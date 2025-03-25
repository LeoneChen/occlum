#!/bin/bash -e

# 
# Copyright (C)  2022  Intel Corporation. 
#
# This software and the related documents are Intel copyrighted materials, and
# your use of them is governed by the express license under which they were
# provided to you ("License"). Unless the License provides otherwise, you may
# not use, modify, copy, publish, distribute, disclose or transmit this software
# or the related documents without Intel's prior written permission.  This
# software and the related documents are provided as is, with no express or
# implied warranties, other than those that are expressly stated in the License.
#
# SPDX-License-Identifier: MIT

# Helper script for generating busybox-based initrd rootfs

set -e
set -u

INSTANCE_DIR="/home/leone/occlum/demos/hello_c/occlum_workspace"
KAFL_DIR="/home/leone/kAFL"
EXAMPLES_ROOT="${KAFL_DIR}/kafl/examples"
SCRIPT_ROOT=$EXAMPLES_ROOT/linux-user
TEMPLATE=$SCRIPT_ROOT/initrd_template

fatal() {
	echo
	echo -e "\nError: $@\n" >&2
	echo -e "Usage:\n\t$(basename $0) <path/to/initrd.cpio.gz> [FILE...]\n" >&2
	exit 1
}

# autostart /loader.sh
function bless_loader()
{
	echo "[*] Blessing image to launch /loader.sh"

	pushd "$TARGET_ROOT" > /dev/null
	chmod a+x loader.sh

	if ls etc/init.d/S0* > /dev/null 2>&1; then
		# works for buildroot and anything close to sysv init
		echo "[*] Adding loader.sh to /etc/init.d/ scripts.."
		ln -sf /loader.sh etc/init.d/S00loader
	elif ! test -e etc/rcS; then
		# homebrew initrd may not works for busybox initrd
		echo "[*] Linking etc/rcS to loader.sh.."
		ln -sf /loader.sh etc/rcS
	else
		echo "Not a sysv init and refuse to overwrite etc/rcS. Please ensure loader.sh is launched on boot."
	fi
	popd > /dev/null
}

# create busybox rootfs
function create_rootfs()
{
	echo "[*] Building busybox rootfs at $TARGET_ROOT..."
	pushd "$TARGET_ROOT" > /dev/null
	mkdir -p  bin dev  etc  lib  lib64  mnt/root  proc  root  sbin  sys  usr/bin
	$BUSYBOX --install -s bin/
	cp $BUSYBOX usr/bin
	popd > /dev/null
}

function inject_file()
{
	abs_path=$(realpath -s $1)
	real_path=$(realpath $1)

	echo "[*] Copying $real_path => $TARGET_ROOT/$real_path..."
	install -D $real_path $TARGET_ROOT/$real_path

	if [[ "${abs_path}" != "${real_path}" ]]; then
		echo "[*] Linking $real_path => $TARGET_ROOT/$abs_path..."
		mkdir -p $(dirname $TARGET_ROOT/$abs_path)
		ln -sf $real_path $TARGET_ROOT/$abs_path
	fi

	echo "[*] Copying dependencies of $real_path..."
	for dep in $($LDDTREE $real_path|grep -v "interpreter => none"|sed -e s/.*' => '// -e 's/)$//'|sort -u); do
		install -Dv "$dep" $TARGET_ROOT/"$dep"
	done
}

function inject_file2fuzz()
{
	real_path=$(realpath $1)

	echo "[*] Copying $real_path => Dir. $TARGET_ROOT/fuzz..."
	install -D -t $TARGET_ROOT/fuzz $real_path

	echo "[*] Copying dependencies of $real_path..."
	for dep in $($LDDTREE $real_path|grep -v "interpreter => none"|sed -e s/.*' => '// -e 's/)$//'|sort -u); do
		install -Dv "$dep" $TARGET_ROOT/"$dep"
	done
}

# inject any additional files, including their dependencies
function inject_files()
{
	echo "[*] Copying template files..."
	cp -vr $TEMPLATE/* "$TARGET_ROOT"/

	# echo "[*] Copying given file args to /fuzz..."
	# echo "Install { $@ } => $TARGET_ROOT/fuzz/"
	# install -D -t $TARGET_ROOT/fuzz/ $@

	# echo "[*] Copying any detected dependencies..."
	# for dep in $($LDDTREE $@|grep -v "interpreter => none"|sed -e s/.*' => '// -e 's/)$//'|sort -u); do
	# 	echo "Install $dep => $TARGET_ROOT/$dep"
	# 	install -D "$dep" $TARGET_ROOT/"$dep"
	# done

	echo "[*] Copying basic utils..."
	inject_file2fuzz ${SCRIPT_ROOT}/vmcall/vmcall
	inject_file /bin/bash
	inject_file /bin/pgrep
	inject_file /bin/lscpu
	inject_file /bin/sha256sum
	inject_file /bin/gdbserver
	inject_file /etc/hostname
	inject_file /etc/hosts
	inject_file /etc/resolv.conf
	inject_file /usr/lib/x86_64-linux-gnu/libcrypto.so.1.1

	echo "[*] Copying dependencies about SGX..."
	echo "[*] Copying $INSTANCE_DIR/ => $TARGET_ROOT/$INSTANCE_DIR/..."
	mkdir -p $TARGET_ROOT/$INSTANCE_DIR
	rsync -a --exclude='image/' $INSTANCE_DIR/ $TARGET_ROOT/$INSTANCE_DIR/
	echo "[*] Copying /usr/lib/x86_64-linux-gnu/ => $TARGET_ROOT/usr/lib/x86_64-linux-gnu/..."
	mkdir -p $TARGET_ROOT/usr/lib/x86_64-linux-gnu/
	rsync -a --include='*sgx*' --exclude='*' /usr/lib/x86_64-linux-gnu/ $TARGET_ROOT/usr/lib/x86_64-linux-gnu/
	echo "[*] Copying /opt/occlum/ => $TARGET_ROOT/opt/occlum/..."
	mkdir -p $TARGET_ROOT/opt/occlum/
	rsync -a --exclude='toolchains' /opt/occlum/ $TARGET_ROOT/opt/occlum/
}

function build_image()
{
	echo "[*] Generating final image at $TARGET_INITRD"
	pushd "$TARGET_ROOT" > /dev/null
	find . -print0 | cpio --null --create --format=newc | gzip --fast  > $TARGET_INITRD
	popd > /dev/null
}


##
## main()
##

test "$#" -ge 1 || fatal "Need ad least one argument: <path/to/initrd.cpio.gz>"
test -d "$TEMPLATE" || fatal "Could not find initrd template folder >>$TEMPLATE<<"

BUSYBOX=$(which busybox) || fatal "Could not find busybox - try 'sudo apt install busybox-static'?"
LDDTREE=$(which lddtree) || fatal "Could not find lddtree - try 'sudo apt install lddtree'?"

$LDDTREE $BUSYBOX |grep -q "interpreter => none" || fatal "Binary at $BUSYBOX is not static. Try 'apt install busybox-static'."

TARGET_INITRD="$(realpath "$1")"; shift;
TARGET_ROOT="$(mktemp -d)"

test -z "$TARGET_INITRD" && fatal "Output path $TARGET_INITRD is not set. Abort."


create_rootfs
inject_files "$@"
bless_loader
build_image

rm -rf "$TARGET_ROOT"
