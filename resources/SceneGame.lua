
dofile("BackButton.lua")

sceneGame = director:createScene()
sceneGame.name = "game"

function sceneGame:setUp(event)
    virtualResolution:applyToScene(self)
    
    system:addEventListener({"suspend", "resume", "update"}, self)

    self.slotsbg = director:createSprite(0, 0, "textures/slotsbg.png")
    self.slotsbg.debugIdee = "slotsbg"
    self.slotsbg.y = appHeight-self.slotsbg.h - 50
    self.slotsbg.zOrder = 0
    
    local slotAtlas = director:createAtlas({width = 116, height = 338, numFrames = 14, textureName = "textures/reel_atlas.png",})
    
    math.randomseed(os.time())
    
    self.credit = 20
    self.bet = 0
    
    self.slots = {}
    
    for i=1, 3, 1 do
        local slotAnim = director:createAnimation({start = 1, count = 14, atlas = slotAtlas, delay = 1/30})
        self.slots[i] = director:createSprite({x=self.slotsbg.x+96+(i-1)*117, y=self.slotsbg.y+65, source=slotAnim})
        self.slots[i].slotAnim = slotAnim
        self.slots[i].animDelay = 1/30
        self.slots[i]:pause()
        self.slots[i].zOrder = -1
        self.slots[i].startFrame = math.random(1,7)*2-1
        self.slots[i]:setFrame(self.slots[i].startFrame)
    end
    
    self.handle = director:createSprite({x=self.slotsbg.x+518, y=self.slotsbg.y+348, xAnchor=0.5, yAnchor=0.5, source="textures/handle.png"})
    self.handle.touch = moveHandle
    self.maxHandle = self.handle.y
    self.minHandle = self.handle.y - 228
    
    self.handle.color = {100,100,100}
    
    self:makePayTable()
    
    local creditBox = director:createRectangle({x=50, y=self.slotsbg.y+400, w=250, h=50, color=color.black, strokeColor=goldColorDark})
    self.creditDisplay = director:createLabel({x=50+20, y=self.slotsbg.y+408, hAlignment="left", vAlignment="bottom", text="CREDIT: " .. self.credit, color=color.red, font="fonts/dosfont16.fnt", xScale=2, yScale=2})
    
    local betBox = director:createRectangle({x=50+250+30, y=self.slotsbg.y+400, w=130, h=50, color=color.black, strokeColor=goldColorDark})
    self.betDisplay = director:createLabel({x=50+250+30+20, y=self.slotsbg.y+408, hAlignment="left", vAlignment="bottom", text="BET: " .. self.bet, color=color.red, font="fonts/dosfont16.fnt", xScale=2, yScale=2})
    
    local creditBtnY = self.slotsbg.y + 50
    local bet1Btn = sceneGame:addButton("credit1", "BET 1\nCREDIT", 180, creditBtnY, appWidth/5, sceneGame.touch1Credit, 5, color.red)
    local betMaxBtn = sceneGame:addButton("creditMax", "BET MAX\nCREDIT", 180 + 170, creditBtnY, appWidth/5, sceneGame.touchMaxCredit, 5, color.red)
    
    --used for taking a screenshot with bits missing
    --in order to generate the game's icon!!
    --creditBox.isVisible = false
    --betBox.isVisible = false
    --self.creditDisplay.isVisible = false
    --self.betDisplay.isVisible = false
    --bet1Btn.isVisible = false
    --betMaxBtn.isVisible = false
end

function sceneGame:enterPostTransition(event)
end

function sceneGame:exitPreTransition(event)
    saveUserData()
end

function sceneGame:exitPostTransition(event)
    backButtonHelper:remove()
    destroyNodesInTree(sceneGame, false)
    self.slotsbg = nil
    self.slots = nil
    self.handle = nil
    self.btns = nil
    
    self:releaseResources()
    collectgarbage("collect")
    director:cleanupTextures()
end

sceneGame:addEventListener({"setUp", "enterPostTransition", "exitPreTransition", "exitPostTransition"}, sceneGame)

-------------------------------------------------------------

-- Main logic

sceneGame.items = {"berry", "bar", "bell", "berry", "berry", "melon", "seven"}

