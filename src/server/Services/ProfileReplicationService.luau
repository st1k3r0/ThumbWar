--!strict
-- Односторонняя реплика данных игрока на его собственный клиент:
-- при загрузке профиля, при каждом изменении и по запросу самого клиента.
-- Обратного канала нет: клиент не может ни изменить данные, ни повлиять на то,
-- что ему прислали. Любой аргумент от клиента здесь игнорируется —
-- игрок определяется только по отправителю запроса.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(ServerScriptService.Server.Services.DataService)

local profileUpdated = Remotes.ProfileUpdated :: RemoteEvent
local getProfile = Remotes.GetProfile :: RemoteFunction

local ProfileReplicationService = {}

-- Копия рекурсивная: наружу не должна уходить ссылка на живую таблицу профиля.
local function deepCopy(source: { [any]: any }): { [any]: any }
	local result = {}
	for key, value in source do
		if type(value) == "table" then
			result[key] = deepCopy(value)
		else
			result[key] = value
		end
	end
	return result
end

-- Возвращает копию данных игрока или nil, если профиль ещё не загружен.
local function snapshot(player: Player): { [any]: any }?
	local profile = DataService.GetProfile(player)
	if profile == nil then
		return nil
	end
	return deepCopy(profile.Data)
end

local function push(player: Player)
	local data = snapshot(player)
	if data == nil then
		return
	end
	-- Строго FireClient: данные игрока не уходят никому, кроме него самого.
	profileUpdated:FireClient(player, data)
end

function ProfileReplicationService.Init()
	-- Один источник событий: и первая загрузка профиля, и любое изменение.
	DataService.OnProfileChanged(push)

	-- Стартовая синхронизация по инициативе клиента: пуш при загрузке профиля
	-- мог уйти раньше, чем клиентский контроллер успел подписаться.
	getProfile.OnServerInvoke = function(player: Player)
		return snapshot(player)
	end

	for _, player in Players:GetPlayers() do
		push(player)
	end
end

return ProfileReplicationService
