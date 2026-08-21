--!strict
-- client/UISounds.luau
-- Central place for UI sound-effect ids and playback, so hover/press/level-up/
-- salvage cues all go through one spot instead of scattering Sound instances
-- across every script.
--
-- IMPORTANT: every SoundId below is a placeholder ("") -- there is no way for
-- me to upload or verify real audio assets from this environment. Drop your
-- own uploaded or catalog asset ids into SOUND_IDS to make these actually
-- play. Until then, Play() on an empty SoundId is a harmless no-op (it will
-- NOT error), so nothing breaks -- these just stay silent.
local SoundService = game:GetService("SoundService")

local SOUND_IDS: { [string]: string } = {
	Hover = "",
	Press = "",
	LevelUp = "",
	Salvage = "",
}

local sounds: { [string]: Sound } = {}

for name, id in SOUND_IDS do
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = id
	sound.Parent = SoundService
	sounds[name] = sound
end

local UISounds = {}

function UISounds.Play(name: string)
	local sound = sounds[name]
	if sound and sound.SoundId ~= "" then
		sound:Play()
	end
end

return UISounds
