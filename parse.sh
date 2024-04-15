#!/bin/bash

# MacOS
# brew install sysbench

# Debian/Ubuntu
# curl -s https://packagecloud.io/install/repositories/akopytov/sysbench/script.deb.sh | sudo bash
# sudo apt -y install sysbench

# Arch
# sudo pacman -Suy sysbench

for i in $(seq 1 5);
do
    sysbench --test=cpu --time=60 --cpu-max-prime=20000 run >> res_cpu_${i}.txt

    sysbench --num-threads=64 --test=threads --thread-yields=100 --thread-locks=2 run >> res_threads_${i}.txt

    sysbench --test=memory --memory-block-size=1M --memory-total-size=1G run >> res_memory_${i}.txt

    sysbench --test=fileio --file-total-size=1G prepare
    sysbench --test=fileio --file-total-size=1G --file-test-mode=rndrw --time=120 --max-time=300 --max-requests=0 run >> res_io_${i}.txt
    sysbench --test=fileio --file-total-size=1G cleanu
done
