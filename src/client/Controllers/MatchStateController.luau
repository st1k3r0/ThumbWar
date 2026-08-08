--!strict
-- Приём состояния матча и вывод его на экран.
--
-- Клиент здесь только читает: он ничего не пересчитывает и не отправляет обратно.
-- Отсчёт считалки рисуется по времени окончания фазы, которое прислал сервер,
-- поэтому он одинаков у обоих игроков и не зависит от часов клиента.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local MatchPhase = require(ReplicatedStorage.Shared.MatchPhase)

local UI = require(Players.LocalPlayer.PlayerScripts.Client.UI.MatchStateUI)

local matchState = Remotes.MatchState :: RemoteEvent

local MatchStateController = {}

type PlayerLine = { name: string, wins: number }

type StatePayload = {
	matchId: number,
	phase: string,
	roundNumber: number,
	phaseEndsAt: number,
	players: { PlayerLine },
}

local current: StatePayload? = nil
local countdownConnection: RBXScriptConnection? = nil

local function stopCountdown()
	if countdownConnection ~= nil then
		countdownConnection:Disconnect()
		countdownConnection = nil
	end
	UI.HideRitual()
end

-- Отсчёт живёт ровно столько, сколько идёт фаза Ritual: соединение
-- обрывается на выходе из неё, а не копится от раунда к раунду.
local function startCountdown(endsAt: number)
	stopCountdown()

	countdownConnection = RunService.RenderStepped:Connect(function()
		local secondsLeft = endsAt - Workspace:GetServerTimeNow()
		UI.ShowRitual(secondsLeft)

		if secondsLeft <= 0 then
			stopCountdown()
		end
	end)
end

local function apply(payload: StatePayload)
	current = payload

	UI.SetVisible(payload.phase ~= MatchPhase.MatchEnd)
	UI.Update(payload.roundNumber, payload.phase, payload.players)

	if payload.phase == MatchPhase.Ritual then
		startCountdown(payload.phaseEndsAt)
	else
		stopCountdown()
	end
end

-- Текущее состояние матча или nil, если матча нет.
function MatchStateController.Get(): StatePayload?
	return current
end

-- В считалке ввод игрока не учитывается. Это подсказка для интерфейса:
-- решение всё равно принимает сервер, клиенту здесь не доверяют.
function MatchStateController.IsInputAllowed(): boolean
	local state = current
	if state == nil then
		return false
	end
	return state.phase ~= MatchPhase.Ritual
end

local initialized = false

function MatchStateController.Init()
	if initialized then
		return
	end
	initialized = true

	UI.Build()
	matchState.OnClientEvent:Connect(apply)
end

return MatchStateController
