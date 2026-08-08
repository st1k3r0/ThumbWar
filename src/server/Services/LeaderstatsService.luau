--!strict
-- Стандартный leaderstats (список игроков по Tab): Wins и Coins.
-- Это только отображение: источник правды — профиль, сюда значения зеркалятся.

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local Services = ServerScriptService.Server.Services
local DataService = require(Services.DataService)

local FOLDER_NAME = "leaderstats"
local WINS_NAME = "Wins"
local COINS_NAME = "Coins"

local LeaderstatsService = {}

-- Возвращает папку leaderstats игрока, создавая её при первом обращении.
local function getFolder(player: Player): Folder
	local existing = player:FindFirstChild(FOLDER_NAME)
	if existing then
		return existing :: Folder
	end

	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME

	local wins = Instance.new("IntValue")
	wins.Name = WINS_NAME
	wins.Parent = folder

	local coins = Instance.new("IntValue")
	coins.Name = COINS_NAME
	coins.Parent = folder

	-- Папка парентится последней: клиент видит её уже укомплектованной.
	folder.Parent = player

	return folder
end

-- Переносит текущие значения профиля в leaderstats.
local function sync(player: Player)
	local profile = DataService.GetProfile(player)
	if profile == nil then
		-- Профиль ещё не загружен или уже освобождён — показывать нечего.
		return
	end

	local folder = getFolder(player)
	local wins = folder:FindFirstChild(WINS_NAME) :: IntValue
	local coins = folder:FindFirstChild(COINS_NAME) :: IntValue

	wins.Value = profile.Data.Wins
	coins.Value = profile.Data.Coins
end

local initialized = false

function LeaderstatsService.Init()
	if initialized then
		return
	end
	initialized = true

	-- Одна точка обновления: и первая загрузка профиля, и любое последующее
	-- изменение данных приходят сюда же.
	DataService.OnProfileChanged(sync)

	-- Игроки, чей профиль загрузился до старта этого сервиса.
	for _, player in Players:GetPlayers() do
		sync(player)
	end
end

return LeaderstatsService