sceneGame.payTable = {{target={"seven","seven","seven"}, payout={2000,5000,15000}},
                      {target={"bell","bell","bell"}, payout={50,100,200}},
                      {target={"bar","bar","bar"}, payout={30,60,90}},
                      {target={"match","match","seven"}, payout={25,50,75}},
                      {target={"berry","berry","berry"}, payout={10,20,30}},
                      {target={"match","match","berry"}, payout={5,10,15}},
                      {target={"any","any","berry"}, payout={2,4,6}}
                     }


function sceneGame:startPlay()
    self.handle:addEventListener("touch", self.handle)
    if not self.spinning then
        system:addEventListener("touch", self)
        sceneGame.enableBetButtons()
    end
    
    if backButtonHelper.added then
        backButtonHelper:enable()
    else
        backButtonHelper:add({listener=self.quit, xCentre=appWidth/2, yCentre=200, btnWidth=appWidth/2,
                btnTexture=btnTexture, pulse=false, activateOnRelease=true, animatePress=true,
                deviceKeyOnly=false, drawArrowOnBtn=true, arrowThickness=5})
        
        if backButtonHelper.backBtn then -- in case we change to non-visible on Android etc!
            tween:from(backButtonHelper.backBtn, {alpha=0, time=0.2})
        end
    end
end

function sceneGame:pausePlay()
    self.handle:removeEventListener("touch", self.handle)
    system:removeEventListener("touch", self)
    backButtonHelper:disable()
    sceneGame.disableBetButtons()
end

function sceneGame.quit()
    audio:stopStream()
    system:removeEventListener({"suspend", "resume", "update", "touch"}, sceneGame)
    pauseNodesInTree(sceneGame)
    backButtonHelper:disable()
    director:moveToScene(sceneMainMenu, {transitionType="slideInL", transitionTime=0.8})
end

--------- Pay Table show/hide ---------

function sceneGame:makePayTable()
    self.payTableImg = director:createNode({x=0, y=0, radius = 5, zOrder=10})
    self.payTableImg.debugIdee = "paytable"
    
    local numrows = 0
    for i, row in ipairs(self.payTable) do
        for j, item in ipairs(row.target) do
            if (item ~= "any" and item ~= "match") or j == 1 then
                self.payTableImg:addChild(director:createSprite({x=(j-1)*55, y=(i-1)*-55, source="textures/" .. item .. ".png", xScale=0.5, yScale=0.5}))
            end
        end
        for j, item in ipairs(row.payout) do
            self.payTableImg:addChild(director:createLabel({x=200+(j-1)*100, y=((i-1)*-55)+10, hAlignment="left", vAlignment="bottom", text=item, color=titleCol, font=fontMain, xScale=1.3, yScale=1.3}))
            
            if i == 1 then
                self.payTableImg:addChild(director:createLabel({x=200+(j-1)*100, y=((i-2)*-55)+20, hAlignment="left", vAlignment="bottom", text=j .. "COIN", color=titleCol, font=fontMain, xScale=1.3, yScale=1.3}))
            end
        end
        numrows = i
    end
    
    local bg = director:createRectangle({x=-20, y=(numrows-1)*-55-30, w=550, h=(numrows+1)*55+40, color=color.black, strokeColor=titleCol, zOrder=-1})
    
    self.payTableImg:addChild(bg)
    
    self.payTableImg.bg = bg
    self.payTableImg.x = appWidth/2 - bg.w/2+20
    self.payTableImg.xOnScreen = self.payTableImg.x
    self.payTableImg.xOffScreen = appWidth-15
    self.payTableImg.y = appHeight/2 + bg.h/2-200
    
    self.greyOut = director:createRectangle({x=0, y=0, w=appWidth, h=appHeight, color=color.black, alpha=0.6, strokeWidth=0, zOrder=2})
    
    self.payTableShown()
end

function sceneGame.showPayTable()
    sceneGame.payTableImg.bg:removeEventListener("touch", sceneGame.showPayTable)
    sceneGame:pausePlay()
    tween:to(sceneGame.payTableImg, {x=sceneGame.payTableImg.xOnScreen, time=0.5, onComplete=sceneGame.payTableShown})
    tween:to(sceneGame.greyOut, {alpha=0.4, time=0.5})
end

