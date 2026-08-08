--!strict
-- Единственный источник числовых настроек игры.
-- Никакие числовые литералы не должны дублироваться в другом коде — только здесь.

local Config = {
	Match = {
		RoundsToWin = 2,
		TotalRounds = 3,

		-- Сколько секунд длится каждая фаза. Ключи совпадают с именами фаз
		-- из Shared.MatchPhase.
		PhaseDuration = {
			Ritual = 2.5,
			Hunt = 2,
			Pin = 2,
			RoundEnd = 2,
			MatchEnd = 2,
		},
	},

	Hunt = {
		TickDuration = 0.8,
		MaxStamina = 100,
	},

	Pin = {
		HitsToPin = 3,
		EscapeSteps = 10,
		Timeout = 8,
		MaxMisses = 3,
	},

	Trap = {
		StaminaCost = 20,
		Cooldown = 2,
	},

	Progression = {
		BaseStats = {
			Strength = 1,
			Grip = 1,
			Escape = 1,
			Stamina = 1,
		},
	},

	Ranked = {
		StartingElo = 1000,
	},
}

return Config
