local bit=require'bit'

local CG = "{E45623ED-744C-4053-1401-84C72EE49D3B}"

-- CXSessItem state bits, from TrisulDef.h
local SESS_SEEN_SYN_ACK = 0x0004
local SESS_TIMEDOUT     = 0x0100
local SESS_TERMINATED   = 0x0800
local SESS_DONE         = bit.bor(SESS_TIMEDOUT, SESS_TERMINATED)

-- Flows whose setup latency has already been reported, so a flow that outlives
-- several flushes does not feed the same measurement to the AVERAGE meter again.
-- Only flows still running are held here; the entry is dropped the moment the flow
-- is accounted, and every flow is flushed once more as TERMINATED or TIMEDOUT
-- before it is deleted, so this cannot accumulate.
local rtt_reported = {}

TrisulPlugin = {

  id =  {
    name = "TCP Analysis",
    description = "Measure and tag TCP parameters per host "
  },

  countergroup = {
    control = {
      guid = CG,
      name = "TCP Analyzer",
      description = "Measure setup time retrans timeouts",
      bucketsize = 60,
    },

    meters = {
      {  0, T.K.vartype.AVERAGE,  20, 20, "us",   "Avg Latency Internal",   "us"},
      {  1, T.K.vartype.AVERAGE,  20, 20, "us",   "Avg Latency External",   "us" },
      {  2, T.K.vartype.COUNTER,  20, 20, "pkts", "Retrans Internal",       "pkts"},
      {  3, T.K.vartype.COUNTER,  20, 20, "pkts", "Retrans External",       "pkts" },
      {  4, T.K.vartype.AVERAGE,  20, 20, "pkts", "Retrans Rate Internal",  "percent"},
      {  5, T.K.vartype.AVERAGE,  20, 20, "pkts", "Retrans Rate External",  "percent" },
      {  6, T.K.vartype.COUNTER,  20, 20, "flows","Poor Quality Flows",     "flws" },
      {  7, T.K.vartype.COUNTER,  20, 20, "flows","Timeouts",               "flws" },
      {  8, T.K.vartype.COUNTER,  20, 20, "flows","Unidirectional",         "flws" },
    },
  },

  sg_monitor  = {

    onflush = function(engine, newflow)

      local flowkey = newflow:flow()

      if flowkey:protocol() ~= "06" then return end

      local state    = newflow:state()
      local terminal = bit.band(state, SESS_DONE) ~= 0

      -- Setup latency is a one-shot measurement, taken when the handshake completes,
      -- not a running total - so report it on the first flush that carries it. A long
      -- running flow gets its connect time into the average right away instead of
      -- waiting hours to finish. setup_rtt is 0 when the handshake was never seen,
      -- and an AVERAGE meter counts a zero as a real sample, so skip those.
      local setup_rtt = newflow:setup_rtt()
      local fkey, report_rtt
      if setup_rtt > 0 then
        fkey       = newflow:key()
        report_rtt = not rtt_reported[fkey]
      end

      -- nothing to do on an active pass that has already reported its latency
      if not (report_rtt or terminal) then return end

      -- addresses in Trisul key form - no formatting, no reparsing, and the
      -- same code path for IPv4 and IPv6
      local ipa = flowkey:ipa()
      local ipz = flowkey:ipz()

      -- meters 0,2,4 are the Internal (homenet) set, 1,3,5 the External one
      local a = T.host:is_homenet_key(ipa) and 0 or 1
      local z = T.host:is_homenet_key(ipz) and 0 or 1

      if report_rtt then
        engine:update_counter(CG, ipa, 0+a, setup_rtt)
        engine:update_counter(CG, ipz, 0+z, setup_rtt)
        if not terminal then rtt_reported[fkey] = true end
      end

      -- Everything below is cumulative. onflush fires again every
      -- ActiveTrackingAgeLimit for flows that are still running, and the session
      -- counters are never reset between flushes, so accounting them on an active
      -- pass would add the running totals again every time. Account them once, when
      -- the flow is finished: terminated by FIN/RST, or timed out.
      if not terminal then return end
      if fkey then rtt_reported[fkey] = nil end

      local packets       = newflow:az_packets() + newflow:za_packets()
      local retrans       = newflow:retransmissions()
      local retrans_rate  = packets > 0 and 100*retrans/packets or 0

      -- high retrans
      if retrans_rate  > 5  then
        engine:update_counter(CG, ipa, 6, 1)
        engine:update_counter(CG, ipz, 6, 1)
        newflow:add_tag("BADQUALITY")
      end

      -- timeout : did not terminate with RST/FIN. Only count connections that were
      -- established - without a SYN-ACK there was never a session to time out, and
      -- an unanswered SYN is a failed connection, not a timeout.
      if bit.band(state, SESS_TIMEDOUT) ~= 0 and
         bit.band(state, SESS_SEEN_SYN_ACK) ~= 0 then
        engine:update_counter(CG, ipa, 7, 1)
        engine:update_counter(CG, ipz, 7, 1)
        newflow:add_tag("BADQUALITY")
      end

      -- traffic in one direction only. Usually asymmetric routing or a tap that sees
      -- just one leg, so it says more about the capture than about the network - it
      -- is counted but deliberately not tagged BADQUALITY.
      local az_bytes = newflow:az_bytes()
      local za_bytes = newflow:za_bytes()
      if (az_bytes > 0 and za_bytes == 0) or
         (za_bytes > 0 and az_bytes == 0) then
        engine:update_counter(CG, ipa, 8, 1)
        engine:update_counter(CG, ipz, 8, 1)
      end

      engine:update_counter(CG, ipa, 2+a, retrans)
      engine:update_counter(CG, ipa, 4+a, retrans_rate)

      engine:update_counter(CG, ipz, 2+z, retrans)
      engine:update_counter(CG, ipz, 4+z, retrans_rate)

    end,
  },
}
