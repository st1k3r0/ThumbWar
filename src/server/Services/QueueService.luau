--!strict
-- Площадка входа в очередь: игрок встал на неё — попадает в очередь,
-- сошёл, умер или вышел из игры — выбывает. Табличка над площадкой показывает
-- текущее число ожидающих.
--
-- Список ожидающих здесь не хранится: им владеет MatchmakingService.
-- Этот сервис — только детект присутствия и табличка.
--
-- Присутствие определяется опросом объёма над площадкой, а не Touched/TouchEnded:
-- TouchEnded не срабатывает надёжно, когда персонаж стоит неподвижно,
-- и игрок оставался бы в очереди после ухода.

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Services = ServerScriptService.Server.Services
local MatchmakingService = require(Services.MatchmakingService)

local QueueService = {}

-- Технические константы детекта, не влияют на баланс.
local POLL_INTERVAL = 0.25
-- Высота объёма должна с запасом перекрывать прыжок: персонаж поднимается
-- примерно на 7 стадов, и на верхушке дуги он обязан оставаться внутри объёма,
-- иначе прыжок на площадке читается как уход с неё.
local DETECTION_HEIGHT = 24

local pad: BasePart
local countLabel: TextLabel

-- Кто стоит на площадке прямо сейчас. Это состояние детекта, а не очередь:
-- в очередь игрок ставится в момент входа на площадку и снимается при сходе.
-- Иначе игрок, уже забранный в матч, но всё ещё стоящий на площадке,
-- добавлялся бы в очередь заново на каждом опросе.
local onPad: { [Player]: boolean } = {}

local lastDisplayedCount = -1

local overlapParams = OverlapParams.new()

local function updateSign()
	local count = MatchmakingService.GetCount()
	if count == lastDisplayedCount then
		return
	end

	lastDisplayedCount = count
	countLabel.Text = `В ОЧЕРЕДИ: {count}`
end

-- Возвращает множество игроков, стоящих на площадке прямо сейчас.
local function getPlayersOnPad(): { [Player]: boolean }
	local center = pad.CFrame * CFrame.new(0, pad.Size.Y / 2 + DETECTION_HEIGHT / 2, 0)
	local size = Vector3.new(pad.Size.X, DETECTION_HEIGHT, pad.Size.Z)

	local present: { [Player]: boolean } = {}

	for _, part in Workspace:GetPartBoundsInBox(center, size, overlapParams) do
		local character = part.Parent
		if character == nil then
			continue
		end

		local player = Players:GetPlayerFromCharacter(character)
		if player == nil then
			continue
		end

		-- Мёртвый персонаж не считается стоящим на площадке.
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid == nil or humanoid.Health <= 0 then
			continue
		end

		present[player] = true
	end

	return present
end

local function poll()
	local present = getPlayersOnPad()

	for player in present do
		if not onPad[player] then
			onPad[player] = true
			MatchmakingService.Add(player)
		end
	end

	for player in onPad do
		if not present[player] then
			onPad[player] = nil
			MatchmakingService.Remove(player)
		end
	end

	updateSign()
end

local function onPlayerRemoving(player: Player)
	onPad[player] = nil
	-- Из самой очереди вышедшего игрока убирает MatchmakingService.
end

function QueueService.Init()
	local zone = Workspace:WaitForChild("Lobby"):WaitForChild("Zones"):WaitForChild("Casual")

	pad = zone:WaitForChild("Platform") :: BasePart
	countLabel = zone:WaitForChild("Sign"):WaitForChild("Label"):WaitForChild("Count") :: TextLabel

	-- Сама площадка в выборку попадать не должна.
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = { pad }

	Players.PlayerRemoving:Connect(onPlayerRemoving)

	updateSign()

	task.spawn(function()
		while true do
			task.wait(POLL_INTERVAL)
			poll()
		end
	end)
end

return QueueService
