
 --[[
    (C) Nick Smith 2013-2014
    On-screen d-pad/joystick visual control for Marmalade Quick
    
    Implements a visual pad or stick on the screen which the user can control
    by touch.
    
    Create Pad
    ----------
    
    Uses table constructor:
        myPad = OnScreenDPad.Create{...params...}
        
    Pad can use two styles, controlled with "padType" param:
        1) "pad" style, with a visual base and a top circle. Touch and drag to
           move top circle around
        2) "joystick" style, with a pseudo-3D stick on screen that moves in the
           direction you drag
    
    You can set the size of the top and base circles using topRadius and
    baseRadius. If using joystick style then the ball on top is the size of
    topRadius and everything scales to match. For joysticks, no base circle is
    show but the size of that circle still determines total touchable area.
    
    Params:
    
    - name              Set an identifier
    - debugCircles      Show glowing circles for top and base. Useful for
                        debugging joystick style
    - x                 Pad/base initial centre point x
    - y                 Pad/base initial centre point y
    - topColor          Colour of top/touch point circle, nil -> light grey
    - baseColor         Colour of base circle, nil -> dark grey
    - topOutlineColor   Outline of top circle, nil -> no outline
    - stickArrowColor   Colour of up/down/left/right arrows for joystick style
    - topRadius         Radius of top circle - for joystick it determines
                        visual style of whole stick
    - baseRadius        Radius of base circle - determines touchable area of
                        pad/joystick. A good ratio is top:base = 1:3
    - moveRelative      If true, when user touches and moves, pad top moves
                        relative to finger.
                        If false (default), pad top jumps to position finger
                        initially touches, then moves with finger.
                        False is like a direction pad you touch directly, true
                        is good for gestures and joypad style.
    - alwaysRelocate    If true, pad base moves to be centred on point touched
                        when finger goes down if anywhere within the
                        relocateArea. If false and relocateArea is set, pad
                        moves if touch is in relocateArea but not overlapping
                        the base area. If both are false, the pad base is static
    - relocateArea      Optional area within which touching can cause the whole
                        pad to re-centre itself. Value is a table of format
                        {x,y,radius} or {x,y,rectW,rectH} (world coordinates).
    - resetOnRelease    Snap back to 0,0 on release. True by default.

    Example:
        myPad = OnScreenDPad.Create{x=100, y=50, padType="pad", topRadius=45,
            baseRadius=120, resetOnRelease=true, moveRelative=true,
            relocate=true, debugCircles=true}
    
    myPad.origin
        After creation, .origin gives you the root Quick Node object you can
        use to move/hide/scale/etc. the whole thing.
    
    
    Activation and destruction
    --------------------------
    
    myPad:activate()
        Start checking for touch events. Pad won't animate, function set by
        setMoveListener() and getX/Y() won't do anything until this is called.
    
    myPad:deactivate()
        Stop checking for touch events, updating X/Y and calling move listener
        
    myPad:destroy()
        Destroy all internals and remove from scene.
        Calls deactivate() if currently active.
    
    
    Getting values back: event handlers and polling
    -----------------------------------------------
    
    myPad:setMoveListener(func)
        Set a callback function to be called on touch/move events
        Function must expect params: (x, y, state). You usually want to set
        this up before calling activate() but don't need to. After deactivate()
        the function just stops being called; no need to "unregister" it.
        
    myPad:getX()
        Get current top X position in world/screen coords.
        
    myPad:getY()
        Get current top Y position in world/screen coords.

    NB: x and y are in world/screen coords. You might want to use functions
    from the following to scale them to work with your game logic:
        http://github.com/nickchops/MarmaladeQuickNodeUtility
        http://github.com/nickchops/MarmaladeQuickVirtualResolution
    
    
    TODO
    ----
    
    - Add support for having transparent circles for pads - i.e. allow just
      outline, with no fill.
    - Add support for sprites for top and base on pads.
    - Add out of the box support for using pads as non-analogue. e.g. pushing up
    - just fires an "up" event and has timers etc. to limit how often that
      occurs.
    
]]--


require("Utility")