function sceneGame.hidePayTable()
    system:removeEventListener("touch", sceneGame.hidePayTable)
    tween:to(sceneGame.payTableImg, {x=sceneGame.payTableImg.xOffScreen, time=0.5, onComplete=sceneGame.payTableHidden})
    tween:to(sceneGame.greyOut, {alpha=0, time=0.5})
end

function sceneGame.payTableHidden()
    sceneGame.payTableImg.bg:addEventListener("touch", sceneGame.showPayTable)
    sceneGame:startPlay()
end

function sceneGame.payTableShown()
    system:addEventListener("touch", sceneGame.hidePayTable)
end

-----------------------------------------------------------------

function sceneGame:touch(event)
    local x = vr:getUserX(event.x)
    local y = vr:getUserY(event.y)
    
    if event.phase == "moved" then
        if self.handle.inUse then
            if y <= self.minHandle then
                self.handle.y = self.minHandle
                self.handle.inUse = false
                self.handle.resetting = true
                
                -- start spin animation
                self.spinning = true
                self.spinFinished = 0
                
                audio:playStream("sounds/lever_pull.mp3")
                
                --in a real slots game, would ask server for value here (or later when timer expires)
                self.result = {math.random(1,7), math.random(1,7), math.random(1,7)}
                
                for i=1,3,1 do
                    sceneGame.slots[i].animDelay = 1/30
                    sceneGame.slots[i].slotAnim:setDelay(sceneGame.slots[i].animDelay)
                    sceneGame.slots[i]:setAnimation(sceneGame.slots[i].slotAnim)
                    self.slots[i]:play({startFrame = self.slots[i].startFrame, loopCount=0})
                    self.slots[i].slowDownCount = 3
                    local timer = system:addTimer(slotEndTimer, 1.5+i*1, 1)
                    timer.slotId = i
                end
                
            elseif y >= self.maxHandle then 
                self.handle.y = self.maxHandle
            else
                self.handle.y = y
            end
        end
    elseif event.phase == "ended" then
        if self.handle.inUse then
            self.handle.resetting = true
        end
    end
end

function slotEndTimer(event)
    local slot = sceneGame.slots[event.timer.slotId]
    slot.animDelay = slot.animDelay * 1.3
    slot.slotAnim:setDelay(slot.animDelay)
    slot:setAnimation(slot.slotAnim)
    
    slot.slowDownCount = slot.slowDownCount -1
    
    if slot.slowDownCount > 0 then
        local timer = system:addTimer(slotEndTimer, 0.4, 1)
        timer.slotId = event.timer.slotId
    end
end

function sceneGame:update(event)
    if pauseflag then
        pauseflag = false
        system:resumeTimers()
        resumeNodesInTree(self)
    end
    
    if self.spinning then
        for i=1,3,1 do
            if self.slots[i].slowDownCount == 0 then
                if self.slots[i].frame == self.result[i]*2-1 then
                    self.slots[i].startFrame = self.slots[i].frame
                    self.slots[i]:pause()
                    self.slots[i].slowDownCount = -1
                    self.spinFinished = self.spinFinished + 1
                end
            end
        end
        if self.spinFinished == 3 then
            self.spinning = false
            self:doResults()
        end
    end
    
    if self.handle.resetting then
        if self.handle.y < self.maxHandle then
            self.handle.y = self.handle.y + 400*system.deltaTime
            if self.handle.y > self.maxHandle then
                self.handle.y = self.maxHandle
            end
        else
            self.handle.resetting = false
        end
    end
end

function sceneGame:doResults()
    local winner = false
    local cashWon = 0
    local jackpot = false --todo
    
    for i, row in ipairs(self.payTable) do
        local matchCount = 0
        for j, item in ipairs(row.target) do
            if item == self.items[self.result[j]] then
                matchCount = matchCount + 1
            end
        end
        if matchCount == 3 then
            cashWon = row.payout[self.bet]
            winner = true
            break
        end
    end
    
    if winner then
        self.label = director:createLabel({x=appWidth/2-20, y=appHeight/4+50, hAlignment="center", vAlignment="bottom", text="! YOU WON: " .. cashWon .. " !", color=titleCol, font=fontMain, xScale=2, yScale=2})
        audio:playStream("sounds/coins_fall.mp3")
        self.credit = self.credit + cashWon
    else
        self.label = director:createLabel({x=appWidth/2-20, y=appHeight/4+50, hAlignment="center", vAlignment="bottom", text="TRY YOUR LUCK AGAIN", color=titleCol, font=fontMain, xScale=2, yScale=2})
    end
    
    tween:to(self.label, {alpha=0, time=0.3, mode="mirror"})
    system:addTimer(restartGame, 2, 1)
