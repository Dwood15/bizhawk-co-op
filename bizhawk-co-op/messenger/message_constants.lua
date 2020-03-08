local messenger = {}

--list of message types
messenger.ERROR = -1
messenger.MEMORY = 0
messenger.CONFIG = 1
messenger.PING = 2
messenger.QUIT = 4
messenger.RAMEVENT = 5

messenger.message_type_to_str = {
    [messenger.MEMORY] = "mem",
    [messenger.RAMEVENT] = "ram",
    [messenger.PING] = "ping",
    [messenger.CONFIG] = "conf",
    [messenger.QUIT] = "quit",
  }

  --inverse of the previous table
messenger.str_to_message_type = {}

for t, c in pairs(messenger.message_type_to_str) do
    messenger.message_type_to_str[c] = t
end

return messenger