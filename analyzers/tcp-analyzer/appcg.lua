-- apps 
local bit=require'bit'

-- CXSessItem state bits, from TrisulDef.h
local SESS_SEEN_SYN_ACK = 0x0004
local SESS_A_END_SERVER = 0x0010
local SESS_Z_END_SERVER = 0x0020
local SESS_TIMEDOUT     = 0x0100
local SESS_TERMINATED   = 0x0800
local SESS_DONE         = bit.bor(SESS_TIMEDOUT, SESS_TERMINATED)

-- Flows whose setup latency has already been reported. Only flows still running are
-- held here; the entry is dropped when the flow is accounted, and every flow is
-- flushed once more as TERMINATED or TIMEDOUT before deletion, so this cannot grow.
local rtt_reported = {}

-- Below this a retransmission RATE is noise. Keep in step with tcp_analyzer.lua.
local MIN_PACKETS_FOR_RATE = 50

-- The "app" is the port the server listened on. The SYN / SYN-ACK direction tells
-- us which end that is, so use it rather than guessing. Fall back to the lower port
-- number when neither end was identified - that guess is wrong whenever the service
-- runs on a high port, and meaningless for peer to peer, but it is all we have.
-- Port keys are fixed width uppercase hex ("p-01BB"), so comparing them as strings
-- orders them exactly as comparing the port numbers would.
local function app_port(flowkey, state)
  if bit.band(state, SESS_A_END_SERVER) ~= 0 then return flowkey:porta() end
  if bit.band(state, SESS_Z_END_SERVER) ~= 0 then return flowkey:portz() end

  local pa, pz = flowkey:porta(), flowkey:portz()
  if pa < pz then return pa else return pz end
end

TrisulPlugin = {

  id =  {
    name = "TCP Ana. App CG ",
    description = "App counter group", 
  },

  countergroup = {
    control = {
      guid = "{24DBD78F-CBB6-4383-7A78-B2C734FC480F}",
      name = "TCP Analyzer Apps",
      description = "Measure setup time retrans timeouts for apps",
      bucketsize = 60,
    },

    meters = {
      {  0, T.K.vartype.AVERAGE,  20, 20, "us",   "Avg Latency",   			"us"},
      {  1, T.K.vartype.COUNTER,  20, 20, "pkts", "Retrans",       			"pkts" },
      {  2, T.K.vartype.AVERAGE,  20, 20, "pkts", "Retrans Rate			",  "percent" },
      {  3, T.K.vartype.COUNTER,  20, 20, "flows","Poor Quality Flows",     "flws" },
      {  4, T.K.vartype.COUNTER,  20, 20, "flows","Timeouts",               "flws" },
      {  5, T.K.vartype.COUNTER,  20, 20, "flows","Unidirectional",         "flws" },
    },  
  },

  sg_monitor  = {

    onflush = function(engine, newflow)

      local flowkey = newflow:flow() 

      if flowkey:protocol() ~= "06" then return end 

      local state    = newflow:state()
      local terminal = bit.band(state, SESS_DONE) ~= 0

      -- Setup latency is a one-shot measurement taken when the handshake completes,
      -- not a running total, so report it on the first flush that carries it rather
      -- than making a long running flow wait until it ends. setup_rtt is 0 when the
      -- handshake was never seen, and an AVERAGE counts a zero as a real sample.
      local setup_rtt = newflow:setup_rtt()
      local fkey, report_rtt
      if setup_rtt > 0 then
        fkey       = newflow:key()
        report_rtt = not rtt_reported[fkey]
      end

      -- nothing to do on an active pass that has already reported its latency
      if not (report_rtt or terminal) then return end

      local appport = app_port(flowkey, state)

      if report_rtt then
        engine:update_counter("{24DBD78F-CBB6-4383-7A78-B2C734FC480F}", appport, 0, setup_rtt)
        if not terminal then rtt_reported[fkey] = true end
      end

      -- Everything below is cumulative, and onflush fires again every
      -- ActiveTrackingAgeLimit while a flow is still running, so account it once,
      -- when the flow is finished: terminated by FIN/RST, or timed out.
      if not terminal then return end
      if fkey then rtt_reported[fkey] = nil end

      local packets       = newflow:az_packets() + newflow:za_packets()
      local retrans       = newflow:retransmissions()

      -- timeout : did not terminate with RST/FIN. Only count connections that were
      -- established - without a SYN-ACK there was never a session to time out.
      if bit.band(state, SESS_TIMEDOUT) ~= 0 and
         bit.band(state, SESS_SEEN_SYN_ACK) ~= 0 then
        engine:update_counter("{24DBD78F-CBB6-4383-7A78-B2C734FC480F}", appport , 4, 1)
        newflow:add_tag("BADQUALITY")
      end

      -- retransmitted packets is a volume, so it is counted for every flow
      engine:update_counter("{24DBD78F-CBB6-4383-7A78-B2C734FC480F}", appport, 1, retrans)

	  -- tag unidirectional also (maybe packet capture issue
	  if  (newflow:az_bytes() > 0 and newflow:za_bytes() == 0) or
	      (newflow:za_bytes() > 0 and newflow:az_bytes() == 0) then
		  engine:update_counter("{24DBD78F-CBB6-4383-7A78-B2C734FC480F}", appport, 5, 1)
	  end

      -- the rate needs a big enough sample, or it tags healthy flows
      if packets < MIN_PACKETS_FOR_RATE then return end

      local retrans_rate = 100*retrans/packets

      -- high retrans
      if retrans_rate > 10 then
        engine:update_counter("{24DBD78F-CBB6-4383-7A78-B2C734FC480F}", appport, 3, 1)
        newflow:add_tag("BADQUALITY")
      end

      engine:update_counter("{24DBD78F-CBB6-4383-7A78-B2C734FC480F}", appport, 2, retrans_rate)
    end,
  },
}
