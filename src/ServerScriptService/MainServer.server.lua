local Players = game:GetService("Players")

local function onPlayerAdded(player)
	print(player.Name .. " joined the game!")
end

Players.PlayerAdded:Connect(onPlayerAdded)

for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end
