--!strict
-- Локальное зеркало данных игрока. Только чтение.
-- Источник правды — сервер: здесь ничего не пересчитывается и не отправляется обратно.
-- Таблица заморожена, поэтому попытка изменить зеркало упадёт сразу,
-- а не разойдётся молча с серверным состоянием.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local profileUpdated = Remotes.ProfileUpdated :: RemoteEvent
local getProfile = Remotes.GetProfile :: RemoteFunction

local DataController = {}

local data: { [any]: any }? = nil
local listeners: { (data: { [any]: any }) -> () } = {}

local function deepFreeze(t: { [any]: any }): { [any]: any }
	for _, value in t do
		if type(value) == "table" then
			deepFreeze(value)
		end
	end
	return table.freeze(t)
end

local function apply(newData: { [any]: any })
	data = deepFreeze(newData)

	for _, listener in listeners do
		-- Упавший подписчик не должен ломать приём следующих обновлений.
		local ok, err = pcall(listener, newData)
		if not ok then
			warn(`[DataController] Подписчик на обновление данных упал: {err}`)
		end
	end
end

-- Текущая копия данных или nil, если она ещё не пришла с сервера.
function DataController.Get(): { [any]: any }?
	return data
end

-- Подписка на обновление. Если данные уже есть, callback вызывается сразу,
-- чтобы подписчику не приходилось отдельно обрабатывать первый кадр.
function DataController.OnChanged(callback: (data: { [any]: any }) -> ())
	table.insert(listeners, callback)

	local current = data
	if current ~= nil then
		callback(current)
	end
end

local initialized = false

function DataController.Init()
	if initialized then
		return
	end
	initialized = true

	profileUpdated.OnClientEvent:Connect(apply)

	-- Стартовый запрос отдельным потоком: он не должен задерживать
	-- запуск остальных контроллеров.
	task.spawn(function()
		local initial = getProfile:InvokeServer()

		-- Пуш мог прийти, пока ждали ответ, — тогда он свежее, и его не трогаем.
		if initial ~= nil and data == nil then
			apply(initial)
		end
	end)
end

return DataController
