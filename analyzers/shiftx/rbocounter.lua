--
-- rbo - RBO counter 
--
-- TYPE:        FRONTEND SCRIPT
-- PURPOSE:     counter group, 
-- {22B6E494-382B-47D5-D914-591CF8572343}
-- DEFINE_GUID(GUID_xxx,0x22B6E494,0x382B,0x47D5,0xD9,0x14,0x59,0x1C,0xF8,0x57,0x23,0x43);

-- JSD - Jensen-Shannon Distance
-- RBO - Rank-Biased Overlap
-- Novelty - Novelty score
-- Composite - Composite score
-- Alert - Alert score
-- 
TrisulPlugin = { 


  -- the ID block, you can skip the fields marked 'optional '
  -- 
  id =  {
    name = "TopKShift",
    description = "RBO shift scoring from top-K keys", -- optional
  },
    -- countergroup info block
    countergroup = {

      control = {
        guid = "{22B6E494-382B-47D5-D914-591CF8572343}",
        name = "ShiftX Metrics",
        description = "Shift scoring metrics",
        bucketsize = 30,
      },
  
      -- meters table
      -- id, type of meter, toppers to track, bottom-ers to track, Name, units, units-short
      --60
      meters = {
        {  0, T.K.vartype.GAUGE, 1000, 0, "RBO", "RBO Score",    "score" },
        {  1, T.K.vartype.GAUGE, 1000, 0, "Novelty", "Novelty Score",    "score" },
        {  2, T.K.vartype.GAUGE, 1000, 0, "JSD", "JSD Score",    "score" },
        {  3, T.K.vartype.GAUGE, 1000, 0, "Composite", "Composite Score",    "score" },
        {  4, T.K.vartype.GAUGE, 1000, 0, "Alert", "Alert",    "trigger" },
      },
  
    },
  }