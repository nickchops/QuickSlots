--- Back Button -------------------------------------

-- Helper to add a back button. Can be a visible button that responds to touch
-- and/or just a way to respond to pressing physical/default on-screen back key
-- (like Android's built-in back key)

-- The back key support checks for Marmalade's s3eKeyAbsBSK.
-- You need to set this to point to a real key via your ICF. e.g. to use "Esc"
-- on Win/Mac and "Back" (e.g. Android on screen back button) on anything else:
-- [s3e]
-- KeyAbsBSK = Back
-- {OS=WINDOWS}
-- KeyAbsBSK = Esc
-- {OS=OSX}
-- KeyAbsBSK = Esc


backButtonHelper = {}

--allow device's back button to operate on screen button
function backButtonHelper.keyListener(event)
    if not backButtonHelper.enabled then
        return
    end
    
    if event.keyCode == 210 and event.phase == "pressed" then -- 210 is the C++ code for s3eKeyAbsBSK
        if backButtonHelper.backBtn then
            backButtonHelper.pressBtn(true)
        else
            backButtonHelper.listener()
        end
    end
end

function backButtonHelper.touch(self, event)
    if self.touched and event.id ~= self.touched then
        return --ignore other fingers once pressed
    end
    if not event.target then -- listener being called for system, not node
        --note that node events are always called before system when they happen in same update/click
        if self.touched and event.id == self.touched and event.phase == "ended" then
            self.touched = nil
            if self.inUse and self.animatePress and self.activateOnRelease then
                cancelTweensOnNode(self.backBtn)
                self.releaseBtn(nil, true) -- animate back but dont fire listener
            end
        end
        return
    end
    -- listener called for node, not system now...
    
    if event.phase == "ended" then
        if self.enabled and self.touched and self.inUse and self.animatePress and self.activateOnRelease then
            cancelTweensOnNode(self.backBtn)
            self.releaseBtn()
        end
        self.touched = nil
        
    elseif event.phase == "began" then
        self.touched = event.id -- track which finger was held down on the node
        if self.enabled and not self.inUse then
            cancelTweensOnNode(self.backBtn) --in case we are pulsing
            if self.animatePress then
                self.inUse = true
                self.pressBtn(not self.activateOnRelease)
            else
                self.listener()
            end
        end
    end
end

function backButtonHelper.pressBtn(autoRelease)
    local onComplete = nil;
    if autoRelease then
        onComplete = backButtonHelper.releaseBtn
    end
    tween:to(backButtonHelper.backBtn, {xScale=backButtonHelper.btnScale*0.9, yScale=backButtonHelper.btnScale*0.9, time=0.2, onComplete=onComplete})
end

function backButtonHelper.releaseBtn(node, noEvent)
    -- can be called by onComplete, which will pass backButtonHelper.backBtn as "node"
    local onComplete = nil
    if not noEvent then
        onComplete = backButtonHelper.listener
    end
    tween:to(backButtonHelper.backBtn, {xScale=backButtonHelper.btnScale, yScale=backButtonHelper.btnScale, time=0.2, onComplete=onComplete})
    backButtonHelper.inUse = false
end

function backButtonHelper:add(listenerOrParamTable, xCentre, yCentre, btnWidth, btnTexture, pulse, activateOnRelease, animatePress, respondToKey, deviceKeyOnly, drawArrowOnBtn, arrowColor, arrowThickness, enabled)
    
    --allow passing a table of explicit param names
    if type(listenerOrParamTable) == "table" then
        xCentre = listenerOrParamTable.xCentre
        yCentre = listenerOrParamTable.yCentre
        btnWidth = listenerOrParamTable.btnWidth
        btnTexture = listenerOrParamTable.btnTexture
        drawArrowOnBtn = listenerOrParamTable.drawArrowOnBtn
        arrowColor = listenerOrParamTable.arrowColor
        arrowThickness = listenerOrParamTable.arrowThickness
        pulse = listenerOrParamTable.pulse
        activateOnRelease = listenerOrParamTable.activateOnRelease
        animatePress = listenerOrParamTable.animatePress
        respondToKey = listenerOrParamTable.respondToKey
        deviceKeyOnly = listenerOrParamTable.deviceKeyOnly
        self.listener = listenerOrParamTable.listener
        enabled = listenerOrParamTable.enabled
    else
        self.listener = listenerOrParamTable
    end
    
    --by default, animate and do action after push/release of button
    self.activateOnRelease = activateOnRelease or true
    self.animatePress = animatePress or true
    
    respondToKey = respondToKey or true
    arrowColor = arrowColor or color.black
    arrowThickness = arrowThickness or 2
    self.pulse = pulse
    
    self.added = true
    self.enabled = enabled or true
    
    if respondToKey then
        system:addEventListener("key", self.keyListener) -- allow key to press button
	end
    
    local keyOnly = false
	if deviceKeyOnly then
        if type(deviceKeyOnly) == "boolean" and deviceKeyOnly == true then
            keyOnly = true
        else
            local plat = device:getInfo("platform")
            if type(deviceKeyOnly) == "string" and deviceKeyOnly == "guess" then
                if plat == "ANDROID" or plat == "WP8" then
                    keyOnly = true
                end
            elseif type(deviceKeyOnly) == "table" then
                for k,v in pairs(deviceKeyOnly) do
                    if plat == v then
                        keyOnly = true
                    end
                end
            else
                dbg.assert("backButtonHelper: deviceKeyOnly value is invalid type")
            end
        end
    end

    if not keyOnly then
        self.backBtn = director:createSprite({x=appWidth/2, y=115, xAnchor=0.5, yAnchor=0.5, source=btnTexture})
        
        if not btnWidth then btnWidth = self.backBtn.w end
        self.btnScale = btnWidth/self.backBtn.w
        self.backBtn.xScale = self.btnScale
        self.backBtn.yScale = self.btnScale

        self.backBtn:addChild(director:createLines({x=self.backBtn.w/2, y=self.backBtn.h/2, coords={-15,20, -35,0, -15,-20, -15,-10, 35,-10, 35,10, -15,10, -15,20}, strokeColor=arrowColor, alpha=0, strokeWidth=arrowThickness}))

        self.backBtn:addEventListener("touch", self)
        system:addEventListener("touch", self)
        
        if pulse then
            tween:to(self.backBtn, {xScale=self.btnScale*1.1, yScale=self.btnScale*1.1, time=1.0, mode="mirror"})
        end
    end
end

function backButtonHelper:disable()
    self.enabled = false
    self.inUse = false
    if self.backBtn then
        cancelTweensOnNode(self.backBtn)
        tween:to(self.backBtn, {xScale=self.btnScale, yScale=self.btnScale, time=0.2})
    end
end

function backButtonHelper:enable()
    if self.enabled then
        return
    end
    self.enabled = true
    if self.backBtn and self.pulse then
        cancelTweensOnNode(self.backBtn)
        tween:to(self.backBtn, {xScale=self.btnScale*1.1, yScale=self.btnScale*1.1, time=1.0, mode="mirror"})
    end
end

function backButtonHelper:remove()
    if not self.listener then
        dbg.assert("Tried to disable back button that wasn't enabled")
        return
    end
    
    self.added = false

    system:removeEventListener("key", self.keyListener)

    if self.backBtn then
        self.backBtn:removeEventListener("touch", self)
        destroyNodesInTree(self.backBtn, true)
        self.backBtn = nil
    end
end
