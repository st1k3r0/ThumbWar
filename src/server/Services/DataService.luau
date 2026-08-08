--!strict
-- Загрузка, хранение и освобождение профилей игроков поверх ProfileStore.
-- Если профиль не загрузился — игрок кикается, а не пускается с пустыми данными:
-- иначе его прогресс будет перезаписан дефолтами шаблона.

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ServerScriptService.Server.Modules
local ProfileStore = require(Modules.ProfileStore)
local ProfileTemplate = require(ReplicatedStorage.Shared.ProfileTemplate)

local PLAYER_STORE_NAME = "PlayerData"
local KICK_MESSAGE = "Couldn't load your data. Please rejoin — this way your progress won't be overwritten."

local PlayerStore = ProfileStore.New(PLAYER_STORE_NAME, ProfileTemplate)

local Profiles: { [Player]: any } = {}

-- Подписчики на изменение данных. Нужны, чтобы отображение (leaderstats и т.п.)
-- обновлялось само, а DataService не знал о тех, кто его слушает.
local changedListeners: { (player: Player) -> () } = {}

local function notifyChanged(player: Player)
	for _, listener in changedListeners do
		-- Упавший подписчик не должен ломать запись данных.
		local ok, err = pcall(listener, player)
		if not ok then
			warn(`[DataService] Подписчик на изменение профиля упал: {err}`)
		end
	end
end

local DataService = {}

-- Подписка на изменение данных игрока. Вызывается и при первой загрузке профиля.
function DataService.OnProfileChanged(callback: (player: Player) -> ())
	table.insert(changedListeners, callback)
end

-- Ручное уведомление для кода, который меняет profile.Data напрямую,
-- минуя методы этого сервиса.
function DataService.NotifyChanged(player: Player)
	notifyChanged(player)
end

-- Возвращает профиль игрока или nil, если он ещё не загружен / уже освобождён.
function DataService.GetProfile(player: Player)
	return Profiles[player]
end

function DataService.AddCoins(player: Player, amount: number): boolean
	local profile = Profiles[player]
	if profile == nil then
		return false
	end
	profile.Data.Coins += amount
	notifyChanged(player)
	return true
end

function DataService.AddXP(player: Player, amount: number): boolean
	local profile = Profiles[player]
	if profile == nil then
		return false
	end
	profile.Data.XP += amount
	notifyChanged(player)
	return true
end

function DataService.IncrementStat(player: Player, statName: string, amount: number): boolean
	local profile = Profiles[player]
	if profile == nil then
		return false
	end

	local stats = profile.Data.Stats
	if stats[statName] == nil then
		return false
	end

	stats[statName] += amount
	notifyChanged(player)
	return true
end

local function onPlayerAdded(player: Player)
	local profile = PlayerStore:StartSessionAsync(`Player_{player.UserId}`, {
		Cancel = function()
			-- Не продолжать загрузку, если игрок уже вышел.
			return player.Parent ~= Players
		end,
	})

	if profile == nil then
		-- Сессию не удалось начать (обычно игрок вышел во время загрузки).
		player:Kick(KICK_MESSAGE)
		return
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()

	profile.OnSessionEnd:Connect(function()
		Profiles[player] = nil
		-- Сессия могла быть отобрана другим сервером — данные больше не наши.
		player:Kick(KICK_MESSAGE)
	end)

	if player.Parent == Players then
		Profiles[player] = profile
		-- Первое уведомление: подписчики строят отображение по загруженным данным.
		notifyChanged(player)
	else
		-- Игрок вышел, пока грузились: освобождаем сессию, чтобы её не заклинило.
		profile:EndSession()
	end
end

local function onPlayerRemoving(player: Player)
	local profile = Profiles[player]
	if profile ~= nil then
		profile:EndSession()
	end
end

-- Поднимает сервис: подписки на вход/выход и загрузка уже присутствующих игроков.
local initialized = false

function DataService.Init()
	if initialized then
		return
	end
	initialized = true

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	-- Игроки, зашедшие до подписки (например, при live-синке в Studio).
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return DataService
