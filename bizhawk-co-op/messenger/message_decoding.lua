local json = require("bizhawk-co-op.json.json")
local messenger = require("bizhawk-co-op.messenger.message_constants")

local function memory_decoder(msg)
    printOutput("memory_decoder message: " .. msg)
    return json.decode(msg)
end

local function ramevent_decoder(msg)
    printOutput("ramevent_decoder message: " .. msg)
    return json.decode(msg)
  end

local function config_decoder(msg)
    printOutput("json decoding the config_decoder message: " .. msg)

    local split = json.decode(msg)

	printOutput("successfuly decoded message")

    --get sync hash from message
    local their_sync_hash = split['sync_hash']
    local their_id = split['their_id']
    if (their_id ~= nil) then
        their_id = tonumber(their_id)
    end
   
    local ramconfig = split['ramconfig']

    if ramconfig ~= nil then
		printOutput("attempting to decode the ramconfig")
        ramconfig = json.decode(ramconfig)
    end

    return {their_sync_hash, their_id, ramconfig}
end


local function fake_decoder(data) return {} end
--describes how to decode a message for each message type
local decoders = {
    [messenger.MEMORY] = memory_decoder,
  
    [messenger.RAMEVENT] = ramevent_decoder,
  
    [messenger.PING] = fake_decoder,
  
    [messenger.CONFIG] = config_decoder,

    [messenger.QUIT] = fake_decoder
  }

  return decoders