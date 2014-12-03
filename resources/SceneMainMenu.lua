
require("helpers/Utility")
require("helpers/NodeUtility")

-- These are user space coords for screen edges that will inc letterbox areas
-- that VirtualResolution has created
menuScreenMinX = appWidth/2 - screenWidth/2
menuScreenMaxX = appWidth/2 + screenWidth/2
menuScreenMinY = appHeight/2 - screenHeight/2
menuScreenMaxY = appHeight/2 + screenHeight/2

sceneMainMenu = director:createScene()
sceneMainMenu.name = "menu"


startupFlag = false -- for initial menu animation

 -- for easy scaling of buttons (all same size and texture)
local btnW = 400
local btnH
local btnScale

--------------------------------------------------------

function sceneMainMenu:startup()
    if gameInfo.soundOn then
        audio:playStreamWithLoop(titleMusic, true)
    end

    if not startupFlag then
        tween:from(self.mainMenu, {y=menuScreenMinY-100, time=0.5, onComplete=enableMainMenu})
    else
        enableMainMenu()
    end
end

function sceneMainMenu:setUp(event)
    dbg.print("sceneMainMenu:setUp")
    sceneMainMenu.alpha = 1
    
    system:addEventListener({"suspend", "resume", "update"}, self)

    -- turn scaling on for the scene
    virtualResolution:applyToScene(self)

    -- loads scores etc from local storage
    if not startupFlag then loadUserData() end

    self.background = director:createSprite(0, 0, "textures/vegas_lights_3.jpg")
    self.background.alpha=0
    tween:to(self.background, {alpha=1, time=2})
    
    -- sprites are scaled to file size by default. need to use xScale/yScale
    -- to change size, not w and h.
    --storing the scale factor is useful to scale relative to this later
    self.background.defaultScale = appHeight/self.background.h
    self.background.xScale = self.background.defaultScale
    self.background.yScale = self.background.defaultScale
    self.background.x = appWidth/2-self.background.w/2

    self.mainMenu = director:createNode({x=appWidth/2,y=appHeight-150})
    self.mainMenu.titleOutline = director:createLines({x=0, y=0, coords={-200,-50, -200,50, 200,50, 200,-50, -200,-50},
            strokeWidth=4, strokeColor=titleCol, alpha=0})
    self.mainMenu:addChild(self.mainMenu.titleOutline)
    self.mainMenu.titleText = director:createLabel({x=-156, y=-25, w=400, h=100,
            hAlignment="left", vAlignment="bottom", text="SIGNAL SLOTS", color=titleCol, font=fontMain, xScale=2, yScale=2})
    self.mainMenu:addChild(self.mainMenu.titleText)

    -- main menu buttons
    self.btns = {}
    local btnY = -200

    sceneMainMenu:addButton("start", "Start Game", btnY, touchStart, 70)

    --btnY = btnY - 150
    --sceneMainMenu:addButton("scores", "High Scores", btnY, touchScores, 55)

    btnY = btnY - 150
    sceneMainMenu:addButton("sound", "Sound: on", btnY, touchSound, 95)

    if not gameInfo.soundOn then
        self.btns.sound.alpha = 0.5
        self.btns.sound.label.text = "Sound: off"
    end

    if useQuitButton then
        btnY = btnY - 150
        sceneMainMenu:addButton("quit", "Quit", btnY, touchQuit, 150)
    end

    if not startupFlag then
		 --when transitioning from another scene, we don't want to do any animation or sound pre-transition
		 self:startup()
		 startupFlag = true
	 end
end

function sceneMainMenu:enterPostTransition(event)
    -- performed after transitioning from other scenes
    self:startup()
end

function sceneMainMenu:exitPreTransition(event)
    system:removeEventListener({"suspend", "resume", "update"}, self)
end

function sceneMainMenu:exitPostTransition(event)
    destroyNodesInTree(self.mainMenu, true)
    self.mainMenu = nil
    self.btns = nil

    self.background:removeFromParent()
    self.background = nil

    self:releaseResources()
    collectgarbage("collect")
    director:cleanupTextures()

    dbg.print("sceneMainMenu:exitPostTransition done")
end

sceneMainMenu:addEventListener({"setUp", "enterPostTransition", "exitPreTransition", "exitPostTransition"}, sceneMainMenu)


---- Button helpers -----------------------------------------------------------

function sceneMainMenu:addButton(name, text, btnY, touchListener, textX)
    self.btns[name] = director:createSprite({x=0, y=btnY, xAnchor=0.5, yAnchor=0.5, source=btnTexture}) --color=btnCol

    -- these two are re-used throughout rest of file
    if not btnScale then
        btnScale = btnW/self.btns.start.w
        btnH = self.btns.start.h * btnScale
    end

    self.btns[name].xScale = btnScale
    self.btns[name].yScale = btnScale
    self.btns[name].defaultScale = btnScale
    self.mainMenu:addChild(self.btns[name])
    self.btns[name].label = director:createLabel({x=textX, y=40, w=btnW, h=btnH, hAlignment="left", vAlignment="bottom", text=text, color=textCol, font=fontMain, xScale=2, yScale=2})
    self.btns[name]:addChild(self.btns[name].label)
    --NB: font scale is applied after x/yAnchor ofset so using those makes it very hard!
    --For text, better to use left/bottom and position manually.

    self.btns[name].touch = touchListener
