**raspbian.sh** let you download, customize and install raspbian OS.

```
$ ./raspbian.sh -h
raspbian.sh [options]

Options:

-b	Path to an sdcard block device
-c	Customize a raspbian image
-d	Download the latest raspbian image
-e	Extend the filesystem on an sdcard
-i	Install raspbian image on an sdcard
-p	Path to an existing raspbian image

examples:

Extend the fs in an sdcard
$ raspbian.sh -e -b /dev/mmcblk0

Download the latest raspbian image and customize it
$ raspbian.sh -c -d 

Customize a specific raspbian image
$ raspbian.sh -c -p /path/to/raspbian.img

Install raspbian on an sdcard
$ raspbian.sh -p /path/to/raspbian.img -b /dev/mmcblk0
```

## License
The source code in this repo is licenced under the GPL 3
