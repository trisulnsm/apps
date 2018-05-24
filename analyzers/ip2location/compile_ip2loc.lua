--
-- compile.lua
-- 
-- helper methods. Compile IP2Location databases into a LevelDB for use 
-- by Trisul Network Analytics scripts. 
-- 
-- We use levelDB and not load the whole thing into memory due to the sheer size
-- Raw DB of Country/Region is > 300MB. Why levelDB? we love it!  and two threads
-- can share a handle. 
-- 
local IPPrefixDB=require'ipprefixdb'


local bit=require'bit'

-- 
-- All databases are compiled into a single LevelDB 
-- 
function do_compile(csv_file_path, leveldb_path )

	local ldb = IPPrefixDB.new()
	ldb:open(leveldb_path);

	-- ASN is a prefix 
	ldb:set_databasename("ASN");
	process_csv_file(ldb, csv_file_path.. "/IP2LOCATION-LITE-ASN.CSV",
					 function(ldb, linearr)
						local k1 = linearr[1]
						local k2 = linearr[2]
						ldb:put_ipnum(k1,k2,linearr[4]..' '..linearr[5])
				 end)

	-- IPR (Ip region  ) 
	-- IPC (Ip countr  )
	-- IPC (Ip city )
	process_csv_file(ldb, csv_file_path.. "/IP2LOCATION-LITE-DB3.CSV",
					 function(ldb, linearr)
						local k1 = linearr[1]
						local k2 = linearr[2]
						ldb:set_databasename("CTRY");
						ldb:put_ipnum(k1,k2,linearr[3]..' '..linearr[4])
						ldb:set_databasename("STATE");
						ldb:put_ipnum(k1,k2,linearr[3]..'_'..linearr[5])
						ldb:set_databasename("CITY");
						ldb:put_ipnum(k1,k2,linearr[3]..'_'..linearr[6])
				 end)


	-- PRXY (Proxy-Type-CC) 
	process_csv_file(ldb, csv_file_path.. "/IP2PROXY-LITE-PX2.CSV",
					 function(ldb, linearr)
						local k1 = linearr[1]
						local k2 = linearr[2]
						ldb:set_databasename("PROXY");
						ldb:put_ipnum(k1,k2,linearr[3]..' '..linearr[4])
				 end)

	ldb:putraw("last_updated_tm",tostring(os.time()))
	ldb:close() 


end


-- cbfn : callbackfunc(leveldb, lineitems) 
-- 
process_csv_file=function( ldb, csv_file, cbfunc) 
	local startts = os.time() 
	local beforemem = collectgarbage("count")

	-- check if we already compiled 
	local h_csv = io.popen("md5sum   "..csv_file)
	local md5=  h_csv:read("*a"):match('%w+')
	local _,md5_db = ldb:getraw(csv_file)

	if md5_db == md5  then 
		print("Skipping. No change detected in "..csv_file)
		return 
	end

	-- update  hash
	ldb:putraw(csv_file,"in progress")

	print("Processing ".. csv_file)
	local f,err = io.open(csv_file)
	if f == nil then 
		print("Error: opening CSV file "..csv_file.." msg="..err)
		return false, err 
	end 


	local nitems = 0 
	for l in f:lines() do 
	  local  validline=true 
	  if #l==0  or l:match("%s*#") then validline=false end 

	  -- break the CSV into parts 
	  if validline  then 
		local linearr={}
		for k in l:gmatch('".-"')  do
			linearr[#linearr+1] = k:gsub('"','')
		end 
		cbfunc( ldb, linearr) 
		nitems = nitems + 1
	  end
	end 

	local endts = os.time() 
	collectgarbage()
	local aftermem = collectgarbage("count")
	print(csv_file.. ":Loaded ".. nitems.." subnets in "..(endts-startts).." seconds. Mem usage = "..(aftermem-beforemem).." KB") 

	-- update  hash
	ldb:putraw(csv_file,md5)
end


if #arg ~= 2 then
	print("Usage : compile_ip2loc directory-with-IP2LOC-databases  output-leveldb-database")
	return  
end


print("compile_ip2loc:  Compiling IP2LOCATION files in "..arg[1].." into the LevebDB dir"..arg[2])
do_compile(arg[1], arg[2])

