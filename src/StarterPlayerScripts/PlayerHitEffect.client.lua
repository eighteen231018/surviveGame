-- 玩家受击效果 - 客户端（屏幕闪红 + 镜头震动）
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer

local playerHitEvent = ReplicatedStorage:WaitForChild("PlayerHitEvent")

-- 创建屏幕闪红UI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "HitEffectGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local flashFrame = Instance.new("Frame")
flashFrame.Name = "HitFlash"
flashFrame.Size = UDim2.new(1, 0, 1, 0)
flashFrame.BackgroundColor3 = Color3.new(1, 0, 0)
flashFrame.BackgroundTransparency = 1
flashFrame.BorderSizePixel = 0
flashFrame.ZIndex = 999
flashFrame.Parent = screenGui

playerHitEvent.OnClientEvent:Connect(function()
	-- 屏幕闪红
	flashFrame.BackgroundTransparency = 0.5
	task.delay(0.15, function()
		flashFrame.BackgroundTransparency = 1
	end)

	-- 镜头震动
	local camera = workspace.CurrentCamera
	if camera then
		local originalCF = camera.CFrame
		local shakeOffset = Vector3.new(
			(math.random() - 0.5) * 0.5,
			(math.random() - 0.5) * 0.5,
			(math.random() - 0.5) * 0.5
		)
		camera.CFrame = originalCF * CFrame.new(shakeOffset)
		task.delay(0.1, function()
			if camera and camera.Parent then
				camera.CFrame = originalCF
			end
		end)
	end
end)