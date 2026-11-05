--!strict
-- Named events with a declared vocabulary.
--
-- Producers and consumers never require each other: they only share a topic
-- name. Every topic has to be declared when the bus is created, so a typo fails
-- loudly instead of quietly going nowhere.

local Signal = require(script.Parent.Signal)

local EventBus = {}
EventBus.__index = EventBus

export type Bus = typeof(setmetatable({} :: { _signals: { [string]: any } }, EventBus))

function EventBus.new(declared: { string }): Bus
	local signals: { [string]: any } = {}

	for _, name in declared do
		signals[name] = Signal.new(name)
	end

	return (setmetatable({ _signals = signals }, EventBus) :: any) :: Bus
end

function EventBus:_signal(name: string): any
	local signal = self._signals[name]
	if not signal then
		error(('unknown event "%s" - declare it in Topics'):format(tostring(name)), 3)
	end

	return signal
end

function EventBus:On(name: string, handler: (...any) -> ())
	return self:_signal(name):Connect(handler)
end

function EventBus:Once(name: string, handler: (...any) -> ())
	return self:_signal(name):Once(handler)
end

function EventBus:Emit(name: string, ...: any)
	self:_signal(name):Fire(...)
end

function EventBus:Wait(name: string): ...any
	return self:_signal(name):Wait()
end

return EventBus
