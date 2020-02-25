--author: TheOnlyOne

local socket = require("socket")
local http = require("socket.http")
sync = require("bizhawk-co-op.sync")

local host = {}

local server = nil
host.clients = {}
host.users = {}
host.status = 'Idle'
host.locked = false
host.hostname = nil
host.client_ping = {}
local itemcount

function host.start()
	printOutput("host.start beginning")
	if (host.status == 'Host') then
		if host.locked then
			local roomstr, err = http.request('https://us-central1-mzm-coop.cloudfunctions.net/create' ..
				'?user=dwooda' .. '&pass=a')
			if (err == 200) then
				host.locked = false
				updateGUI()
				printOutput('Room unlocked.')
			else
				printOutput('Error unlocking room [Code: ' .. (err or '') .. ']')
			end
		else
			local roomstr, err = http.request('https://us-central1-mzm-coop.cloudfunctions.net/destroy' ..
				'?user=dwooda' .. '&pass=a')
			if (err == 200) then
				host.locked = true
				updateGUI()
				printOutput('Room locked.')
			else
				printOutput('Error locking room [Code: ' .. (err or '') .. ']')
			end
		end

		return
	end

	local ramcontroller = sync.loadramcontroller()
	if (ramcontroller == false) then
		return
	end

	if ramcontroller.getConfig then
		config.ramconfig = ramcontroller.getConfig()
		if (config.ramconfig == false) then
			return
		end
	else 
		config.ramconfig = {}
	end

	itemcount = ramcontroller.itemcount
	if (itemcount == false) then
		return
	end

	if not config.user or config.user == '' then
		printOutput('Set your username before creating a room.')
		return false
	end

	if not config.port or config.port == '' then
		config.port = 50000
	end

	host.status = 'Host'
	host.locked = true
	updateGUI()

	coroutine.yield()

	printOutput("creating the server")
	--create the server
	server = socket.bind("*", config.port, 1)
	if (server == nil) then
		printOutput("Error creating server. Port is probably in use.")
		host.status = 'Idle'
		host.locked = false
		updateGUI()
		return false
	end

	local ip, setport = server:getsockname()
	server:settimeout(0) -- non-blocking
	printOutput("Created server on port " .. setport)

	local roomstr, err = http.request('https://us-central1-mzm-coop.cloudfunctions.net/create?user=dwooda&pass=a')
	if (err == 200) then
		printOutput('Room initialized.')
	else
		printOutput('Error creating room [Code: ' .. (err or '') .. ']')
		host.close()
		return false
	end

	host.locked = false
	host.users[config.user] = 1
	updateGUI()

	return true
end


function host.listen()
	if (server == nil or host.locked) then
		return false
	end

	--wait for the connection from the client
	local client, err = server:accept()

	--end execution if a client does not connect in time
	if (client == nil) then
		if err ~= "timeout" then
            printOutput("Server error: ", err)
	  		host.close()
        end
	  	return false
	end

	local clientID = 2
	while (true) do
	 	if (host.clients[clientID] == nil) then
	 		break
	 	end
		clientID = clientID + 1
	end
	
	--display the client's information
	printOutput("Player " .. clientID .. " connecting...")

	-- make sure we don't block forever waiting for input
	client:settimeout(5)
	client:setoption('linger', {['on']=false, ['timeout']=0})

	--sync the gameplay
	local success, their_user = nil

	--Working around lua's awkward circular reference issues
	success, their_user, host = pcall(sync.syncconfig, client, clientID, host)

	if success and their_user then
		host.clients[clientID] = client
		host.users[their_user] = clientID
		host.client_ping[clientID] = 4
	else
		if not success then
			printOutput("Error in Listen: " .. their_user)
		end
		client:close()
		return false
	end

	printOutput(their_user .. " connected.")

	-- send item lists
	local clientMap = {[0]=1}
	local clientCount = 1
	for id,_ in pairs(host.clients) do
		clientMap[clientCount] = id
		clientCount = clientCount + 1
	end

	local itemlist = {}
	math.randomseed(os.time())
	math.random(itemcount)
	for i=0,(itemcount-1) do
		itemlist[i] = clientMap[i % clientCount]
	end

	for i=1,(itemcount-1) do
		j = math.random(i + 1) - 1 -- 0 to i inclusive
		itemlist[i], itemlist[j] = itemlist[j], itemlist[i]
	end

	sync.sendItems(itemlist)

	updateGUI()
	return clientID
