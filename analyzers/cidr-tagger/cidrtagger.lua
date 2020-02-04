--  CIDR tagger 
-- 
--  adds tags for /25/26/27/28  - by default we have tags for /16 and /24
-- 
local bit = require("bit")
require 'mkconfig'


function gen_subnet_tags( trisul_format_ip,   cidr_masks )

	local b1= tonumber(trisul_format_ip:sub(1,2),16)
	local b2= tonumber(trisul_format_ip:sub(4,5),16)
	local b3= tonumber(trisul_format_ip:sub(7,8),16)
	local b4= tonumber(trisul_format_ip:sub(10,11),16)
	local k=  bit.lshift(b1, 24) + bit.lshift(b2, 16) + bit.lshift(b3, 8) + bit.lshift(b4, 0)
	
	local ret = {}
	for _,maskbits in ipairs( cidr_masks) 
	do
		local mask= bit.bnot(bit.lshift(1,(32-maskbits))-1)
		local netnum = bit.band(k,mask)
		local i1 = bit.band(bit.rshift(netnum,24),0xff)
		local i2 = bit.band(bit.rshift(netnum,16),0xff)
		local i3 = bit.band(bit.rshift(netnum,8),0xff)
		local i4 = bit.band(bit.rshift(netnum,0),0xff)
		table.insert(ret, "[cidr]"..i1..'.' ..i2.. '.'..i3..'.'..i4..'/'..maskbits )
	end

	return ret
end


TrisulPlugin = {

	id =  {
		name = "CIDR tagger", 
		description = "Adds CIDR tags to each flow with flexibility",
	},

	onload = function()
		T.config = make_config(
          T.env.get_config("App>DBRoot").."/config/trisulnsm_cidr-tagger.lua",
          {
		  	-- only tag these subnet networks
            tag_masks={26,27,28},

			-- only tag internalhosts 
		    tag_internal_hosts_only = true
          } )
	end,


	sg_monitor  = {

		onflush  = function(engine, newflow)
			
			-- only IPv4 are processed 
			if newflow:flow():flow_type() == 'B'  or newflow:flow():flow_type() == 'D'  then 
			   	return
			end 

			local ipa = newflow:flow():ipa()
			if not T.config.tag_internal_hosts_only or T.host:is_homenet_key(ipa) then 
				for _,tag in ipairs( gen_subnet_tags( ipa, T.config.tag_masks)) do 
					newflow:add_tag(tag)
				end 
			end 

			local ipz = newflow:flow():ipz()
			if not T.config.tag_internal_hosts_only or T.host:is_homenet_key(ipz) then
				for _,tag in ipairs( gen_subnet_tags( ipz, T.config.tag_masks)) do 
					newflow:add_tag(tag)
				end 
			end
		end,
	},

}
