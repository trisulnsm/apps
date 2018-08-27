local LDB=require'tris_leveldb'

local csv_file=arg[1]
local out_db=arg[2]

print("Compiling 1M "..csv_file) 

-- in_file 
local f,err = io.open(csv_file,"r")
if not f then
    print("Unable to open Cisco Umbrella Feed file="..csv_file.." err="..err);
    return false;
end

-- out_db 
local ldb=LDB:new()

local status,err=ldb:open(out_db)
if not status then
    print("Unable to open leveldb database err="..out_db.." err="..err);
    return false;
end

-- push each  into leveldb 
for l in f:lines() do 
	local h = l:match("%d+,(%S+)")
	ldb:put(h,"1")
end 

f:close() 
ldb:close()

