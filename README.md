# Simple container

This script is a bash script that helps create & manage simply  containers on a **Linux** system.

## Usage

To use this script, run the following command:

```bash
sudo bash container.sh container_name command
```
> `sudo` is required

Replace `container_name` with the name you want to assign to the container + `command` can be any comand (for exmple simple bash session)

**Example:** `sudo bash container.sh test bash`

## Pre-requirements
1. Check if `cgroup-tools` is on your machine. Install if needed
2. Check if `rootfs.tar` is placed near to script!
