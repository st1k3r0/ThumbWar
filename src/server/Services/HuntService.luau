--!strict
-- Тики фазы охоты.
--
-- Всё время считает сервер. Клиент не сообщает, когда тик начался или кончился,
-- и не присылает свои отметки времени: он получает открытие окна ввода и может
-- прислать только сам выбор. Опоздавший, чужой или неизвестный ввод
-- отбрасывается молча.
--
-- Внутри тика выбор можно менять сколько угодно: засчитывается последний.
-- Отсутствие выбора — это не ошибка, а полноценный исход: игрок не действовал.
--
-- Платит игрок только за финальный выбор, и только при разрешении тика.
-- Промежуточные нажатия соперник не видит, обмануть ими некого, поэтому они
-- не стоят стамины и не запускают перезарядку ловушки. Доступность ловушки
-- при этом проверяется в момент выбора, а не при списании.
--
-- Правила исхода охоты появятся вместе с геймплеем. Здесь тик собирает выборы
-- обоих игроков и отдаёт их подписчикам через OnTickResolved.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local HuntDirection = require(ReplicatedStorage.Shared.HuntDirection)
local HuntOutcome = require(ReplicatedStorage.Shared.HuntOutcome)
local MatchPhase = require(ReplicatedStorage.Shared.MatchPhase)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Services = ServerScriptService.Server.Services
local MatchService = require(Services.MatchService)

local huntInput = Remotes.HuntInput :: RemoteEvent

local HuntService = {}

-- Открытое окно ввода одного тика.
type Window = {
	tickNumber: number,
	closesAt: number,
	choices: { [Player]: HuntDirection.Direction },
}

-- Момент, когда игроку снова доступна ловушка, по матчам и игрокам.
-- Кулдаун живёт внутри фазы охоты: тиков вне неё не бывает.
local trapReadyAt: { [number]: { [Player]: number } } = {}

-- По одному открытому окну на матч.
local windows: { [number]: Window } = {}

type TickListener = (
	match: MatchService.Match,
	tickNumber: number,
	choices: { [Player]: HuntDirection.Direction },
	outcome: HuntOutcome.Result
) -> ()

local tickListeners: { TickListener } = {}

-- Подписка на закрытый тик: сюда придут выборы обоих игроков и разрешённый исход.
function HuntService.OnTickResolved(callback: TickListener)
	table.insert(tickListeners, callback)
end

-- Доступна ли игроку ловушка прямо сейчас: хватает ли сил и прошла ли перезарядка.
local function isTrapAvailable(match: MatchService.Match, player: Player): boolean
	local stamina = match.stamina[player]
	if stamina == nil or stamina < Config.Trap.StaminaCost then
		return false
	end

	local perMatch = trapReadyAt[match.id]
	local readyAt = perMatch ~= nil and perMatch[player] or nil
	if readyAt ~= nil and Workspace:GetServerTimeNow() < readyAt then
		return false
	end

	return true
end

-- Запускает перезарядку ловушки. Зовётся только если ловушка осталась
-- финальным выбором игрока в тике.
local function startTrapCooldown(match: MatchService.Match, player: Player)
	local perMatch = trapReadyAt[match.id]
	if perMatch == nil then
		perMatch = {}
		trapReadyAt[match.id] = perMatch
	end

	perMatch[player] = Workspace:GetServerTimeNow() + Config.Trap.Cooldown
end

-- Снимает стамину, не опуская её ниже нуля.
local function spendStamina(match: MatchService.Match, player: Player, amount: number)
	if amount <= 0 then
		return
	end

	local current = match.stamina[player]
	if current == nil then
		return
	end

	match.stamina[player] = math.max(current - amount, 0)
end

local function openWindow(match: MatchService.Match, tickNumber: number): Window
	local window: Window = {
		tickNumber = tickNumber,
		closesAt = Workspace:GetServerTimeNow() + Config.Hunt.TickDuration,
		choices = {},
	}

	windows[match.id] = window

	for _, player in match.players do
		-- Открытие окна: с этого момента сервер принимает ввод этого тика.
		huntInput:FireClient(player, {
			matchId = match.id,
			tickNumber = tickNumber,
			closesAt = window.closesAt,
		})
	end

	return window
end

