--!strict
-- Отправка состояния матча его участникам: фаза, номер раунда и счёт.
--
-- Обоим игрокам уходит ОДИН И ТОТ ЖЕ payload, и порядок игроков в нём совпадает
-- с порядком точек на арене: players[1] стоит слева экрана, players[2] справа.
-- Так же, как с камерой, состояние не переворачивается под сторону игрока.
--
-- Канал односторонний: сервер -> клиент. Клиент отсюда ничего не запрашивает
-- и ни на что не влияет.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Services = ServerScriptService.Server.Services
local MatchService = require(Services.MatchService)

local matchState = Remotes.MatchState :: RemoteEvent

local MatchStateService = {}

local function buildPayload(match: MatchService.Match, phaseEndsAt: number)
	local players = {}

	for index, player in match.players do
		players[index] = {
			name = player.Name,
			wins = match.score[player],
		}
	end

	return {
		matchId = match.id,
		phase = match.phase,
		roundNumber = match.roundNumber,
		-- Момент окончания фазы по серверным часам: клиент рисует отсчёт по нему.
		phaseEndsAt = phaseEndsAt,
		players = players,
	}
end

local function broadcast(match: MatchService.Match, phaseEndsAt: number)
	local payload = buildPayload(match, phaseEndsAt)

	for _, player in match.players do
		-- Строго участникам матча: посторонним состояние не уходит.
		matchState:FireClient(player, payload)
	end
end

function MatchStateService.Init()
	MatchService.OnPhaseChanged(broadcast)
end

return MatchStateService
