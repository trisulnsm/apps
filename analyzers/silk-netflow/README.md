Analyze SiLK Netflow data visually
====================

This LUA script allows Trisul to consume "SiLK":https://tools.netsa.cert.org/silk/ netflow  records. 

### Why would you want to do this ?

Trisul Network Analytics is an excellent platform for flow analytics. You can use Trisul as a tool to visualize a SiLK deployment.  Trisul automatically does all of the counting and aggregating and indexing you normally want to use. You get to visually work with hundreds of metrics, flow summaries, toppers, bottom-K.  

Also read the blog post : [How to send flow record to trisul](https://www.unleashnetworks.com/blog/?p=688)


## Using this script


**Step 1 : Install** 

Install SiLK tools.  You probably already have this in place. 

Download the two LUA files in this directory onto the Trisul probe.  You can put them in any directory , lets say `/home/brian/`


**Step 2 : Create a FIFO** 

This named pipe is the connector between the SiLK world and the TrisulNSM world. 

````
mkfifo /tmp/silkpipe
````
**Step 3:  Run Trisul**

We use the `importlua` tool and a new context to store the data. A context is a separate dataset. 


````bash
trisulctl_probe importlua /home/brian/silk.lua /tmp/silkpipe  context=silk111
````

Now, Trisul is waiting for records on the named FIFO `/tmp/silkpipe` You're ready to go


**Step 3:  Run rwcat**

rwcat is used to send silk files to the FIFO. You can set up a live system or play out previously captured `YAF` files. The following example shows how you can dump a YAF file to the FIFO.  Note that we need to uncompress it as shown.

````bash

$ rwcat --ipv4-output --compression=none /tmp/a12.yaf -o /tmp/silkpipe


````

Now you can logon to the `silk111` context and view reports.


