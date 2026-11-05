--!strict
-- A tiny event emitter.
--
-- It touches no Roblox instances, so the same module runs on the server, on the
-- client and inside Jest. A listener that throws is reported and skipped, so one
-- broken subscriber never stops the others.

export type Handler = (...any) -> ()
export type Connection = { Disconnect: (self: Connection) -> () }

type Record = { handler: Handler, connected: boolean }

local Signal = {}
Signal.__index = Signal

export type Signal = typeof(setmetatable({} :: { name: string, _records: { Record } }, Signal))

function Signal.new(name: string?): Signal
	local self = setmetatable({ name = name or "Signal", _records = {} :: { Record } }, Signal)
	return (self :: any) :: Signal
end

function Signal:Connect(handler: Handler): Connection
	local record: Record = { handler = handler, connected = true }
	table.insert(self._records, record)

	return {
		Disconnect = function()
			if not record.connected then
				return
			end

			record.connected = false
			local index = table.find(self._records, record)
			if index then
				table.remove(self._records, index)
			end
		end,
	}
end

function Signal:Once(handler: Handler): Connection
	local connection: Connection

	connection = self:Connect(function(...)
		connection.Disconnect()
		handler(...)
	end)

	return connection
end

function Signal:Fire(...: any)
	for _, record in table.clone(self._records) do
		if record.connected then
			local ok, err = pcall(record.handler, ...)
			if not ok then
				warn(("[%s] listener failed: %s"):format(self.name, tostring(err)))
			end
		end
	end
end

function Signal:Wait(): ...any
	local thread = coroutine.running()
	local connection: Connection

	connection = self:Connect(function(...)
		connection.Disconnect()
		task.spawn(thread, ...)
	end)

	return coroutine.yield()
end

function Signal:Count(): number
	return #self._records
end

function Signal:Destroy()
	for _, record in table.clone(self._records) do
		record.connected = false
	end

	table.clear(self._records)
end

return Signal
