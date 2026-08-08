--!strict
-- Камера матча: фиксированный ракурс сбоку, одинаковый для обоих игроков.
--
-- Камера НЕ зеркалится под игрока. Сервер присылает готовый CFrame, один и тот же
-- для обеих сторон, и клиент ставит его как есть — никаких разворотов и отражений
-- в зависимости от того, на какой точке стоит игрок. Иначе "влево" на экране
-- означало бы разное у двоих, и вся боевая механика превратилась бы в лотерею.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local matchCamera = Remotes.MatchCamera :: RemoteEvent

local CameraController = {}

local player = Players.LocalPlayer

-- Что вернуть камере после матча.
local restoreType: Enum.CameraType? = nil

local function enable(cameraCFrame: CFrame)
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end

	if restoreType == nil then
		restoreType = camera.CameraType
	end

	camera.CameraType = Enum.CameraType.Scriptable
	-- CFrame ставится ровно тот, что прислал сервер.
	camera.CFrame = cameraCFrame
end

local function disable()
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end

	camera.CameraType = restoreType or Enum.CameraType.Custom
	restoreType = nil

	local character = player.Character
	if character ~= nil then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid ~= nil then
			camera.CameraSubject = humanoid
		end
	end
end

local initialized = false

function CameraController.Init()
	if initialized then
		return
	end
	initialized = true

	matchCamera.OnClientEvent:Connect(function(cameraCFrame: CFrame?)
		-- nil означает "матч закончился, верни обычную камеру".
		if cameraCFrame == nil then
			disable()
		else
			enable(cameraCFrame)
		end
	end)
end

return CameraController
