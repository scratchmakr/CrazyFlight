local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Trove = require(ReplicatedStorage.Packages.Trove)
local Fusion = require(ReplicatedStorage.Packages.Fusion)

local TOGGLE_MUSIC_TIME = 0.3

local module = {}
local musicSoundGroup = workspace.Lobby.SoundGroups.music

local sfxFolder = workspace:FindFirstChild("SFXFolder") or Instance.new("Folder")
sfxFolder:ClearAllChildren()
sfxFolder.Name = "SFXFolder"
sfxFolder.Parent = workspace
export type soundProps = {
    sound: Sound,
	pitch: number?,
    pitchVariation: boolean?,
    parent: Object?,
}

function module.playSound(props: soundProps)
    local sound = props.sound
    local pitch = props.pitch
    local pitchVariation = props.pitchVariation
    local parent = props.parent

	local soundTrove = Trove.new()
	parent = parent or sfxFolder;

	local newSound = sound:Clone()
	if not newSound.SoundGroup then
		newSound.SoundGroup = workspace.Lobby.SoundGroups.sfx
	end
	if pitchVariation == nil or pitchVariation == true then
		newSound.PlaybackSpeed = Random.new():NextNumber(0.9,1.1);
	end
	
	if pitch then
		newSound.PlaybackSpeed = pitch
	end
	
	newSound.Parent = parent;
	newSound:Play()
	if not newSound.Looped then
		soundTrove:Add(newSound.Ended:Once(function()
			----print("sound destroyed", sound.Name)
			newSound:Destroy()
		end))
	end
	Fusion.Hydrate(newSound) {
		[Fusion.Cleanup] = function ()
			soundTrove:Destroy()
		end
	}
	return newSound
end

function module.toggleMusic(toggle: boolean)
	local previousVolume = musicSoundGroup:GetAttribute("previousVolume")
	if not toggle and not previousVolume then
		musicSoundGroup:SetAttribute("previousVolume", musicSoundGroup.Volume)
	end
	local endVolume = toggle and previousVolume or 0
	--print("toggle music", endVolume)
	local tween = TweenService:Create(musicSoundGroup, TweenInfo.new(TOGGLE_MUSIC_TIME, Enum.EasingStyle.Linear), {
		Volume = endVolume
	})
	tween:Play()
	Debris:AddItem(tween, TOGGLE_MUSIC_TIME)
end

return module