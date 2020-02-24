local json = require("bizhawk-co-op.json.json")
local messenger = require("message_constants")

local function memory_encoder(data)
    local to_encode = {}
    for adr, val in pairs(data[1]) do
      to_encode[adr] = val
    end
  
    return json.encode(to_encode)
  end
  
  local function ramevent_encoder(data)
    return json.encode(data[1])
  end
  
  
  local function config_encoder(data)
    local to_encode = {}
    to_encode['sync_hash'] = data[1]
    to_encode['ramconfig'] = data[3]
  
    local their_id = data[2]
    if their_id ~= nil then
      to_encode['their_id'] = their_id
    else
      to_encode['sync_hash'] = data[1]
      to_encode['their_id'] = their_id
      to_encode['ramconfig'] = json.encode(data[3])
    end
    return json.encode(to_encode)
  end
  
  local function empty_encoder(data) return "" end
  
  --describes how to encode a message for each message type
local encoders = {
    --an input message expects 2 arguments:
    --a table containing the inputs pressed,
    --and the frame this input should be pressed on
    [messenger.MEMORY] = memory_encoder,

    [messenger.RAMEVENT] = ramevent_encoder,

    [messenger.PING] = empty_encoder,

    --a config message expects 1 arguments:
    --the hash of the code used in gameplay sync
    [messenger.CONFIG] = config_encoder,

    --a quit message expects no arguments
    [messenger.QUIT] = empty_encoder
}

return encoders