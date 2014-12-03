
--SceneMenu and general game structure were based on
--https://github.com/nickchops/QuickMenuTemplate

--This game (sorry, "game"!) was built in about 10 hours as a demo challenge

--The "fruit" in this machine are themed on Signal to the Stars
--https://itunes.apple.com/app/signal-to-the-stars/id596795873
--https://play.google.com/store/apps/details?id=com.marmalade.signaltothestars


----------------------------------------------------------------------------
require("helpers/Utility")
dofile("Globals.lua")
require("helpers/VirtualResolution")

-- All code is in user coords - will be scaled to screen with fixed aspect ration and
-- letterboxes we can draw over
vr = virtualResolution
vr:initialise{userSpaceW=appWidth, userSpaceH=appHeight}

-- User space values of screen edges: for detecting edges of full screen area, including letterbox/borders
-- Useful for making sure things are on/off screen when needed
screenWidth = vr:winToUserSize(director.displayWidth)
screenHeight = vr:winToUserSize(director.displayHeight)

dofile("SceneMainMenu.lua")
dofile("SceneGame.lua")

device:enableVibration()

director:moveToScene(sceneMainMenu)


-- Shutdown/cleanup

function shutDownApp()
    dbg.print("Exiting app")
    system:quit()
end

function shutDownCleanup(event)
    dbg.print("Cleaning up app on shutdown")
    audio:stopStream()
end

system:addEventListener("exit", shutDownCleanup)
