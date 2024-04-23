# Create Simple Container
> Daria Kalashnikova d.kalashnikova@innopolis.university

### Link
https://github.com/adarika/tv-simple-container

## Intro
This script is written in Bash and is used to simply create & manage containers by creating an isolated environment for running them with restricted access to resources.

## Features:

- runs under `sudo`
- script supports only one container at a time
- limits cpu and memory via `cgroups`
- separated namespaces, network and PID namespace isolation; + forked into separate process
information and all contents
- supports any `rootfs`, it should place near to script file; I used self-made with sysbench + python3 for further testing
- after the container is created and run, it will be deleted (cleanup phase, which involves unmounting and removing data)

1. Virtual Storage Device Creation:
   - virtual storage device is created using a zeroed file as an image via `dd if=/dev/zero of=$image bs=$size count=1` for the following mount
   - setup loop mechanism to use file above as image for virtual storage device: `loop_device=$(losetup -f --show $image)`
   - make filesystem in this device - `mkfs -t ext4 $loop_device`
   - mount virtual storage device for path via `mount $loop_device $MOUNT_PATH`, where `$MOUNT_PATH` is a specific point
   - assign a rootfs to a mount path (for the container)`tar -xf $ROOTFS_PATH -C $MOUNT_PATH`

2. Container Isolation:
   - the script sets up cgroups for CPU and memory control (`cgcreate -g "cpu,memory:$1"`, where `$1` is a container's name), then executes the command in a new namespace with isolation of network and PID namespace via `unshare -n -p -f`, changed the root directory with `chroot`, and then complete needed command.

3. Cleanup:
   - After completing the container, the script unmounts the virtual storage device, removes the loop device, deletes the image and mount path
    ```bash
    umount $loop_device
    losetup -D $loop_device
    rm -rf $image $MOUNT_PATH
    ```

## Testing

| Metric | Sysbench command | Why this command | What is interesting in sysbench output |
|---|---|---|---|
| CPU computation test | `sysbench cpu --threads=4 --time=60 --cpu-max-prime=64000 run` | loads all CPU cores excessively; I expect to see difference between total time in different containers | total time |
| Threads | `sysbench threads --threads=16 --thread-yields=64 --thread-locks=2 run` | mutex performance which is important in case of testing performance in concurrent env; metrics show how well the system handles multiple threads accessing shared resources concurrently | total number of events, events avg and stddev |
| Memory concurrent write test | `sysbench memory --threads=4 --time=60 --memory-oper=write run` | memory write access with concurrent env + test paging + impact on memory transfer rate | memory speed |
| Memory stress test | `sysbench memory --memory-block-size=1M --memory-total-size=10G run` | memory write access + continuously filling it up to 1G | memory speed |
| fileIO test | `sysbench fileio --file-total-size=1G --file-test-mode=rndrw --time=120 --time=300 --max-requests=0 run` | performs big fileIO test for 5 min. to test fileio algorithm | Ops/sec (read, write, fsyncs) + latency |

### Explanation Why Metrics Differ

The reason why the metrics from the container differ from the host system is due to loop device isolation. This involves fileIO syscalls to a loop device, then fileio syscalls to a hard drive (which contains an image file of the container) => affect on FileIO test. 

#### CPU + memory
The default cgroups settings have no CPU/memory limits, so container benchmark tests provide the same performance as on the host.

#### FileIO
The performance of the container is twice worse than the host machine's metrics due to additional "overhead" caused by the loop device isolation and double file IO syscalls, as explained above.


## Appendix - testing measures

### Host machine

`sysbench cpu --threads=4 --time=60 --cpu-max-prime=64000 run`

|     | CPU events/s | total time, s | total # of events | latency min | latency avg | latency max | latency 95p | latency sum | events avg | events stddev | exec time avg | exec time sttdev |
| --- | ------------ | ------------- | ----------------- | ----------- | ----------- | ----------- | ----------- | ----------- | ---------- | ------------- | ------------- | ---------------- |
| 1 | 433.76 | 60.0067 | 26029.0 | 8.93 | 9.22 | 13.15 | 9.56 | 240004.67 | 6507.25 | 8.1 | 60.0012 | 0.0 |
| 2 | 439.76 | 60.0061 | 26389.0 | 8.62 | 9.1 | 10.44 | 9.39 | 240008.33 | 6597.25 | 11.9 | 60.0021 | 0.0 |
| 3 | 437.01 | 60.0084 | 26225.0 | 8.73 | 9.15 | 11.25 | 9.39 | 240010.92 | 6556.25 | 3.83 | 60.0027 | 0.0 |
| 4 | 445.08 | 60.0063 | 26708.0 | 8.73 | 8.99 | 11.22 | 9.39 | 240005.91 | 6677.0 | 10.42 | 60.0015 | 0.0 |
| 5 | 436.2 | 60.0085 | 26176.0 | 8.92 | 9.17 | 11.32 | 9.39 | 240010.69 | 6544.0 | 5.34 | 60.0027 | 0.0 |
| Avg | 438.3620 | 60.0072 | 26305.4000 | 8.7860 | 9.1260 | 11.4760 | 9.4240 | 240008.1040 | 6576.3500 | 7.9180 | 60.0020 | 0.0000 |

`sysbench threads --threads=16 --thread-yields=64 --thread-locks=2 run`

|     | total time, s | total # of events | latency min | latency avg | latency max | latency 95p | latency sum | events avg | events stddev | exec time avg | exec time sttdev |
| --- | ------------- | ----------------- | ----------- | ----------- | ----------- | ----------- | ----------- | ---------- | ------------- | ------------- | ---------------- |
| 1 | 10.0003 | 506986.0 | 0.01 | 0.32 | 3.5 | 0.8 | 159912.45 | 31686.625 | 202.82 | 9.9945 | 0.0 |
| 2 | 10.0004 | 473961.0 | 0.01 | 0.34 | 3.65 | 0.86 | 159917.11 | 29622.5625 | 185.08 | 9.9948 | 0.0 |
| 3 | 10.0004 | 475515.0 | 0.01 | 0.34 | 3.53 | 0.86 | 159920.63 | 29719.6875 | 182.37 | 9.995 | 0.0 |
| 4 | 10.0002 | 491476.0 | 0.01 | 0.33 | 3.3 | 0.81 | 159915.11 | 30717.25 | 167.7 | 9.9947 | 0.0 |
| 5 | 10.0003 | 470638.0 | 0.01 | 0.34 | 3.81 | 0.86 | 159913.08 | 29414.875 | 143.87 | 9.9946 | 0.0 |
| Avg | 10.0003 | 483715.2000 | 0.0100 | 0.3340 | 3.5580 | 0.8380 | 159915.6760 | 30232.2000 | 176.3680 | 9.9947 | 0.0000 |

`sysbench memory --threads=4 --time=60 --memory-oper=write run`

|     | Ops/s | Mem speed, MiB/s | total time, s | total # of events | latency min | latency avg | latency max | latency 95p | latency sum | events avg | events stddev | exec time avg | exec time sttdev |
| --- | ----- | ---------------- | ------------- | ----------------- | ----------- | ----------- | ----------- | ----------- | ----------- | ---------- | ------------- | ------------- | ---------------- |
| 1 | 11585074.19 | 11313.55 | 9.05 | 104857600.0 | 0.0 | 0.0 | 0.48 | 0.0 | 27286.88 | 26214400.0 | 0.0 | 6.8217 | 0.04 |
| 2 | 12581367.1 | 12286.49 | 8.3333 | 104857600.0 | 0.0 | 0.0 | 0.47 | 0.0 | 24716.94 | 26214400.0 | 0.0 | 6.1792 | 0.04 |
| 3 | 11834938.12 | 11557.56 | 8.8589 | 104857600.0 | 0.0 | 0.0 | 0.47 | 0.0 | 26178.33 | 26214400.0 | 0.0 | 6.5446 | 0.06 |
| 4 | 12060687.51 | 11778.02 | 8.693 | 104857600.0 | 0.0 | 0.0 | 0.47 | 0.0 | 25215.02 | 26214400.0 | 0.0 | 6.3038 | 0.08 |
| 5 | 11542780.34 | 11272.25 | 9.0832 | 104857600.0 | 0.0 | 0.0 | 0.47 | 0.0 | 27489.57 | 26214400.0 | 0.0 | 6.8724 | 0.05 |
| Avg | 11920969.4520 | 11641.5740 | 8.8037 | 104857600.0000 | 0.0000 | 0.0000 | 0.4720 | 0.0000 | 26177.3480 | 26214400.0000 | 0.0000 | 6.5443 | 0.0540 |

`sysbench memory --memory-block-size=1M --memory-total-size=10G run`

|     | Ops/s | Mem speed, MiB/s | total time, s | total # of events | latency min | latency avg | latency max | latency 95p | latency sum | events avg | events stddev | exec time avg | exec time sttdev |
| --- | ----- | ---------------- | ------------- | ----------------- | ----------- | ----------- | ----------- | ----------- | ----------- | ---------- | ------------- | ------------- | ---------------- |
| 1 | 25187.06 | 25187.06 | 0.4055 | 10240.0 | 0.04 | 0.04 | 0.09 | 0.04 | 403.83 | 10240.0 | 0.0 | 0.4038 | 0.0 |
| 2 | 25293.55 | 25293.55 | 0.4037 | 10240.0 | 0.04 | 0.04 | 0.06 | 0.04 | 402.06 | 10240.0 | 0.0 | 0.4021 | 0.0 |
| 3 | 25280.41 | 25280.41 | 0.404 | 10240.0 | 0.04 | 0.04 | 0.09 | 0.04 | 402.27 | 10240.0 | 0.0 | 0.4023 | 0.0 |
| 4 | 25264.7 | 25264.7 | 0.4042 | 10240.0 | 0.04 | 0.04 | 0.09 | 0.04 | 402.56 | 10240.0 | 0.0 | 0.4026 | 0.0 |
| 5 | 25290.33 | 25290.33 | 0.4038 | 10240.0 | 0.04 | 0.04 | 0.05 | 0.04 | 402.24 | 10240.0 | 0.0 | 0.4022 | 0.0 |
| Avg | 25263.2100 | 25263.2100 | 0.4042 | 10240.0000 | 0.0400 | 0.0400 | 0.0760 | 0.0400 | 402.5920 | 10240.0000 | 0.0000 | 0.4026 | 0.0000 |

`sysbench fileio --file-total-size=1G --file-test-mode=rndrw --time=120 --time=300 --max-requests=0 run`

|     | ops reads/s | ops writes/s | ops fsyncs/s | throughput read, MiB/s | throughput write, MiB/s | total time, s | total # of events | latency min | latency avg | latency max | latency 95p | latency sum | events avg | events stddev | exec time avg | exec time sttdev |
| --- | ----------- | ------------ | ------------ | ---------------------- | ----------------------- | ------------- | ----------------- | ----------- | ----------- | ----------- | ----------- | ----------- | ---------- | ------------- | ------------- | ---------------- |
| 1 | 879.24 | 586.16 | 1875.9 | 13.74 | 9.16 | 300.0499 | 1002446.0 | 0.0 | 0.3 | 13.75 | 2.14 | 298992.56 | 1002446.0 | 0.0 | 298.9926 | 0.0 |
| 2 | 678.44 | 452.29 | 1447.41 | 10.6 | 7.07 | 300.0667 | 773499.0 | 0.0 | 0.39 | 16.25 | 2.22 | 299037.66 | 773499.0 | 0.0 | 299.0377 | 0.0 |
| 3 | 676.36 | 450.91 | 1443.3 | 10.57 | 7.05 | 300.0124 | 771088.0 | 0.0 | 0.39 | 11.59 | 2.22 | 299001.51 | 771088.0 | 0.0 | 299.0015 | 0.0 |
| 4 | 741.42 | 494.28 | 1581.79 | 11.58 | 7.72 | 300.066 | 845321.0 | 0.0 | 0.35 | 11.67 | 2.18 | 298934.44 | 845321.0 | 0.0 | 298.9344 | 0.0 |
| 5 | 813.9 | 542.6 | 1736.57 | 12.72 | 8.48 | 300.0357 | 927907.0 | 0.0 | 0.32 | 12.95 | 2.14 | 299286.34 | 927907.0 | 0.0 | 299.2863 | 0.0 |
| Avg | 757.8720 | 505.2480 | 1616.9940 | 11.8420 | 7.8960 | 300.0461 | 864052.2000 | 0.0000 | 0.3500 | 13.2420 | 2.1800 | 299050.5020 | 864052.2000 | 0.0000 | 299.0505 | 0.0000 |

### Inside container

`sysbench cpu --threads=4 --time=60 --cpu-max-prime=64000 run`

|     | CPU events/s | total time, s | total # of events | latency min | latency avg | latency max | latency 95p | latency sum | events avg | events stddev | exec time avg | exec time sttdev |
| --- | ------------ | ------------- | ----------------- | ----------- | ----------- | ----------- | ----------- | ----------- | ---------- | ------------- | ------------- | ---------------- |
| 1 | 462.53 | 60.0081 | 27756.0 | 8.39 | 8.65 | 12.87 | 9.06 | 240018.24 | 6939.0 | 12.25 | 60.0046 | 0.0 |
| 2 | 462.65 | 60.0081 | 27763.0 | 8.4 | 8.65 | 11.92 | 8.9 | 240014.62 | 6940.75 | 13.99 | 60.0037 | 0.0 |
| 3 | 467.46 | 60.0047 | 28050.0 | 8.21 | 8.56 | 12.91 | 8.9 | 240000.48 | 7012.5 | 12.09 | 60.0001 | 0.0 |
| 4 | 460.49 | 60.0069 | 27633.0 | 8.22 | 8.69 | 12.07 | 9.06 | 240011.57 | 6908.25 | 18.67 | 60.0029 | 0.0 |
| 5 | 461.25 | 60.0076 | 27679.0 | 8.41 | 8.67 | 11.99 | 8.9 | 240010.46 | 6919.75 | 14.55 | 60.0026 | 0.0 |
| Avg | 462.8760 | 60.0071 | 27776.2000 | 8.3260 | 8.6440 | 12.3520 | 8.9640 | 240011.0740 | 6944.0500 | 14.3100 | 60.0028 | 0.0000 |


`sysbench memory --threads=4 --time=60 --memory-oper=write run`

|     | total time, s | total # of events | latency min | latency avg | latency max | latency 95p | latency sum | events avg | events stddev | exec time avg | exec time sttdev |
| --- | ------------- | ----------------- | ----------- | ----------- | ----------- | ----------- | ----------- | ---------- | ------------- | ------------- | ---------------- |
| 1 | 10.0002 | 524065.0 | 0.01 | 0.31 | 8.25 | 0.77 | 159891.76 | 32754.0625 | 188.34 | 9.9932 | 0.0 |
| 2 | 10.0003 | 523972.0 | 0.01 | 0.31 | 13.49 | 0.77 | 159898.3 | 32748.25 | 224.55 | 9.9936 | 0.0 |
| 3 | 10.0002 | 525472.0 | 0.01 | 0.3 | 7.43 | 0.77 | 159891.89 | 32842.0 | 180.39 | 9.9932 | 0.0 |
| 4 | 10.0003 | 537956.0 | 0.01 | 0.3 | 6.66 | 0.75 | 159898.61 | 33622.25 | 177.87 | 9.9937 | 0.0 |
| 5 | 10.0004 | 507976.0 | 0.01 | 0.31 | 15.95 | 0.8 | 159900.45 | 31748.5 | 124.54 | 9.9938 | 0.0 |
| Avg | 10.0003 | 523888.2000 | 0.0100 | 0.3060 | 10.3560 | 0.7720 | 159896.2020 | 32743.0125 | 179.1380 | 9.9935 | 0.0000 |


`sysbench memory --threads=4 --time=60 --memory-oper=write run`

|     | Ops/s | Mem speed, MiB/s | total time, s | total # of events | latency min | latency avg | latency max | latency 95p | latency sum | events avg | events stddev | exec time avg | exec time sttdev |
| --- | ----- | ---------------- | ------------- | ----------------- | ----------- | ----------- | ----------- | ----------- | ----------- | ---------- | ------------- | ------------- | ---------------- |
| 1 | 11797646.59 | 11521.14 | 8.8869 | 104857600.0 | 0.0 | 0.0 | 0.48 | 0.0 | 26371.75 | 26214400.0 | 0.0 | 6.5929 | 0.01 |
| 2 | 11354927.49 | 11088.8 | 9.2334 | 104857600.0 | 0.0 | 0.0 | 0.48 | 0.0 | 27464.83 | 26214400.0 | 0.0 | 6.8662 | 0.07 |
| 3 | 12428112.38 | 12136.83 | 8.436 | 104857600.0 | 0.0 | 0.0 | 0.5 | 0.0 | 24979.62 | 26214400.0 | 0.0 | 6.2449 | 0.02 |
| 4 | 11685704.44 | 11411.82 | 8.972 | 104857600.0 | 0.0 | 0.0 | 0.44 | 0.0 | 27317.77 | 26214400.0 | 0.0 | 6.8294 | 0.04 |
| 5 | 11133502.61 | 10872.56 | 9.4171 | 104857600.0 | 0.0 | 0.0 | 0.48 | 0.0 | 28093.99 | 26214400.0 | 0.0 | 7.0235 | 0.08 |
| Avg | 11679978.7020 | 11406.2300 | 8.9891 | 104857600.0000 | 0.0000 | 0.0000 | 0.4760 | 0.0000 | 26845.5920 | 26214400.0000 | 0.0000 | 6.7114 | 0.0440 |


`sysbench memory --memory-block-size=1M --memory-total-size=10G run`

|     | Ops/s | Mem speed, MiB/s | total time, s | total # of events | latency min | latency avg | latency max | latency 95p | latency sum | events avg | events stddev | exec time avg | exec time sttdev |
| --- | ----- | ---------------- | ------------- | ----------------- | ----------- | ----------- | ----------- | ----------- | ----------- | ---------- | ------------- | ------------- | ---------------- |
| 1 | 25112.5 | 25112.5 | 0.4066 | 10240.0 | 0.04 | 0.04 | 0.09 | 0.04 | 404.84 | 10240.0 | 0.0 | 0.4048 | 0.0 |
| 2 | 25284.54 | 25284.54 | 0.4039 | 10240.0 | 0.04 | 0.04 | 0.1 | 0.04 | 402.12 | 10240.0 | 0.0 | 0.4021 | 0.0 |
| 3 | 25115.8 | 25115.8 | 0.4066 | 10240.0 | 0.04 | 0.04 | 0.13 | 0.04 | 404.78 | 10240.0 | 0.0 | 0.4048 | 0.0 |
| 4 | 25131.14 | 25131.14 | 0.4063 | 10240.0 | 0.04 | 0.04 | 0.11 | 0.04 | 404.63 | 10240.0 | 0.0 | 0.4046 | 0.0 |
| 5 | 25200.93 | 25200.93 | 0.4052 | 10240.0 | 0.04 | 0.04 | 0.05 | 0.04 | 403.44 | 10240.0 | 0.0 | 0.4034 | 0.0 |
| Avg | 25168.9820 | 25168.9820 | 0.4057 | 10240.0000 | 0.0400 | 0.0400 | 0.0960 | 0.0400 | 403.9620 | 10240.0000 | 0.0000 | 0.4039 | 0.0000 |


`sysbench fileio --file-total-size=1G --file-test-mode=rndrw --time=120 --time=300 --max-requests=0 run`

|     | ops reads/s | ops writes/s | ops fsyncs/s | throughput read, MiB/s | throughput write, MiB/s | total time, s | total # of events | latency min | latency avg | latency max | latency 95p | latency sum | events avg | events stddev | exec time avg | exec time sttdev |
| --- | ----------- | ------------ | ------------ | ---------------------- | ----------------------- | ------------- | ----------------- | ----------- | ----------- | ----------- | ----------- | ----------- | ---------- | ------------- | ------------- | ---------------- |
| 1 | 526.16 | 350.78 | 1122.9 | 8.22 | 5.48 | 300.019 | 599864.0 | 0.0 | 0.5 | 17.57 | 4.49 | 299610.05 | 599864.0 | 0.0 | 299.61 | 0.0 |
| 2 | 323.28 | 215.52 | 689.81 | 5.05 | 3.37 | 300.1039 | 368589.0 | 0.0 | 0.81 | 16.39 | 4.82 | 299537.13 | 368589.0 | 0.0 | 299.5371 | 0.0 |
| 3 | 321.93 | 214.62 | 687.07 | 5.03 | 3.35 | 300.0633 | 367040.0 | 0.0 | 0.82 | 17.49 | 4.91 | 299522.66 | 367040.0 | 0.0 | 299.5227 | 0.0 |
| 4 | 322.64 | 215.1 | 688.42 | 5.04 | 3.36 | 300.1412 | 367897.0 | 0.0 | 0.81 | 16.5 | 4.82 | 299519.32 | 367897.0 | 0.0 | 299.5193 | 0.0 |
| 5 | 322.12 | 214.75 | 687.47 | 5.03 | 3.36 | 300.07 | 367263.0 | 0.0 | 0.82 | 17.95 | 4.82 | 299531.37 | 367263.0 | 0.0 | 299.5314 | 0.0 |
| Avg | 363.2260 | 242.1540 | 775.1340 | 5.6740 | 3.7840 | 300.0795 | 414130.6000 | 0.0000 | 0.7520 | 17.1800 | 4.7720 | 299544.1060 | 414130.6000 | 0.0000 | 299.5441 | 0.0000 |
