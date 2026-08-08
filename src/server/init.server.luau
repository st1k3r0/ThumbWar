--!strict
-- Серверный bootstrap: поднимает сервисы в явно заданном порядке.
-- Каждый сервис обязан реализовывать метод Init.

local Services = script.Services

-- Порядок запуска задаётся здесь и только здесь. Новый сервис — новая строка.
local SERVICE_ORDER: { ModuleScript } = {
	Services.DataService,
	Services.LeaderstatsService,
	Services.ProfileReplicationService,
	Services.MatchmakingService,
	Services.MatchService,
	Services.MatchStateService,
	Services.HuntService,
	Services.ArenaService,
	Services.QueueService,
}

for _, moduleScript in SERVICE_ORDER do
	local service = require(moduleScript)

	local ok, err = pcall(function()
		service.Init()
	end)

	if not ok then
		-- Останавливаем загрузку: дальше поднимать сервисы поверх сломанного нельзя.
		error(`[Bootstrap] Сервис "{moduleScript.Name}" не запустился: {err}`, 0)
	end
end

print("[Bootstrap] Сервер: все сервисы запущены.")