end

function restartGame(event)
    destroyNode(sceneGame.label)
    sceneGame.label = nil
    sceneGame:startPlay()
    sceneGame.bet = 0
    sceneGame.handle.color = {100,100,100}
    sceneGame.updateCredit()
end


-- pull handle events

function moveHandle(self, event)
    if event.phase == "began" and sceneGame.bet > 0 then
        self.inUse = true
        self:removeEventListener("touch", self)
        sceneGame.disableBetButtons()
    end
end

--- coin buttons

function sceneGame:addButton(name, text, x, y, width, touchListener, textX, btnColor)
    local btn = director:createSprite({x=x, y=y, xAnchor=0.5, yAnchor=0.5, source=btnTextureShort, color=btnColor})
    
    if not self.btns then
        self.btns = {}
    end
    self.btns[name] = btn
    
    btn.btnScale = width/btn.w

    btn.xScale = btn.btnScale
    btn.yScale = btn.btnScale
    btn.defaultScale = btn.btnScale
    
    --btn.x = btn.x+btn.w/2
    --btn.y = btn.y+btn.h/2
    
    sceneGame:addChild(btn)
    btn.label = director:createLabel({x=-width+textX, y=10, w=btn.w, h=btn.h, hAlignment="center", vAlignment="bottom", text=text, color=color.white, font=fontMain, xScale=2, yScale=2})
    btn:addChild(btn.label)

    btn.touch = touchListener
    return btn
end

function sceneGame.enableBetButtons()
    for k,v in pairs(sceneGame.btns) do
        v:addEventListener("touch", v)
        v.color=color.red
    end
end

function sceneGame.disableBetButtons()
    for k,v in pairs(sceneGame.btns) do
        v:removeEventListener("touch", v)
        v.color={100,0,0}
    end
end

function sceneGame.touch1Credit(self, event)
    if event.phase == "ended" then
        if sceneGame.bet < 3 and sceneGame.credit > 0 then
            sceneGame.bet = sceneGame.bet + 1
            sceneGame.credit = sceneGame.credit-1
        end
        
        tween:to(self, {xScale=self.btnScale*0.9, yScale=self.btnScale*0.9, time=0.1})
        tween:to(self, {xScale=self.btnScale, yScale=self.btnScale, time=0.1, delay=0.1, onComplete=sceneGame.updateCredit})
    end
end

function sceneGame.touchMaxCredit(self, event)
    if event.phase == "ended" then
        if sceneGame.bet < 3 and sceneGame.credit > 0 then
            local dif = 3 - sceneGame.bet
            sceneGame.credit = sceneGame.credit-dif
            sceneGame.bet = 3
            
            if sceneGame.credit < 0 then
                sceneGame.bet = sceneGame.bet + sceneGame.credit
                sceneGame.credit = 0
            end
        end
    
        tween:to(self, {xScale=self.btnScale*0.9, yScale=self.btnScale*0.9, time=0.1})
        tween:to(self, {xScale=self.btnScale, yScale=self.btnScale, time=0.1, delay=0.1, onComplete=sceneGame.updateCredit})
    end
end

function sceneGame.updateCredit()
    sceneGame.creditDisplay.text = "CREDIT: " .. sceneGame.credit
    sceneGame.betDisplay.text = "BET: " .. sceneGame.bet
    
    if sceneGame.bet > 0 then
        sceneGame.handle.color = color.white
    end
end

---- Pause/resume logic/anims on app suspend/resume ---------------------------

function sceneGame:suspend(event)
    dbg.print("suspending menus...")
	
    if not pauseflag then
        system:pauseTimers()
        pauseNodesInTree(self) --pauses timers and tweens
        saveUserData()
    end
	
    dbg.print("...menus suspended!")
end

function sceneGame:resume(event)
    dbg.print("resuming menus...")
    pauseflag = true
    dbg.print("...menus resumed")
end
