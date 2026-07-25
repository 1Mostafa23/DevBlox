--!strict
export type WaveGroup = {
	EnemyType: string,         -- Название из EnemyConfig
	Count: number,             -- Количество врагов
	Interval: number,          -- Пауза между спавном внутри группы
	DelayBeforeGroup: number?, -- Задержка перед стартом этой группы
}

export type WaveDefinition = {
	Groups: {WaveGroup},
	PauseAfterWave: number,    -- Пауза перед следующей волной
}

local WaveConfig: {[number]: WaveDefinition} = {
	[1] = {
		PauseAfterWave = 5,
		Groups = {
			{ EnemyType = "Goblin", Count = 5, Interval = 2 },
		},
	},
	[2] = {
		PauseAfterWave = 5,
		Groups = {
			{ EnemyType = "Goblin", Count = 6, Interval = 1.5 },
			{ EnemyType = "FastRunner", Count = 3, Interval = 1, DelayBeforeGroup = 3 },
		},
	},
	[3] = { -- Босс-волна
		PauseAfterWave = 10,
		Groups = {
			{ EnemyType = "Goblin", Count = 10, Interval = 1 },
			{ EnemyType = "Boss", Count = 1, Interval = 0, DelayBeforeGroup = 4 },
		},
	},
}

return WaveConfig