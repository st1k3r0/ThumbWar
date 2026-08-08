--!strict
-- Направления выбора в фазе охоты.
--
-- Заданы в координатах ЭКРАНА и одинаковы для обоих игроков: Left — это левая
-- сторона экрана у каждого, независимо от того, на какой точке арены он стоит.
-- Ничего не зеркалится.

local HuntDirection = {
	Left = "Left",
	Right = "Right",
	-- Ловушка, клавиша S: игрок не бьёт, а ждёт и ловит того, кто ударил.
	Trap = "Trap",
}

export type Direction = string

-- Клавиши управления. Раскладка одинакова для обоих игроков,
-- потому что направления заданы в координатах экрана.
local KEY_TO_DIRECTION: { [Enum.KeyCode]: Direction } = {
	[Enum.KeyCode.A] = HuntDirection.Left,
	[Enum.KeyCode.D] = HuntDirection.Right,
	[Enum.KeyCode.S] = HuntDirection.Trap,
}

-- Удар — это движение в сторону. Ловушка ударом не считается.
function HuntDirection.IsStrike(value: any): boolean
	return value == HuntDirection.Left or value == HuntDirection.Right
end

-- Возвращает направление для клавиши или nil, если клавиша не наша.
function HuntDirection.FromKeyCode(keyCode: Enum.KeyCode): Direction?
	return KEY_TO_DIRECTION[keyCode]
end

-- Проверка присланного клиентом значения. Сервер обязан звать её на каждый ввод:
-- клиент может прислать что угодно.
function HuntDirection.IsValid(value: any): boolean
	return value == HuntDirection.Left or value == HuntDirection.Right or value == HuntDirection.Trap
end

return table.freeze(HuntDirection)
