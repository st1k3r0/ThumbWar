--!strict
-- Таблица исходов тика охоты. Это сердце боя, поэтому здесь чистая функция:
-- никаких обращений к состоянию матча, только два выбора на входе и исход на выходе.
--
-- Здесь живёт ТОЛЬКО стоимость исхода. Стоимость самого действия (постановка
-- ловушки) списывается отдельно, в момент регистрации выбора, и в эту таблицу
-- не входит. Иначе обоюдная ловушка списалась бы дважды.
--
-- Игроки различаются исключительно позициями 1 и 2 — теми же, что на арене
-- и в состоянии матча. Направления заданы в координатах экрана и одинаковы для
-- обоих, поэтому таблица полностью симметрична: Resolve(a, b) обязан быть
-- зеркалом Resolve(b, a), и ни одна позиция не даёт преимущества.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local HuntDirection = require(ReplicatedStorage.Shared.HuntDirection)

local HuntOutcome = {}

-- Стоимость самого действия, списывается при регистрации выбора.
-- Удары бесплатны, ловушка стоит сил уже за постановку.
function HuntOutcome.GetActionCost(choice: HuntDirection.Direction?): number
	if choice == HuntDirection.Trap then
		return Config.Trap.StaminaCost
	end
	return 0
end

HuntOutcome.Kind = table.freeze({
	-- Оба ударили в одну сторону: столкновение, дальше микро-дуэль на реакцию.
	Collision = "Collision",
	-- Ударили в разные стороны и разошлись: ничья с потерей стамины.
	Miss = "Miss",
	-- Один ударил, другой ждал в ловушке: пойман, дальше мягкий пин.
	Trapped = "Trapped",
	-- Оба ждали в ловушке: не произошло ничего. Свои силы каждый уже потратил
	-- на постановку ловушки, дополнительной стоимости у исхода нет.
	Nothing = "Nothing",
	-- Хотя бы один не действовал. Промах без урона по стамине.
	Idle = "Idle",
})

export type Kind = string

export type Result = {
	kind: Kind,
	-- Позиция поймавшего и пойманного, только для исхода Trapped.
	trapper: number?,
	caught: number?,
	-- Списание стамины по позициям: [1] и [2].
	staminaCost: { number },
}

-- Разрешает тик по выбору каждой позиции. nil означает "не действовал".
function HuntOutcome.Resolve(first: HuntDirection.Direction?, second: HuntDirection.Direction?): Result
	-- Бездействие разбирается первым: оно не приносит ни урона, ни исхода.
	if first == nil or second == nil then
		return {
			kind = HuntOutcome.Kind.Idle,
			staminaCost = { 0, 0 },
		}
	end

	local firstStrikes = HuntDirection.IsStrike(first)
	local secondStrikes = HuntDirection.IsStrike(second)

	if firstStrikes and secondStrikes then
		if first == second then
			-- Оба влево или оба вправо: пальцы встретились.
			return {
				kind = HuntOutcome.Kind.Collision,
				staminaCost = { 0, 0 },
			}
		end

		-- Один влево, другой вправо: разошлись, оба потратились впустую.
		local cost = Config.Hunt.MissStaminaCost
		return {
			kind = HuntOutcome.Kind.Miss,
			staminaCost = { cost, cost },
		}
	end

	if not firstStrikes and not secondStrikes then
		-- Обе ловушки: ловить некого. Постановку каждый уже оплатил,
		-- поэтому сам исход бесплатный.
		return {
			kind = HuntOutcome.Kind.Nothing,
			staminaCost = { 0, 0 },
		}
	end

	-- Остался единственный случай: один бьёт, другой стоит в ловушке.
	-- Ловушка ловит бьющего, и неважно, влево тот бил или вправо.
	local trapper = if firstStrikes then 2 else 1
	local caught = if firstStrikes then 1 else 2

	return {
		kind = HuntOutcome.Kind.Trapped,
		trapper = trapper,
		caught = caught,
		staminaCost = { 0, 0 },
	}
end

return HuntOutcome
