--Abstracts message passing between two clients
--author: TheOnlyOne
local messenger = require("messenger.message_constants")
local encoders = require("message_encoding")
local decoders = require("message_decoding")
local json = require("'bizhawk-co-op.json.json'")

--sends a message to the other clients
--client_socket is the socket the message is being sent over
--message_type is one of the types listed above
--the remaining arguments are specific to the type of message being sent
function messenger.send(client_socket, user, message_type, ...)
  --pack message type-specific arguments into a table
  local data = {...}
  --get the function that should encode the message
  local encoder = encoders[message_type]

  --encode the message
  local message = {
    ['user'] = user,
    ['msg_type'] = messenger.message_type_to_str[message_type],
    ['data'] = encoder(data)
  }
  --send the message
  printOutput("sending message: " .. message)

  -- Note: There's like 3 layers of json encode. this is NOT efficient for MW
  client_socket:send(json.encod(message) .. "\n")
end

--recieves a message from the other client, returning the message type
--along with a table containing the message type-specific information
--if nonblocking not set then this will block until a message is received
--or timeouts. Otheriwse it will return nil if no message is receive.
function messenger.receive(client_socket, nonblocking)
  if nonblocking then
    client_socket:settimeout(0)
  end

  --get the next message
  local message, err = client_socket:receive()

  if nonblocking then
    client_socket:settimeout(config.input_timeout)
  end

  if(message == nil) then
    if err == "timeout" then
      if not nonblocking then
        return messenger.ERROR, "[TIMEOUT]"
      else
        return nil
      end
    elseif err == "closed" then
      return messenger.ERROR, "[CLOSED]"
    else
      return messenger.ERROR, "[UNEXPECTED ERROR]"
    end
  end

  -- Note: There's like 3 layers of json decode. this is NOT efficient.
  local decoded = json.decode(message)

  --determine message type
  local msg_type = decoded['msg_type']
  local their_user = decoded['user']
  if (msg_type == nil) then
    printOutput("Recieved an unidentifiable message: " .. message)
    return nil
  end

  printOutput("message received: " .. message)

  local data = decoders[msg_type](decoded['data'])
  --return info
  return msg_type, their_user, data
end


return messenger