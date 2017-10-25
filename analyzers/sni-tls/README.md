Server Name Indication based metrics
====================================

SNI (Server Name Indicator) is a TLS Extension. This app gives you visibility into 
TLS/SSL traffic by breaking it up by SNI Hostname. 


This app provides three metrics 

1. A new Counter Group called "SNI" 
    1. meter 0 : bandwidth  per hostname
	2. meter 1 : flows/hits per hostname

2. A new Resource Group called "SNI" contains IP->SNI hostname mapping 

3. Top SNI Hostnames for each meter by bandwidth and hits 


Versions:
=========

0.0.6  	Oct 25 2017  		Updated - flowkey() 
0.0.5  	Oct 11 2017  		Add Edges from TLS SNI to flow vertices 

