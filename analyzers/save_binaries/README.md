# Save EXE, PE, DLL, FLASH, PDF 

Install this app and immediately start dumping potentially malicious binaries 
transferred via HTTP to `/tmp/savedfiles`

## Installing - enable FileExtraction

For this plugin to work you need to ensure :

1. Open the Probe Config `/usr/local/etc/trisul-probe/domain0/probe0/context0/trisulProbeConfig.xml` file
2. Verify if the `FileExtraction > Enabled` option is `TRUE`
3. You also need to create a RAMFS/TMPFS  partition for this feature. To do this 
    1. run `trisulctl_probe createramfs probe0 default` and specify a size of say 40M 
	2. add this file system to `/etc/fstab` as described in [Creating ramfs](https://www.trisul.org/docs/lua/fileextractoverview.html#the_ramfs_filesystem)
4. Restart Trisul Probe 


## What is dumped

Any file of any size whose _Magic Number_ string meets the following RegEx. You can test 
this string by running the *file* command in Linux.

````
T.trigger_patterns = T.re2("(?i)(msdos|ms-dos|microsoft|windows|elf|executable|pdf|flash)")
````

The default pattern above pulls in all Microsoft Office Doc types, PDF, Flash, Windows EXE/DLL 

## What to do with these files

You can send these files for further analysis to platforms like 

* YARA https://virustotal.github.io/yara/
* Lockheed's LAIKA BOSS Object Scanning platform : https://github.com/lmco/laikaboss
* VirusTotal


## Tuning

This may also pull in ICO files due to the presence of "Microsoft" in the file type.
If this is too noisy you can edit the LUA Regex and submit a pull request.


## LUA Docs 
For more details see [File Extraction Overview](https://www.trisul.org/docs/lua/fileextractoverview.html) 
