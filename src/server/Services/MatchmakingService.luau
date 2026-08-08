--!strict
-- Очередь ожидающих матч и подбор пар в пределах ОДНОГО сервера.
-- Рейтинг пока не учитывается: берутся первые двое по порядку входа.
-- Кросс-серверного поиска здесь нет и не планируется на этом этапе.
--
-- Созданный матч до старта считается незавершённым: пара живёт здесь,
-- и если участник отключается, матч отменяется, а второй игрок возвращается
-- в голову очереди — он не терял место, пока ждал начала матча.
-- Как только матчевая логика реально стартовала, она обязана позвать
-- MarkStarted: с этого момента отключения — её ответственность, не очереди.

local Players = game:GetService("Players")

local MatchmakingService = {}

local PLAYERS_PER_MATCH = 2

export type PendingMatch = {
	id: number,
	players: { Player },
}

-- Массив, а не множество: важен порядок входа, матч получают первые двое.
local waiting: { Player } = {}

-- Созданные, но ещё не стартовавшие матчи.
local pending: { [number]: PendingMatch } = {}
local pendingByPlayer: { [Player]: number } = {}
local nextMatchId = 0

local matchListeners: { (match: PendingMatch) -> () } = {}
local cancelListeners: { (match: PendingMatch, leaver: Player) -> () } = {}

local function indexOf(player: Player): number?
	for index, queued in waiting do
		if queued == player then
			return index
		end
	end
	return nil
end

-- Игрок мог выйти, пока стоял в очереди.
local function isConnected(player: Player): boolean
	return player.Parent == Players
end

local function notify(listeners: { any }, label: string, ...: any)
	for _, listener in listeners do
		-- Упавший подписчик не должен ломать работу очереди.
		local ok, err = pcall(listener, ...)
		if not ok then
			warn(`[Matchmaking] Подписчик "{label}" упал: {err}`)
		end
	end
end

local tryFormMatch

-- Забирает из очереди первых двух и отдаёт их подписчикам.
function tryFormMatch()
	while #waiting >= PLAYERS_PER_MATCH do
		local playerA = table.remove(waiting, 1) :: Player
		if not isConnected(playerA) then
			continue
		end

		local playerB = table.remove(waiting, 1) :: Player
		if not isConnected(playerB) then
			-- Второй отвалился: первый возвращается в голову очереди и ждёт дальше.
			table.insert(waiting, 1, playerA)
			continue
		end

		nextMatchId += 1
		local match: PendingMatch = {
			id = nextMatchId,
			players = { playerA, playerB },
		}

		pending[match.id] = match
		pendingByPlayer[playerA] = match.id
		pendingByPlayer[playerB] = match.id

		print(`[Matchmaking] Матч {match.id} создан: {playerA.Name} и {playerB.Name}`)
		notify(matchListeners, "создание матча", match)
	end
end

local function forgetMatch(match: PendingMatch)
	pending[match.id] = nil
	for _, player in match.players do
		if pendingByPlayer[player] == match.id then
			pendingByPlayer[player] = nil
		end
	end
end

-- Отменяет созданный, но не начатый матч из-за ухода участника.
-- Оставшийся возвращается в голову очереди: он уже отстоял своё.
local function cancelMatch(match: PendingMatch, leaver: Player)
	forgetMatch(match)

	for _, player in match.players do
		if player ~= leaver and isConnected(player) and indexOf(player) == nil then
			table.insert(waiting, 1, player)
		end
	end

	print(`[Matchmaking] Матч {match.id} отменён: {leaver.Name} отключился до старта`)
	notify(cancelListeners, "отмена матча", match, leaver)

	-- Вернувшийся мог сразу составить пару с тем, кто уже ждал.
	tryFormMatch()
end

-- Подписка на созданный матч. Дальнейшее поведение — забота матчевого сервиса.
function MatchmakingService.OnMatchCreated(callback: (match: PendingMatch) -> ())
	table.insert(matchListeners, callback)
end

-- Подписка на отмену матча, который не успел начаться.
function MatchmakingService.OnMatchCancelled(callback: (match: PendingMatch, leaver: Player) -> ())
	table.insert(cancelListeners, callback)
end

-- Матчевая логика подтверждает, что матч стартовал. После этого очередь
-- за него больше не отвечает и отменять его не будет.
function MatchmakingService.MarkStarted(matchId: number): boolean
	local match = pending[matchId]
	if match == nil then
		return false
	end

	forgetMatch(match)
	return true
end

function MatchmakingService.GetCount(): number
	return #waiting
end

function MatchmakingService.IsWaiting(player: Player): boolean
	return indexOf(player) ~= nil
end

function MatchmakingService.IsInPendingMatch(player: Player): boolean
	return pendingByPlayer[player] ~= nil
end

-- Ставит игрока в очередь. Повторный вызов для того же игрока ничего не меняет.
function MatchmakingService.Add(player: Player): boolean
	if indexOf(player) ~= nil then
		return false
	end

	-- Игрок, уже ждущий начала матча, второй раз в очередь не встаёт.
	if pendingByPlayer[player] ~= nil then
		return false
	end

	table.insert(waiting, player)
	tryFormMatch()
	return true
end

function MatchmakingService.Remove(player: Player): boolean
	local index = indexOf(player)
	if index == nil then
		return false
	end

	table.remove(waiting, index)
	return true
end

local function onPlayerRemoving(player: Player)
	-- Из очереди уходит в любом случае: и выход, и вылет приходят сюда же.
	MatchmakingService.Remove(player)

	local matchId = pendingByPlayer[player]
	if matchId == nil then
		return
	end

	local match = pending[matchId]
	if match ~= nil then
		cancelMatch(match, player)
	end
end

function MatchmakingService.Init()
	Players.PlayerRemoving:Connect(onPlayerRemoving)
end

return MatchmakingService
