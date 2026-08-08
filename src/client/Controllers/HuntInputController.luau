--!strict
-- Приём ввода охоты с клавиатуры: A — влево, D — вправо, S — вниз.
--
-- Клиент отправляет только сам выбор. Ни времени, ни номера тика, ни матча он
-- не шлёт: их знает сервер. Пока окно тика открыто, выбор можно менять сколько
-- угодно — сервер засчитает последний. Ничего не нажал — не действовал.
--
-- Проверка окна на клиенте нужна только чтобы не слать заведомо мусорные пакеты.
-- Решает всё равно сервер: он сам отбрасывает всё, что пришло вне окна.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local HuntDirection = require(ReplicatedStorage.Shared.HuntDirection)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local huntInput = Remotes.HuntInput :: RemoteEvent

local HuntInputController = {}

type Window = {
	matchId: number,
	tickNumber: number,
	closesAt: number,
}

local window: Window? = nil
-- Последний отправленный выбор в текущем тике, нужен только для подсказки UI.
local lastSent: HuntDirection.Direction? = nil

local function isWindowOpen(): boolean
	local current = window
	if current == nil then
		return false
	end
	return Workspace:GetServerTimeNow() <= current.closesAt
end

local function onWindowOpened(payload: Window)
	window = payload
	lastSent = nil
end

local function onInputBegan(input: InputObject, gameProcessed: boolean)
	-- Ввод, съеденный чатом или другим интерфейсом, нас не касается.
	if gameProcessed then
		return
	end

	local direction = HuntDirection.FromKeyCode(input.KeyCode)
	if direction == nil then
		return
	end

	if not isWindowOpen() then
		return
	end

	lastSent = direction
	huntInput:FireServer(direction)
end

-- Текущий выбор игрока в этом тике или nil, если он ещё ничего не нажал.
function HuntInputController.GetCurrentChoice(): HuntDirection.Direction?
	if not isWindowOpen() then
		return nil
	end
	return lastSent
end

function HuntInputController.IsWindowOpen(): boolean
	return isWindowOpen()
end

local initialized = false

function HuntInputController.Init()
	if initialized then
		return
	end
	initialized = true

	huntInput.OnClientEvent:Connect(onWindowOpened)
	UserInputService.InputBegan:Connect(onInputBegan)
end

return HuntInputController
