--!strict
-- Арена матча: перенос двух игроков на точки друг напротив друга и фиксация
-- их персонажей на местах. Пока игрок закреплён, он не ходит и не прыгает.
--
-- Сервис не решает, когда матч начинается и заканчивается: он только ставит
-- игроков на места и отпускает по команде. Жизненным циклом матча владеет
-- матчевая логика, она же обязана вызвать Release.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local matchCamera = Remotes.MatchCamera :: RemoteEvent

local ArenaService = {}

-- Насколько поднять персонажа над точкой, чтобы он не застрял в полу.
local SPAWN_HEIGHT = 3

local slotOne: BasePart
local slotTwo: BasePart
local cameraAnchor: BasePart

-- Состояние закреплённых игроков: что нужно вернуть при освобождении.
type LockedState = {
	character: Model,
	rootPart: BasePart,
	humanoid: Humanoid,
	walkSpeed: number,
	jumpHeight: number,
	wasAnchored: boolean,
}

local locked: { [Player]: LockedState } = {}

local function getCharacterParts(player: Player): (Model?, BasePart?, Humanoid?)
	local character = player.Character
	if character == nil then
		return nil, nil, nil
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if rootPart == nil or humanoid == nil then
		return nil, nil, nil
	end

	return character, rootPart, humanoid
end

-- Ставит персонажа на точку лицом к противоположной и закрепляет его.
local function lockAt(player: Player, slot: BasePart, facing: BasePart): boolean
	local character, rootPart, humanoid = getCharacterParts(player)
	if character == nil or rootPart == nil or humanoid == nil then
		return false
	end

	local standPosition = slot.Position + Vector3.new(0, slot.Size.Y / 2 + SPAWN_HEIGHT, 0)
	local lookTarget = Vector3.new(facing.Position.X, standPosition.Y, facing.Position.Z)

	locked[player] = {
		character = character,
		rootPart = rootPart,
		humanoid = humanoid,
		walkSpeed = humanoid.WalkSpeed,
		jumpHeight = humanoid.JumpHeight,
		wasAnchored = rootPart.Anchored,
	}

	-- Сначала переносим, потом закрепляем: закреплённый персонаж не двигается.
	rootPart.CFrame = CFrame.lookAt(standPosition, lookTarget)

	humanoid.WalkSpeed = 0
	humanoid.JumpHeight = 0
	rootPart.Anchored = true

	-- Камера матча. Обоим игрокам уходит ОДИН И ТОТ ЖЕ CFrame якоря:
	-- он не зависит от того, на какой точке стоит игрок, и не зеркалится.
	matchCamera:FireClient(player, cameraAnchor.CFrame)

	return true
end

-- Возвращает персонажу подвижность. Безопасно вызывать повторно.
function ArenaService.Release(player: Player): boolean
	local state = locked[player]
	if state == nil then
		return false
	end

	locked[player] = nil

	-- Персонаж мог быть уничтожен, пока игрок стоял на арене.
	if state.rootPart.Parent ~= nil then
		state.rootPart.Anchored = state.wasAnchored
	end

	if state.humanoid.Parent ~= nil then
		state.humanoid.WalkSpeed = state.walkSpeed
		state.humanoid.JumpHeight = state.jumpHeight
	end

	-- nil означает "верни обычную камеру".
	matchCamera:FireClient(player, nil)

	return true
end

function ArenaService.IsLocked(player: Player): boolean
	return locked[player] ~= nil
end

-- Переносит обоих игроков на арену и закрепляет их друг напротив друга.
-- Если хотя бы одного поставить не удалось, откатывает обоих: половина пары
-- на арене — это хуже, чем несостоявшийся перенос.
function ArenaService.Place(playerA: Player, playerB: Player): boolean
	local placedA = lockAt(playerA, slotOne, slotTwo)
	local placedB = lockAt(playerB, slotTwo, slotOne)

	if not placedA or not placedB then
		ArenaService.Release(playerA)
		ArenaService.Release(playerB)
		return false
	end

	return true
end

local function onPlayerRemoving(player: Player)
	locked[player] = nil
end

local initialized = false

function ArenaService.Init()
	if initialized then
		return
	end
	initialized = true

	local arena = Workspace:WaitForChild("Arena")
	local slots = arena:WaitForChild("Slots")

	slotOne = slots:WaitForChild("Slot1") :: BasePart
	slotTwo = slots:WaitForChild("Slot2") :: BasePart
	cameraAnchor = arena:WaitForChild("CameraAnchor") :: BasePart

	Players.PlayerRemoving:Connect(onPlayerRemoving)
end

return ArenaService