local function closeWindow(match: MatchService.Match, window: Window)
	windows[match.id] = nil

	local first = match.players[1]
	local second = match.players[2]

	-- Порядок аргументов тот же, что и позиции на арене: первый слева экрана.
	local outcome = HuntOutcome.Resolve(window.choices[first], window.choices[second])

	-- Списание происходит здесь и только здесь: сначала стоимость финального
	-- действия каждого, затем стоимость исхода. Промежуточные нажатия внутри
	-- тика бесплатны, поэтому двойного списания не возникает.
	for index, player in match.players do
		local finalChoice = window.choices[player]

		spendStamina(match, player, HuntOutcome.GetActionCost(finalChoice))

		-- Кулдаун запускается только за ловушку, оставшуюся финальным выбором.
		if finalChoice == HuntDirection.Trap then
			startTrapCooldown(match, player)
		end

		spendStamina(match, player, outcome.staminaCost[index])
	end

	-- "не действовал" — игрок не прислал ничего за весь тик.
	print(
		`[Охота] матч {match.id} тик {window.tickNumber}: `
			.. `{first.Name}={window.choices[first] or "не действовал"} `
			.. `{second.Name}={window.choices[second] or "не действовал"} `
			.. `-> {outcome.kind}, стамина {match.stamina[first]}/{match.stamina[second]}`
	)

	for _, listener in tickListeners do
		-- Упавший подписчик не должен остановить тики.
		local ok, err = pcall(listener, match, window.tickNumber, window.choices, outcome)
		if not ok then
			warn(`[Охота] подписчик на исход тика упал: {err}`)
		end
	end
end

-- Крутит тики, пока идёт фаза охоты. Новый тик начинается только если он
-- успевает закончиться до конца фазы: обрубленных тиков быть не должно.
local function runTicks(match: MatchService.Match, phaseEndsAt: number)
	local tickNumber = 0

	while match.phase == MatchPhase.Hunt do
		if Workspace:GetServerTimeNow() + Config.Hunt.TickDuration > phaseEndsAt then
			break
		end

		tickNumber += 1
		local window = openWindow(match, tickNumber)

		task.wait(Config.Hunt.TickDuration)

		closeWindow(match, window)
	end

	windows[match.id] = nil
	trapReadyAt[match.id] = nil
end

local function onPhaseChanged(match: MatchService.Match, phaseEndsAt: number)
	if match.phase ~= MatchPhase.Hunt then
		-- Вне охоты открытых окон и перезарядок не остаётся.
		windows[match.id] = nil
		trapReadyAt[match.id] = nil
		return
	end

	task.spawn(runTicks, match, phaseEndsAt)
end

-- Единственное, что принимается от клиента, — сам выбор. Ни времени, ни номера
-- тика, ни матча: всё это сервер знает сам и клиенту не верит.
local function onInput(player: Player, direction: any)
	if not HuntDirection.IsValid(direction) then
		return
	end

	-- Матч определяется по отправителю, а не по тому, что он прислал.
	-- Игрок вне матча сюда не пройдёт, а повлиять на чужой матч не может:
	-- ему просто некуда записать выбор.
	local match = MatchService.GetByPlayer(player)
	if match == nil or match.phase ~= MatchPhase.Hunt then
		return
	end

	-- Явная проверка участия: запись идёт только в матч, где игрок реально стоит.
	local isParticipant = false
	for _, participant in match.players do
		if participant == player then
			isParticipant = true
			break
		end
	end

	if not isParticipant then
		return
	end

	local window = windows[match.id]
	if window == nil then
		return
	end

	-- Окно уже закрылось, а событие только доехало.
	if Workspace:GetServerTimeNow() > window.closesAt then
		return
	end

	-- Доступность ловушки проверяется в момент выбора: нечем платить или идёт
	-- перезарядка — выбрать нельзя, прежний выбор остаётся нетронутым.
	if direction == HuntDirection.Trap and not isTrapAvailable(match, player) then
		return
	end

	-- Менять выбор внутри тика можно: засчитывается последний.
	-- Промежуточные нажатия не стоят ничего и кулдаун не запускают —
	-- соперник их не видит, обмануть ими некого, наказывать не за что.
	-- Списание происходит при разрешении тика, по финальному выбору.
	window.choices[player] = direction
end

local initialized = false

function HuntService.Init()
	if initialized then
		return
	end
	initialized = true

	MatchService.OnPhaseChanged(onPhaseChanged)
	huntInput.OnServerEvent:Connect(onInput)
end

return HuntService