OnScreenDPad = {}
OnScreenDPad.__index = OnScreenDPad

function OnScreenDPad.Create(vals)
    local pad = {}
    setmetatable(pad,OnScreenDPad)
    
    --"top" means the bit that moves with your finger
    --"base" means the area of the pad that stays still
    --"relocateArea" is an optional circle or rectangle you can touch within to
    --  relocate the pad's centre to the point touched
    
    pad.name = vals.name or "controlPad"
    pad.padType = vals.padType or "pad"
    -- "pad" is like a typical "big and small circle" on screen control stick
    -- "joystick" is a vector-built animated pseudo-3D stick viewed from front/top angle
    pad.debugCircles = vals.debugCircles or false
    -- to do: add "padPolys" and "padImage". These are typical circular touch
    -- pads, were baseCustom & topCustom are colours or images respectively
    pad.topCustom = nil
    pad.baseCustom = nil
    
    pad.x = vals.x
    pad.y = vals.y
    pad.topColor = vals.topColor or {100,100,100}
    pad.baseColor = vals.baseColor or {40,40,40}
    pad.topOutlineColor = vals.topOutlineColor
    pad.baseOutlineColor = vals.baseOutlineColor
    pad.stickArrowColor = vals.stickArrowColor or color.yellow
    pad.topRadius = vals.topRadius
    pad.baseRadius = vals.baseRadius
       -- for joystick style, topRadius determines visual sizes of whole stick. A good ratio is top:base = 1:3
    pad.moveRelative = vals.moveRelative or false
      -- if true, when user touches and moves, pad top moves relative to finger
      -- if false, pad top jumps to position finger initially touches, then moves with finger
      -- false is like a direction pad you touch direct, true is good for gestures
    pad.alwaysRelocate = vals.alwaysRelocate or false
      -- if true, pad base moves to be centred on point touched when finger goes down
      -- if anywhere within the relocateArea. If false and relocateArea is set, pad moves
      -- if touch is in relocateArea but not overlapping the base area. If both are
      -- false, the pad base is static
    pad.relocateArea = vals.relocateArea or nil
      -- Optional area within which touching can cause the whole pad to re-centre itself.
      -- Value is a table of format {x,y,radius} or {x,y,rectW,rectH}, all world coordinates.
    pad.resetOnRelease = vals.resetOnRelease or true --snap back to 0,0

    pad.origin = director:createNode({x=pad.x, y=pad.y})
    
    -- total touchable area of the pad
    pad.base = director:createCircle({xAnchor=0.5, yAnchor=0.5, x=0, y=0,
            radius=pad.baseRadius, strokeWidth=0, zOrder=-3})
    pad.origin:addChild(pad.base)
    pad.touch = baseTouch
    
    -- touched/moving area. This wont actually be under the finger if moveRelative is true and relocate is false.
    pad.top = director:createCircle({xAnchor=0.5, yAnchor=0.5, x=0, y=0,
            radius=pad.topRadius, strokeWidth=0, zOrder=-2})
    pad.origin:addChild(pad.top)
    
    if pad.padType == "joystick" then
        pad.base.alpha = 0
        pad.top.alpha = 0
        
        -- stick origin at base so it can pivot
        pad.joystick = director:createNode({x=0, y=-2*pad.topRadius})
        pad.origin:addChild(pad.joystick)
        
        -- 3-tone visual joystick ball
        local shadow = {math.max(pad.topColor[1]-20, 0), math.max(pad.topColor[2]-20, 0), math.max(pad.topColor[3]-20, 0)}
        local highlight = {math.min(pad.topColor[1]+20, 255), math.min(pad.topColor[2]+20, 255), math.min(pad.topColor[3]+20, 255)}
        
        pad.joystick.ball = director:createNode({x=0, y=pad.topRadius*2, zOrder=1})
        pad.joystick:addChild(pad.joystick.ball)
        pad.joystick.ball1 = director:createCircle({xAnchor=0.5, yAnchor=0.5, x=0, y=0,
                    radius=pad.topRadius, strokeWidth=0, color=shadow, zOrder=1})
        pad.joystick.ball2 = director:createCircle({xAnchor=0.5, yAnchor=0.5, x=0, y=0.25*pad.topRadius,
                    radius=pad.topRadius*0.88, yScale=0.8, strokeWidth=0, color=pad.topColor, zOrder=2}) -- was -3
        pad.joystick.ball3 = director:createCircle({xAnchor=0.5, yAnchor=0.5, x=0, y=0.48*pad.topRadius,
                    radius=pad.topRadius*0.72, yScale=0.6, strokeWidth=0, color=highlight, zOrder=3}) -- was -7
        pad.joystick.ball:addChild(pad.joystick.ball1)
        pad.joystick.ball:addChild(pad.joystick.ball2)
        pad.joystick.ball:addChild(pad.joystick.ball3)

        -- the stick part
        pad.joystick.stick = director:createRectangle({xAnchor=0.5, yAnchor=0, x=0, y=0,
                w=pad.topRadius*0.4, h=pad.topRadius*2-pad.topRadius*0.85, strokeWidth=0, color=pad.baseColor, zOrder=0})
        pad.joystick:addChild(pad.joystick.stick)
        pad.joystick:addChild(director:createCircle({xAnchor=0.5, yAnchor=0.5, x=0, y=0,
                    radius=pad.topRadius*0.16, yScale=0.5, strokeWidth=0, color=pad.baseColor, zOrder=0}))
        pad.joystick.sticktop = director:createCircle({xAnchor=0.5, yAnchor=0.5, x=0, y=pad.joystick.stick.h,
                    radius=pad.topRadius*0.16, yScale=0.4, strokeWidth=0, color=pad.baseColor, zOrder=0})
        pad.joystick:addChild(pad.joystick.sticktop)

        -- arrows at bottom
        pad.stickBase = director:createNode({x=0, y=-2*pad.topRadius, zOrder=-1}) --sit behind stick/top part
        pad.origin:addChild(pad.stickBase)
        
        local a = 0.4*pad.topRadius
        local b = 0.2*pad.topRadius
        local c = 0.56*pad.topRadius
        local d = 0.28*pad.topRadius
        local e = 0.36*pad.topRadius
        local f = 0.16*pad.topRadius
        
        pad.stickBase:addChild(director:createLines({x=0, y=0.36*pad.topRadius, coords={-a,0, 0,b, a,0, -a,0},
                    color=pad.stickArrowColor, strokeWidth=0}))
        pad.stickBase:addChild(director:createLines({x=0, y=-0.48*pad.topRadius, coords={-c,0, 0,-d, c,0, -c,0},
                    color=pad.stickArrowColor, strokeWidth=0}))
        pad.stickBase:addChild(director:createLines({x=-1.2*pad.topRadius, y=0, coords={-e,0, 0,-f, f,f, -e,0},
                    color=pad.stickArrowColor, strokeWidth=0}))
        pad.stickBase:addChild(director:createLines({x=1.2*pad.topRadius, y=0, coords={e,0, 0,-f, -f,f, e,0},
                    color=pad.stickArrowColor, strokeWidth=0}))
    else
        pad.base.color=pad.baseColor
        pad.top.color=pad.topColor
        
        if pad.baseOutlineColor then
            pad.base.strokeWidth=2
            pad.base.strokeColor=pad.baseOutlineColor
        end
        if pad.topOutlineColor then
            pad.top.strokeWidth=2
            pad.top.strokeColor=pad.topOutlineColor
        end
    end
    
    -- debugging
    if pad.debugCircles then
        pad.base.strokeWidth = 2
        pad.base.strokeColor=color.blue
        pad.top.strokeWidth = 2
        pad.top.strokeColor=color.green
        tween:to(pad.base, {time=0.7, strokeAlpha=0.1, mode="mirror"})
        tween:to(pad.top, {time=0.7, strokeAlpha=0.1, mode="mirror"})
    end
    
    return pad
