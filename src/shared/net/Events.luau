--!strict
-- Every message that crosses the client/server line.
--
-- Direction is documentation here, but Remotes checks it, so a server-to-client
-- event cannot be fired from the wrong side by accident.

return table.freeze({
	MazeReady = table.freeze({ direction = "ServerToClient" }),
	ClientReady = table.freeze({ direction = "ClientToServer" }),
})