end


function host.join()
	printOutput("host.join")
	if (sync.loadramcontroller() == false) then
		return
	end

	if not config.room or config.room == '' then
		printOutput('Select a room to join.')
		return false
	end

	if config.room == '(Custom IP)' and (not config.hostname or config.hostname == '') then
		printOutput('Enter the IP to join.')
		return false
	end

	if not config.user or config.user == '' then
		printOutput('Set your username before joining a room.')
		return false
	end

	if not config.port or config.port == '' then
		config.port = 50000
	end

	host.close()
	host.status = 'Join'
	host.locked = true
	updateGUI()

	coroutine.yield()

	if config.room ~= '(Custom IP)' then
		local err
		config.hostname, err = http.request('https://us-central1-mzm-coop.cloudfunctions.net/join' ..
			'?user=' .. 'dwooda' ..
			'&pass=' .. 'a')
		if (err == 200) then
			printOutput('Joining ' .. config.room)
		else
			printOutput('Error joining room [Code: ' .. (err or '') .. ']')
			host.status = 'Idle'
			host.locked = false
			updateGUI()
			return
		end
	end

	local client, err = socket.connect(config.hostname, config.port)
	if (client == nil) then
		printOutput("Connection failed: " .. err)
		host.status = 'Idle'
		host.locked = false
		updateGUI()
		return
	end

	--display the server's information
	local peername, peerport = client:getpeername()
	printOutput("Joined room " .. config.room)
	printOutput("peer name: " .. peername .. " peerport: " .. peerport)
	--make sure we don't block waiting for a response
	client:settimeout(5)
	client:setoption('linger', {['on']=false, ['timeout']=0})

	coroutine.yield()
	coroutine.yield()

	--sync the gameplay
	local success, client_user, hostname = sync.syncconfig(client, nil)
	host.hostname = hostname

	if (success and client_user and hostname) then
		host.clients[1] = client
		host.client_ping[1] = 4
		host.users[host.hostname] = 1
	else
		client:close()
		host.close()
		updateGUI()
	end
	printOutput("end host.join")
	return
end


--when the script finishes, make sure to close the connection
function host.close()
	printOutput("closing connection")

	host.status = 'Idle'
	host.locked = false

	local changed = false

	for i,client in pairs(host.clients) do
		client:close()
		host.clients[i] = nil
		changed = true
	end
	host.users = {}
	host.client_ping = {}

	if (server ~= nil) then
		server:close()
		changed = true

		local roomstr, err = http.request('https://us-central1-mzm-coop.cloudfunctions.net/destroy' ..
			'?user=' .. 'dwooda' ..
			'&pass=' .. 'a')
		if (err == 200) then
			printOutput('Room closed.')
		else
			printOutput('Error closing room [Code: ' .. (err or '') .. ']')
		end
	end
	server = nil

	if changed then
		printOutput("Server closed.")
		updateGUI()
	end
	printOutput("end host.close()")
end


function host.connected()
    for _, _ in pairs(host.clients) do
        return true
    end
    return false
end


function host.ishost()
	return ((host.connected()) and (host.server ~= nil))
end


--Get the list of Rooms
function host.getRooms()
	printOutput("getting rooms")
	local roomstr, err = http.request('https://us-central1-mzm-coop.cloudfunctions.net/getrooms')
	if (err == 200) then
		if (roomstr == '') then
			return false
		else
			return strsplit(roomstr, ',')
		end
	else
		printOutput('Error fetching room list [Code ' .. (err or '') .. ']')
		return false
	end
end


return host