end

function OnScreenDPad:activate()
    -- register both node and system listeners. System needed to check for release
    -- events when not overlapping the pad, otherwise it would stay touched!
    if self.listening then
        dbg.print("already listening. ignoring OnScreenDPad:activate()")
        return
    end
    self.base:addEventListener("touch", self)
    system:addEventListener("touch", self)
    self.listening = true
end

function OnScreenDPad:deactivate()
    if self.listening then
        system:removeEventListener("touch", self)
        self.base:removeEventListener("touch", self)
        self.listening = false
    end
end

function OnScreenDPad:destroy()
    self:deactivate()
    self.top:removeFromParent()
    self.base:removeFromParent()
    self.origin:removeFromParent()
end

function baseTouch(self, event)
    -- .touched tracks which finger if any is held down for the pad
    if self.touched and event.id ~= self.touched then
        return --ignore other fingers once pressed
    end
    
    if not event.target then
        -- global touch
        if self.touched and event.id == self.touched and event.phase == "ended" and self.resetOnRelease then
            -- touch released via system listener, could be on or off the pad
            if self.moveListener then
                self.moveListener(self.top.x, self.top.y, event.phase) --pass last on-pad coords
            end
            
            if self.resetOnRelease then -- reset after listener so it gets final coords
                self:reset()
            end
            self.touched = nil
        end
        return true
    end
    
    -- node touched
    if event.phase == "ended" then
        self.touched = nil
    elseif event.phase == "began" then
        self.touched = event.id
        if self.alwaysRelocate == true then
            self.origin.x = event.x
            self.origin.y = event.y
        end
    elseif not self.touched then
        return false --ignore moved events not started on the base
    end
    
    --NB: function from NodeUtility to get world coord as event.x/y are in world coords
    local parentX, parentY = getWorldCoords(self.origin)
    self.top.x = event.x - parentX
    self.top.y = event.y - parentY
    
    if self.joystick then
        if self.top.y ~= 0 then
            local joyY
            local stickH
            local joyScale = 1 - (0.15 / self.baseRadius * self.top.y)
            if self.top.y < 0 then
                joyY = self.topRadius*2 + (0.64*self.topRadius / self.baseRadius * self.top.y)
            else
                joyY = self.topRadius*2 + (0.32*self.topRadius / self.baseRadius * self.top.y)
            end
            if self.top.y > self.baseRadius /2 then
                self.joystick.ball.zOrder = -1
                stickH = joyY - self.topRadius * joyScale * (1 - (0.1 / self.baseRadius * self.top.y))
                self.joystick.sticktop.yScale = 0.3 * (self.top.y*2-self.baseRadius)/self.baseRadius
            else
                self.joystick.ball.zOrder = 1
                stickH = joyY
            end
            self.joystick.ball.y = joyY
            self.joystick.stick.h = stickH
            self.joystick.sticktop.y = stickH
            self.joystick.ball.xScale = joyScale
            self.joystick.ball.yScale = joyScale
        end
        if self.top.x ~= 0 then
            self.joystick.rotation = 45 / self.baseRadius * self.top.x
            self.joystick.ball.rotation = -self.joystick.rotation --keep highlights on "top"
        end
    end
    
    if self.moveListener then
        self.moveListener(self.top.x, self.top.y, event.phase)
    end
    
    if event.phase == "ended" and self.resetOnRelease then
        self:reset()
    end
    
    return true
end

function OnScreenDPad:reset()
    self.top.x = 0
    self.top.y = 0
    self.joystick.rotation = 0
    self.joystick.ball.rotation = 0
    self.joystick.ball.y = self.topRadius*2
    self.joystick.stick.h = self.topRadius*2
    self.joystick.ball.xScale = 1
    self.joystick.ball.yScale = 1
    self.joystick.ball.zOrder = 1
end

-- 'func' must be a function that expects params: (x, y, state)
function OnScreenDPad:setMoveListener(func)
    self.moveListener = func
end

-- NB x and y are in world/screen coords Might want to use functions from
-- following to scale them to work with your game logic:
-- http://github.com/nickchops/MarmaladeQuickNodeUtility
-- http://github.com/nickchops/MarmaladeQuickVirtualResolution
function OnScreenDPad:getX()
    return self.top.x
end

function OnScreenDPad:getY()
    return self.top.y
end