end

-- control buttons being on/off to not break touch logic when moving in/out of menus
function enableMainMenu(target)
    for k,v in pairs(sceneMainMenu.btns) do
        v:addEventListener("touch", v)
    end
end

function disableMainMenu(target)
    for k,v in pairs(sceneMainMenu.btns) do
        v:removeEventListener("touch", v)
    end
end


---- Pause/resume logic/anims on app suspend/resume ---------------------------

function sceneMainMenu:suspend(event)
    dbg.print("suspending menus...")
	
    if not pauseflag then
        system:pauseTimers()
        pauseNodesInTree(self) --pauses timers and tweens
        saveUserData()
    end
	
    dbg.print("...menus suspended!")
end

function sceneMainMenu:resume(event)
    dbg.print("resuming menus...")
    pauseflag = true
    dbg.print("...menus resumed")
end

function sceneMainMenu:update(event)
    if pauseflag then
        pauseflag = false
        system:resumeTimers()
        resumeNodesInTree(self)
    end
end


---- Button handlers ----------------------------------------------------------

function menuStartGame()
    director:moveToScene(sceneGame, {transitionType="slideInR", transitionTime=0.8})
    audio:stopStream()
end

function touchStart(self, event)
    if event.phase == "ended" then
        disableMainMenu()
        tween:to(sceneMainMenu.btns.start, {xScale=btnScale*0.8, yScale=btnScale*0.8, time=0.2})
        tween:to(sceneMainMenu.btns.start, {xScale=btnScale, yScale=btnScale, time=0.2, delay=0.2, onComplete=menuStartGame})
        cancelTweensOnNode(sceneMainMenu.background)
        tween:to(sceneMainMenu.background, {alpha=0, time=0.2})
        tween:to(sceneMainMenu, {alpha=0, time=0.4})
        tween:to(sceneMainMenu.mainMenu.titleOutline, {strokeAlpha=0, time=0.4})
    end
end

function touchScores(self, event)
    if event.phase == "ended" then
        disableMainMenu()
        tween:to(sceneMainMenu.btns.scores, {xScale=btnScale*0.8, yScale=btnScale*0.8, time=0.2})
        tween:to(sceneMainMenu.btns.scores, {xScale=btnScale, yScale=btnScale, time=0.2, delay=0.2})
        tween:to(sceneMainMenu.mainMenu, {x=menuScreenMinX-300, time=0.5, delay=0.3, onComplete=menuDisplayHighScores})
    end
end

function touchSound(self, event)
    if event.phase == "ended" then
        if gameInfo.soundOn then
            audio:stopStream()
            gameInfo.soundOn = false
            sceneMainMenu.btns.sound.alpha = 0.5
            sceneMainMenu.btns.sound.label.text = "Sound: off"
        else
            audio:playStreamWithLoop(titleMusic, true)
            gameInfo.soundOn = true
            sceneMainMenu.btns.sound.alpha = 1
            sceneMainMenu.btns.sound.label.text = "Sound: on"
        end
    end
end


function touchQuit(self, event)
    if event.phase == "ended" then
        saveUserData() -- save settings
        tween:to(sceneMainMenu.btns.quit, {xScale=btnScale*0.8, yScale=btnScale*0.8, time=0.2})
        tween:to(sceneMainMenu.btns.quit, {xScale=btnScale, yScale=btnScale, time=0.2, delay=0.2, onComplete=menuDisplayHighScores})
        tween:to(sceneMainMenu.btns.quit, {xScale=0.8, yScale=0.8, time=0.2, delay=0.2, onComplete=shutDownApp})
    end
end


---- High scores sub menu -----------------------------------------------------

function menuDisplayHighScores(target)
    -- create title and list of scores off screen
    sceneMainMenu.scoreLabels = director:createNode({x=menuScreenMaxX+300, y=appHeight-100})
    sceneMainMenu.scoreLabels.title = director:createLabel({x=0, y=0, w=250, h=50, xAnchor=0.5, xScale=2, yScale=2,
            yAnchor=0.5, hAlignment="center", vAlignment="bottom", text="HIGH SCORES", color=titleCol, font=fontMainTitle})
    sceneMainMenu.scoreLabels:addChild(sceneMainMenu.scoreLabels.title)

    local labelY=-120

    for k,v in ipairs(gameInfo.scores) do
        local scoreText = gameInfo.scores[k].name .. "  " .. string.format("%08d", gameInfo.scores[k].score)
        sceneMainMenu.scoreLabels[k] = director:createLabel({x=0, y=labelY, w=250, h=30, xAnchor=0.5, yAnchor=0.5, hAlignment="center", vAlignment="bottom", text=scoreText, color=textCol, font=fontMain})
        labelY=labelY-50
        sceneMainMenu.scoreLabels:addChild(sceneMainMenu.scoreLabels[k])
    end

    --animate moving onto screeen and show back button when done
    tween:to(sceneMainMenu.scoreLabels, {time=0.5, x=appWidth/2, onComplete=menuHighScoresShown})
