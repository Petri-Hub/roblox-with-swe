--!strict
-- The vocabulary of the event bus.
--
-- Both realms declare the whole list, so the server and the client cannot drift
-- apart. Adding an event means adding it here first.

return table.freeze({
	-- server, about the house
	MazeBuilt = "MazeBuilt",
	MazeFailed = "MazeFailed",
	-- server, about people
	PlayerJoined = "PlayerJoined",
	-- both, about the client being ready to receive the world
	MazeReady = "MazeReady",
	ClientReady = "ClientReady",
})
