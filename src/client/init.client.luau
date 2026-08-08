--!strict
-- Клиентский bootstrap: поднимает контроллеры в явно заданном порядке.
-- Каждый контроллер обязан реализовывать метод Init.

local Controllers = script.Controllers

-- Порядок запуска задаётся здесь и только здесь. Новый контроллер — новая строка.
local CONTROLLER_ORDER: { ModuleScript } = {
	Controllers.DataController,
}

for _, moduleScript in CONTROLLER_ORDER do
	local controller = require(moduleScript)

	local ok, err = pcall(function()
		controller.Init()
	end)

	if not ok then
		-- Останавливаем загрузку: дальше поднимать контроллеры поверх сломанного нельзя.
		error(`[Bootstrap] Контроллер "{moduleScript.Name}" не запустился: {err}`, 0)
	end
end

print("[Bootstrap] Клиент: все контроллеры запущены.")
