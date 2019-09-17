# Squid proxy metrics 

Use this app to extract metrics from proxy traffic.

## Use case 

In proxy traffic environments, it is very hard to get a visibilty of traffic.

1. from inside the proxy :  you cant see the target websites being visited 
2. from outside the proxy : you cannot see the end point IP addresses.

With this app you can get good visibility of proxy traffic.

## Features

This app works with all explicit proxies. These use CONNECT tunnels.

* Tags all flows with the host name 
* A new counter group called "Proxied Servers" with Download, Upload, Hits for each server 
* Adds Edges from "Proxied Servers" counter group to "Hosts" 


## Installing 

To install this APP logon as admin, then select APP from _Web Admin > Manage > Apps._

UPDATES
=======

````
0.0.1		Sep 20 2018			Release to public 
````


