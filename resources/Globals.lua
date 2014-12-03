-------------------------------------------------------------------
-- Debugging --

showDebugTouchArea = false

--require("mobdebug").start() -- Uncomment for ZeroBrain IDE debuger support

-------------------------------------------------------------------

require("helpers/Utility")

pauseflag = false -- flag to prevent Quick emulating time passed for timers on resume events

deviceId = device:getInfo("deviceID")
deviceIsTouch = true

-- virtual coordinates for user space
appWidth = 640
appHeight = 960


---- Game globals go here for easy access --------

fontMain = "fonts/Default.fnt"
fontMainTitle = "fonts/Default.fnt"

textCol = color.black
goldColor = {231,215,99}
goldColorDark = {181,165,59}
titleCol = goldColor
btnCol = color.aliceBlue
btnTexture = "textures/bigGoldButton.png"
btnTextureShort = "textures/shortGoldButton.png"
titleMusic = "sounds/POL-go-doge-go-short.mp3"
gameMusic = nil
-- free music is from www.playonloop.com A handy website!
-- You should include attribution in the game if not paying!

gameInfo = {}
gameInfo.score = 0
gameInfo.soundOn = true
gameInfo.lastUserName = "P1 "
-- name is hard coded in this example, could be extended to some entry system or game service login

gameInfo.scores = {}
local names = {"MAR", "MAL", "ADE", "PAC", "JNR", "CRS", "I3D", "MRK", "DAN", "FFS"}
for n=1, 10 do
    local score = (11-n)*20 --20->200
    gameInfo.scores[n] = {name=names[n], score=score}
end

---- Platform/device/app info --------

local appId = "com.mycompany.slots"

local platform = device:getInfo("platform")

useQuitButton = platform ~= "IPHONE"

