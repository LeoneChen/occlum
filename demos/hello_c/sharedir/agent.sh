#!/bin/sh
echo "Hello from agent.sh"

export PATH=/opt/occlum/build/bin:/usr/local/occlum/bin:$PATH

echo 0 > /proc/sys/kernel/randomize_va_space
cat /proc/sys/kernel/randomize_va_space

cd /home/leone/occlum/demos/hello_c/occlum_workspace

ifconfig eth0 10.0.2.15
ip addr

source /opt/occlum/sgxsdk-tools/environment
# occlum run /bin/hello_world
export LD_LIBRARY_PATH=/home/leone/occlum/demos/hello_c/occlum_workspace/build/lib:$LD_LIBRARY_PATH
export OCCLUM_GDB=1
export OCCLUM_LOG_LEVEL=trace
export
# gdbserver 127.0.0.1:1234 /home/leone/occlum/demos/hello_c/occlum_workspace/build/bin/occlum-run /bin/hello_world_kafl
/home/leone/occlum/demos/hello_c/occlum_workspace/build/bin/occlum-run /bin/hello_world

# return to loader.sh, which will upload agent.log
