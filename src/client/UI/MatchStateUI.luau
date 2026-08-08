--!strict
-- Экранный вывод состояния матча: раунд, счёт, фаза и текст считалки с отсчётом.
-- Пока это просто текст, без оформления.
--
-- Размеры заданы долями экрана, а шрифт масштабируется: интерфейс обязан
-- читаться на телефоне, а не только на мониторе.

local Players = game:GetService("Players")

local MatchStateUI = {}

local RITUAL_TEXT = "One, two, three, four — I declare a thumb war!"

local screenGui: ScreenGui
local roundLabel: TextLabel
local scoreLabel: TextLabel
local phaseLabel: TextLabel
local ritualLabel: TextLabel
local countdownLabel: TextLabel

local function makeLabel(name: string, position: UDim2, size: UDim2, textSize: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Position = position
	label.Size = size
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.5
	label.Text = ""

	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = textSize
	constraint.Parent = label

	return label
end

function MatchStateUI.Build()
	if screenGui ~= nil then
		return
	end

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "MatchState"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.Enabled = false
	-- Автоперевод Roblox выключен: текст остаётся английским независимо
	-- от языка клиента и от настроек локализации места.
	screenGui.AutoLocalize = false

	roundLabel = makeLabel("Round", UDim2.fromScale(0.25, 0.04), UDim2.fromScale(0.5, 0.07), 36)
	roundLabel.Parent = screenGui

	scoreLabel = makeLabel("Score", UDim2.fromScale(0.2, 0.11), UDim2.fromScale(0.6, 0.1), 56)
	scoreLabel.Parent = screenGui

	phaseLabel = makeLabel("Phase", UDim2.fromScale(0.25, 0.21), UDim2.fromScale(0.5, 0.06), 28)
	phaseLabel.Parent = screenGui

	ritualLabel = makeLabel("Ritual", UDim2.fromScale(0.1, 0.42), UDim2.fromScale(0.8, 0.09), 44)
	ritualLabel.Parent = screenGui

	countdownLabel = makeLabel("Countdown", UDim2.fromScale(0.3, 0.52), UDim2.fromScale(0.4, 0.14), 90)
	countdownLabel.Parent = screenGui

	screenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

function MatchStateUI.SetVisible(visible: boolean)
	if screenGui ~= nil then
		screenGui.Enabled = visible
	end
end

-- Обновляет постоянную часть: раунд, счёт и название фазы.
function MatchStateUI.Update(roundNumber: number, phase: string, players: { { name: string, wins: number } })
	roundLabel.Text = `ROUND {roundNumber}`
	phaseLabel.Text = phase

	local left = players[1]
	local right = players[2]
	if left ~= nil and right ~= nil then
		-- Порядок тот же, что на экране: первый игрок слева, второй справа.
		scoreLabel.Text = `{left.name}  {left.wins} : {right.wins}  {right.name}`
	end
end

-- Показывает считалку с обратным отсчётом. secondsLeft уже посчитан по серверным часам.
function MatchStateUI.ShowRitual(secondsLeft: number)
	ritualLabel.Text = RITUAL_TEXT
	countdownLabel.Text = string.format("%.1f", math.max(secondsLeft, 0))
end

function MatchStateUI.HideRitual()
	ritualLabel.Text = ""
	countdownLabel.Text = ""
end

return MatchStateUI
