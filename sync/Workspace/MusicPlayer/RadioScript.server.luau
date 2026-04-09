local musiclist = 
	{"rbxassetid://96945197814852",
	"rbxassetid://120278659799183",
	"rbxassetid://119906324433963",
	"rbxassetid://94168843948673",
	"rbxassetid://84700217126063"
	}

local MusicPlayer = script.Parent.music

while true do
	local randomid = math.random(1, #musiclist)
	MusicPlayer.SoundId = musiclist[randomid]
	MusicPlayer:Play()
	MusicPlayer.Ended:Wait()
	wait(10)
end
