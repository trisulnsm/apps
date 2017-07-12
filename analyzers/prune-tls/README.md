# Prune PCAP storage 


Disk saver 

## Why store TLS packets you will _never be able to read_ 

Don't waste precious Disk Space and Write IOPs storing encrypted TLS packets. 

1. Save disk space -- extend your PCAP retention
2. Lower disk throughput -- lower RAID0 requirements 
3. Fast PCAP retrieval for useful queries 
4. These packets are almost useless 
5. Trisul still processes the metrics,flows,SSL certs so you dont lose visibility
6. You can optionally store only the first 100K of each SSL flow instead of skipping entirely


This script **isnt naive**  by blindly skipping everything on Port 443 (HTTPS).

* Works on a Per-Flow basis
* Check the bytes at start of the TLS Flow in each direction for TLS Header
* Since QUIC over UDP Port 443(Google Youtube) is a really big deal today, also exclude 
  QUIC traffic by identifying the signature



### BPF
It is extremely hard to get this granularity and flexibility using long BPF lists.

Install this app today and save upto 50-60 of your disk IOP, space
