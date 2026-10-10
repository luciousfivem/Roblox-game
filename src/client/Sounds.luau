--!strict
-- Plays short one-shot sounds. Ids come from Config.SoundIds, so they're easy to swap.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage.Shared.Config)

local Sounds = {}

function Sounds.play(name: string, volume: number?, pitch: number?)
	local id = (Config.SoundIds :: { [string]: string })[name]
	if not Config.SoundsEnabled or not id then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume or 0.5
	sound.PlaybackSpeed = pitch or 1
	sound.Parent = SoundService
	sound:Play()
	Debris:AddItem(sound, 4)
end

return Sounds
