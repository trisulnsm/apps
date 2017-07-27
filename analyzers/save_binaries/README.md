# Save EXE, PE, DLL, FLASH, PDF, ISO 

Install this app and immediately start dumping potentially malicious binaries 
transferred via HTTP to `/tmp/savedfiles`

## Installing - enable FileExtraction

1. Open the Probe Config `/usr/local/etc/trisul-probe/domain0/probe0/context0/trisulProbeConfig.xml` file
2. Verify if the `FileExtraction > Enabled` option is `TRUE`
3. Create a RAMFS/TMPFS  partition for this feature. To do this 
    1. run `trisulctl_probe createramfs probe0 default` and specify a size of say 40M 
	2. add this file system to `/etc/fstab` as described in [Creating ramfs](https://www.trisul.org/docs/lua/fileextractoverview.html#the_ramfs_filesystem)

## Config parameters

To override the default parameters
````
DEFAULT_CONFIG = { 
	-- where do you want the extracted files to go
	OutputDirectory="/tmp/savedfiles",

	-- the strings returned by libmagic you want to save
	Regex="(?i)(msdos|ms-dos|microsoft|windows|elf|executable|pdf|flash|macro)"
}
````

create a new config file named `trisulnsm_save_exe.config.lua` in the probe config directory
`/usr/local/var/lib/trisul-probe/domain0/probe0/context0/config` directory with the following

````
return { 
	-- where do you want the extracted files to go
	OutputDirectory="/my/output/directory,

	-- the strings returned by libmagic you want to save
	Regex="(?i)(msdos|ms-dos|microsoft|windows|executable)"
}

````
				

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


## Also install

The **Save Binaries Dashboard App** gives you a neat dashboard of metrics related to this feature. 
