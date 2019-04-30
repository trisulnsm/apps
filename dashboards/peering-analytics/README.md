# Peering Analytics

This app adds Router/Interface/AS analytics to Trisul. 

You can analyze

1. AS traffic , globally, per router, per interface
2. Country traffic
3. Prefixes 

For each of these you have to specify the cross key 


## For AS Analytics

Two Crosskey Counter groups are required.  Named Auto_Routers_ASN and Auto_Interfaces_ASN  

If you have different names, you can edit the module params to specify them.


````
{
	crosskey_router:"{B2BE5B9D-E60A-DF2A-3FB4-8C57A38CB6A0}",
	crosskey_interface:"{FC5E7CEF-9914-0312-382F-6677998407BC}",
	meters:{upload:0,download:1}
	
}

````
