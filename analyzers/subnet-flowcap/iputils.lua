local bit=require 'bit'

-- ip number to trisulkey format
function ipnum_tokey(ipnum)
	return string.format("%02X.%02X.%02X.%02X", 
		bit.rshift(ipnum,24), bit.band(bit.rshift(ipnum,16),0xff), bit.band(bit.rshift(ipnum,8),0xff), bit.band(bit.rshift(ipnum,0),0xff))
end

function ipnum_todotted(ipnum)
	return string.format("%d.%d.%d.%d", 
		bit.rshift(ipnum,24), bit.band(bit.rshift(ipnum,16),0xff), bit.band(bit.rshift(ipnum,8),0xff), bit.band(bit.rshift(ipnum,0),0xff))
end

function key_toipnum(key)
  local pmatch,_, b1,b2,b3,b4= key:find("(%x+)%.(%x+)%.(%x+)%.(%x+)")
  return  tonumber(b1,16)*16777216+tonumber(b2,16)*65536+tonumber(b3,16)*256+tonumber(b4,16) 
end

function ipstr_tokey(ipstr)
  local pmatch,_, b1,b2,b3,b4= ipstr:find("(%d+)%.(%d+)%.(%d+)%.(%d+)")
  return  string.format("%02X.%02X.%02X.%02X", b1,b2,b3,b4)
end

function cidr_range( ip_range)
    local _,_, b1,b2,b3,b4,cidr = ip_range:find("(%d+)%.(%d+)%.(%d+)%.(%d+)/*(%d*)")
	if b1 == nil then return; end  
    local num_start = b1*math.pow(2,24) + b2*math.pow(2,16) + b3*math.pow(2,8) + b4*math.pow(2,0) 
    local num_end = num_start
    if #cidr > 0  then 
      num_end = num_start + math.pow(2, 32-tonumber(cidr)) -1 
    end

	return num_start, num_end 
end
