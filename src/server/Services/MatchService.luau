--!strict
-- Состояние матчей: создание объекта матча, доступ к нему и удаление.
--
-- Здесь только состояние. Переходы между фазами, правила раундов и определение
-- победителя живут в матчевой логике, а не в этом хранилище.
-- Поля объекта матча обычные и меняются напрямую: match.phase = MatchPhase.Hunt.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

local nextMatchId = 0

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
	for _, player in match.players do
		if matchByPlayer[player] == matchId then
			matchByPlayer[player] = nil
		end
	end

	return true
end

function MatchService.Init() end

return MatchService
