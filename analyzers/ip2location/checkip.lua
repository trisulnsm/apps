local IPPrefixDB=require'ipprefixdb'

if #arg ~= 1 then
	print("Need IPv4 or IPv6 to lookup into the IP lookup")
	print("Usage: checkip 29.23.4.11")
	return 1
end 

ipstr=arg[1]


print("IP2Location Report for IP "..ipstr)

ip=ipstr_tokey(ipstr)
print("Key  :"..ip)

-- create and open 
local ldb = IPPrefixDB.new()
ldb:open("/usr/local/share/trisul-probe/plugins/trisul-ip2loc-0.level")

		
ldb:set_databasename("ASN")
local val = ldb:lookup_prefix(ip)
if val then 
	print("ASN  :"..val)
else
	print("ASN   not found ")
end 

ldb:set_databasename("CTRY")
local val = ldb:lookup_prefix(ip)
if val then 
	print("CTRY :"..val)
else
	print("CTRY not found ")
end 

ldb:set_databasename("STATE")
local val = ldb:lookup_prefix(ip)
if val then 
	print("STATE:"..val)
else
	print("STATE not found ")
end 

ldb:set_databasename("CITY")
local val = ldb:lookup_prefix(ip)
if val then 
	print("CITY :"..val)
else
	print("CITY not found ")
end 

ldb:set_databasename("PROXY")
local val = ldb:lookup_prefix(ip)
if val then 
	print("PROXY:"..val)
else
	print("PROXY not found ")
end 

-- closing 
ldb:close()

