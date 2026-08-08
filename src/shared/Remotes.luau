--!strict
-- Доступ к сетевым объектам по имени.
-- На сервере недостающие инстансы создаются при первом обращении,
-- на клиенте — ожидаются через WaitForChild. API одинаков для обеих сторон.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local IS_SERVER = RunService:IsServer()
local FOLDER_NAME = "Remotes"

-- Единственный список сетевых объектов: имя -> класс инстанса.
local DEFINITIONS: { [string]: string } = {
	MatchState = "RemoteEvent",
	HuntInput = "RemoteEvent",
	PinInput = "RemoteEvent",
	PinStart = "RemoteEvent",
	PinUpdate = "RemoteEvent",
	MatchEnd = "RemoteEvent",

	-- Реплика данных игрока. Пуш — только сервер -> клиент.
	ProfileUpdated = "RemoteEvent",
	-- Запрос данных по инициативе клиента (стартовая синхронизация).
	GetProfile = "RemoteFunction",

	-- Переключение камеры матча. Сервер -> клиент.
	MatchCamera = "RemoteEvent",
}

local function getFolder(): Folder
	if IS_SERVER then
		local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = FOLDER_NAME
			folder.Parent = ReplicatedStorage
		end
		return folder :: Folder
	end

	return ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
end

local folder = getFolder()
local cache: { [string]: Instance } = {}

-- Сервер создаёт все объекты сразу при загрузке модуля, а не лениво:
-- иначе клиент может навсегда зависнуть на WaitForChild, если сервер
-- ещё ни разу не обращался к этому remote.
if IS_SERVER then
	for name, className in DEFINITIONS do
		local remote = folder:FindFirstChild(name)
		if not remote then
			remote = Instance.new(className)
			remote.Name = name
			remote.Parent = folder
		end
		cache[name] = remote
	end
end

local function resolve(name: string): Instance
	local cached = cache[name]
	if cached then
		return cached
	end

	local className = DEFINITIONS[name]
	if not className then
		error(`Remotes: неизвестное имя "{name}"`, 2)
	end

	-- Клиент по-прежнему получает объекты лениво, дожидаясь их от сервера.
	local remote = folder:WaitForChild(name)
	cache[name] = remote
	return remote
end

local Remotes = setmetatable({}, {
	__index = function(_, name: string): Instance
		return resolve(name)
	end,
})

return Remotes
