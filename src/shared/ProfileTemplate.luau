--!strict
-- Единый шаблон данных игрока. Используется как дефолт для ProfileStore на сервере
-- и как эталон структуры данных везде, где это нужно.
-- Балансовые значения (стартовый Elo, базовые статы) читаются из Config,
-- в шаблоне числовых литералов для них быть не должно.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local ProfileTemplate = {
	Coins = 0,
	Level = 1,
	XP = 0,
	Wins = 0,
	Losses = 0,
	BestWinStreak = 0,
	CurrentWinStreak = 0,
	Elo = Config.Ranked.StartingElo,
	Stats = {
		Strength = Config.Progression.BaseStats.Strength,
		Grip = Config.Progression.BaseStats.Grip,
		Escape = Config.Progression.BaseStats.Escape,
		Stamina = Config.Progression.BaseStats.Stamina,
	},
	Rebirths = 0,
	OwnedSkins = {},
	EquippedSkin = "Default",
	DailyLoginStreak = 0,
	LastLoginTime = 0,
}

return ProfileTemplate
