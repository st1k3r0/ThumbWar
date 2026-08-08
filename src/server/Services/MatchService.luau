--!strict
-- Состояние матчей и машина состояний: создание объекта матча, доступ к нему,
-- удаление и прогон матча по фазам.
--
-- Круг раунда: Ritual -> Hunt -> Pin -> RoundEnd. Дальше либо новый раунд
-- с Ritual, либо MatchEnd. Внутри фаз пока ничего не происходит: каждая просто
-- выдерживает свою длительность из Config и уступает место следующей.
-- Определение победителя раунда появится вместе с геймплеем.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local MatchPhase = require(ReplicatedStorage.Shared.MatchPhase)

local MatchService = {}

export type Match = {
	-- Уникальный номер матча в пределах сервера.
	id: number,
	-- Ровно двое: players[1] встаёт на Slot1, players[2] на Slot2.
	players: { Player },
	-- Выигранные раунды по каждому игроку.
	score: { [Player]: number },
	-- Текущая фаза, одно из значений MatchPhase.
	phase: MatchPhase.Phase,
	-- Номер текущего раунда, считается с первого.
	roundNumber: number,
}

local matches: { [number]: Match } = {}
local matchByPlayer: { [Player]: number } = {}

-- Матчи, для которых машина состояний уже крутится.
local running: { [number]: boolean } = {}

local nextMatchId = 0

-- Порядок фаз внутри одного раунда.
local ROUND_PHASES: { MatchPhase.Phase } = {
	MatchPhase.Ritual,
	MatchPhase.Hunt,
	MatchPhase.Pin,
	MatchPhase.RoundEnd,
}

-- Создаёт объект матча в начальном состоянии: первый раунд, фаза Ritual,
-- счёт по нулям. Нули и первый раунд — это пустое стартовое состояние,
-- балансом они не являются и в Config не выносятся.
function MatchService.Create(playerA: Player, playerB: Player): Match
	nextMatchId += 1

	local match: Match = {
		id = nextMatchId,
		players = { playerA, playerB },
		score = {
			[playerA] = 0,
			[playerB] = 0,
		},
		phase = MatchPhase.Ritual,
		roundNumber = 1,
	}

	matches[match.id] = match
	matchByPlayer[playerA] = match.id
	matchByPlayer[playerB] = match.id

	return match
end

function MatchService.Get(matchId: number): Match?
	return matches[matchId]
end

function MatchService.GetByPlayer(player: Player): Match?
	local matchId = matchByPlayer[player]
	if matchId == nil then
		return nil
	end
	return matches[matchId]
end

-- Возвращает соперника игрока в его матче.
function MatchService.GetOpponent(player: Player): Player?
	local match = MatchService.GetByPlayer(player)
	if match == nil then
		return nil
	end

	for _, participant in match.players do
		if participant ~= player then
			return participant
		end
	end

	return nil
end

-- Убирает матч из хранилища. Освобождением арены и прочими последствиями
-- занимается тот, кто вызвал: здесь только состояние.
function MatchService.Destroy(matchId: number): boolean
	local match = matches[matchId]
	if match == nil then
		return false
	end

	matches[matchId] = nil
	running[matchId] = nil
	for _, player in match.players do
		if matchByPlayer[player] == matchId then
			matchByPlayer[player] = nil
		end
	end

	return true
end

-- Подписчики на смену фазы. Через них состояние уходит клиентам,
-- а сама машина состояний про сеть ничего не знает.
local phaseListeners: { (match: Match, phaseEndsAt: number) -> () } = {}

function MatchService.OnPhaseChanged(callback: (match: Match, phaseEndsAt: number) -> ())
	table.insert(phaseListeners, callback)
end

-- Ставит фазу, пишет в лог и сообщает подписчикам.
-- Возвращает длительность фазы, чтобы вызывающий не искал её второй раз.
local function setPhase(match: Match, phase: MatchPhase.Phase): number
	local duration = Config.Match.PhaseDuration[phase]
	-- Время окончания считает сервер: клиент рисует отсчёт по нему,
	-- а не по своим часам.
	local phaseEndsAt = Workspace:GetServerTimeNow() + duration

	match.phase = phase
	print(`[Матч {match.id}] раунд {match.roundNumber}: {phase}`)

	for _, listener in phaseListeners do
		-- Упавший подписчик не должен останавливать матч.
		local ok, err = pcall(listener, match, phaseEndsAt)
		if not ok then
			warn(`[Матч {match.id}] подписчик на смену фазы упал: {err}`)
		end
	end

	return duration
end

-- Матч заканчивается, когда кто-то набрал нужное число побед
-- или когда сыграны все раунды.
local function isMatchOver(match: Match): boolean
	for _, wins in match.score do
		if wins >= Config.Match.RoundsToWin then
			return true
		end
	end

	return match.roundNumber >= Config.Match.TotalRounds
end

-- Прогоняет матч по фазам до конца. Вызывать повторно для того же матча нельзя:
-- две машины состояний на одном объекте затопчут друг друга.
-- Удаление матча остаётся за вызывающим: здесь только прогон.
function MatchService.Start(match: Match): boolean
	if running[match.id] then
		return false
	end

	running[match.id] = true

	task.spawn(function()
		while true do
			for _, phase in ROUND_PHASES do
				task.wait(setPhase(match, phase))
			end

			if isMatchOver(match) then
				break
			end

			match.roundNumber += 1
		end

		task.wait(setPhase(match, MatchPhase.MatchEnd))

		running[match.id] = nil
		print(`[Матч {match.id}] завершён на раунде {match.roundNumber}`)
	end)

	return true
end

function MatchService.IsRunning(matchId: number): boolean
	return running[matchId] == true
end

function MatchService.Init() end

return MatchService
