-- A new FLOW TRACKER
-- that tracks poor quality flows with > 5% retransmission rate 

TrisulPlugin = {

  id =  {
    name = "Poor Quality",
    description = "Poor quality flows > 5% retrans paylaod"
  },

  -- flowtracker block  to track poor quality flows  > 5% retrans rate 
  --
  flowtracker  = {

    control = {
      name = "POOR QUALITY",
      description = "Only tracks flows with > 5% retrans rate ",
      bucketsize = 300, -- streaming window of 300 seconds
      count = 200,      -- track 200 top-K per window 
    },


    -- WHEN CALLED: called for EACH flow after completion or periodically for LONG running flows
    -- return 
    --    0 : not interested in this flow (maybe uninteresting IP, port, etc)
    --    m : a number M that is the metric used in the Top-K for this flow tracker (eg, total volume )
    --
    getmetric = function(engine, newflow) 
      local retrans_rate = 100*newflow:retransmissions()/(newflow:az_packets()+newflow:az_packets());
      if retrans_rate > 5 then 
        return retrans_rate 
      else
        return 0
      end 
    end,

  },

}
