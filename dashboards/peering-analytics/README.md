# Peering Analytics


This app adds Router/Interface/AS analytics to Trisul. 

You can analyze

1. AS traffic , globally, per router, per interface
2. Country traffic
3. Prefixes 

For each of these you have to specify the cross key 


## For AS Analytics


Two Crosskey Counter groups are required.   Router X AS and Interface X AS 

After installing , add these GUIDs to module params. 


````
{
	crosskey_router:"{B2BE5B9D-E60A-DF2A-3FB4-8C57A38CB6A0}",
	crosskey_interface:"{FC5E7CEF-9914-0312-382F-6677998407BC}",
	meters:{upload:0,download:1}
	
}

````