end

function menuHighScoresShown(target)
    sceneMainMenu:addBackButton(menuCloseHighScores)
end

function menuCloseHighScores(event)
    if event.phase == "ended" then
        destroyNodesInTree(sceneMainMenu.scoreLabels, true)
        sceneMainMenu.scoreLabels = nil
        sceneMainMenu:removeBackButton(menuCloseHighScores)

        tween:to(sceneMainMenu.mainMenu, {x=appWidth/2, time=0.5, onComplete=enableMainMenu})
    end
end


---- buttons and handler to close sub-menus (high scores, etc) ----------------

--allow device's back button to operate on screen button
function menuBackKeyListener(event)
    if event.keyCode == 210 and event.phase == "pressed" then -- 210 is the C++ code for s3eKeyAbsBSK (e.g. the back soft key on Android)
        sceneMainMenu.backKeyListener({phase="ended"})
    end
end

function sceneMainMenu:addBackButton(listener)
    sceneMainMenu.backKeyListener = listener
    system:addEventListener("key", menuBackKeyListener) -- allow key to press button

    self.backBtn = director:createSprite({x=appWidth/2, y=115, xAnchor=0.5, yAnchor=0.5, source=btnTexture, color=btnCol})
    self.backBtn.xScale = btnScale
    self.backBtn.yScale = btnScale

    self.backBtn:addChild(director:createLines({x=btnW/2, y=btnH/2, coords={-15,20, -35,0, -15,-20, -15,-10, 35,-10, 35,10, -15,10, -15,20}, strokeColor=textCol, alpha=0, strokeWidth=5}))

    self.backBtn:addEventListener("touch", listener)
    tween:to(self.backBtn, {xScale=btnScale*1.1, yScale=btnScale*1.1, time=1.0, mode="mirror"})
end

function sceneMainMenu:removeBackButton(listener)
    if not self.backBtn then
        dbg.print("Tried to remove non existant back button")
        return
    end

    system:removeEventListener("key", menuBackKeyListener)

    self.backBtn:removeEventListener("touch", listener)
    destroyNodesInTree(self.backBtn, true)
    self.backBtn = nil
end


---- Save/load data -----------------------------------------------------------

function saveUserData(clearHighScoreFlag)
    local gameDataPath = system:getFilePath("storage", "gameData.txt")
    local file = io.open(gameDataPath, "w")
    if not file then
        dbg.print("failed to open game data file for saving: " .. gameDataPath)
    else
        file:write(json.encode({scores=gameInfo.scores, achievements=gameInfo.achievements, lastUserName = gameInfo.lastUserName, soundOn=gameInfo.soundOn}))
        file:close()
        dbg.print("game data saved")
    end

    if clearHighScoreFlag then
        gameInfo.newHighScore = nil
    end
end

-- Check for new high score and save if exists.
-- Could be called from the game scene periodically...
-- Typically you would want the user to enter name/connect to game service on game over.
-- This function autosaves with curent name for safety in case app closes before name entry.
function checkNewHighScoreAndSave()
    gameInfo.newHighScore = nil
    for k,v in pairs(gameInfo.highScore) do
        if gameInfo.score > v.score then
            gameInfo.newHighScore = k
            dbg.print("New high score!")
            for n=10, k+1, -1 do --shuffles old scores down one place
                gameInfo.highScore[n].score = gameInfo.highScore[n-1].score
                gameInfo.highScore[n].name = gameInfo.highScore[n-1].name
            end
            gameInfo.highScore[k].score = gameInfo.score
            gameInfo.highScore[k].name = gameInfo.name
            break
        end
    end

    if gameInfo.newHighScore then
        saveUserData()
    end

    return gameInfo.newHighScore -- allow quick checking if a score was set
end

function loadUserData()
    -- load highscore from JSON encoded lua value
    local gameDataPath = system:getFilePath("storage", "gameData.txt")
    local file = io.open(gameDataPath, "r")
    if not file then
        dbg.print("game data file not found at: " .. gameDataPath)
    else
        local loaded = json.decode(file:read("*a")) -- "*a" = read the entire file contents
        gameInfo.scores = loaded.scores
        gameInfo.lastUserName = loaded.lastUserName
        gameInfo.achievements = loaded.achievements
        gameInfo.soundOn = loaded.soundOn
        file:close()
        dbg.print("game data loaded")
    end
end
