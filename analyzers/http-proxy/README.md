# HTTP Proxy

If you have an environment where Web Traffic goes through a Proxy Server and you are only able to capture data on the "inside side", this plugin is for you. We have put Trisul in such customer environments to find that the Destination IP of all flows is the IP of the proxy server. This plugin provides you the following.

1. handles HTTP CONNECT and straight through HTTP proxies (Squid and most other commonly available UTMs)
2. adds a new Traffic Counter Group "External Hosts Proxy" to measure the actual Destination rather than the Proxy server IP
3. labels all flows with the actual destination host. So you can search by server name "Show me mail.google.com flows" 
4. adds EDGE for graph analytics 

## Installation


Login as admin, then Web Admin > Apps and click on "HTTP Proxy". 

Restart Trisul-Probe and you're done. 


## Viewing


1. Retro Counters > Proxy External Hosts to see upload / download traffic by actual hostname
2. Flows > Search by @tag=mail.google.com@ to search for flows to target hosts 
3. From any point you can click on  "View Edges" to see related items. Example - which internal host connected to "Malware.site.com"

## Configuration parameters

If you want to over ride the default parameters, copy this chunk of code into a file called `trisulnsm_http_connect.lua` in 
the probe config directory `/usr/local/var/lib/trisul-probe/dX/pX/contextX/config`

The two parameters are used to control how very long HTTP hostnames are dealt with

````lua

DEFAULT_CONFIG = {

  -- number of dots in hostname to track 
  -- skks.mail.yahoo.com = 3 dots 
  NumDots=3,
  
  -- max hostname len 
  MaxHostnameLen=25,
}

````


UPDATES
=======

0.0.2		Jun 27 2018			Added config options to control very long proxy external host names 
0.0.1		Jun 26 2018			Initial release 



