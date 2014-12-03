
 --[[
    (C) Nick Smith 2013-2014
    On-screen button visual control for Marmalade Quick
    
    Implements a visual button on the screen which the user can press.
    Currently fairly simple but can be extended to use sprites etc.
    
    Create Pad
    ----------
    
    Uses table constructor:
        myPad = OnScreenButton.Create{...params...}
    
    Params:
    
    - name              Set an identifier
    - x                 Base and top centre point x
    - y                 Base centre point y. Top centre y will be .depth3d above
                        this point
    - radius            Radius
    - outline           Add an outline around top? Set to a color table to use
                        or nil (default) for no outline
    - topColor          Colour of top face
    - baseColor         Colour of base, i.e. the sides of the button
    - scale3d           Optional value from 0-1 to squash the circles by to
                        create 3D effect
    - depth3d           Amount to raise the top up from the base to create 3D
                        effect. Can set to 0, but hard to see button has been
                        pressed then!
    - autoRelease       Set to a timeout after which the button is
                        automatically released. Defaults to nil (never)
    
    Example:
        myButton = {x=appWidth-80, y=90, radius=40, topColor={0,200,0},
            outline={0,170,0}, baseColor={0,130,0}, scale3d=0.4, depth3d=8,
            autoRelease=0.35}
    
    myButton.origin
        After creation, .origin gives you the root Quick Node object you can
        use to move/hide/scale/etc. the whole thing.
    
    
    Activation and destruction
    --------------------------
    
    myButton:activate()
        Start checking for press/release events. Button won't animate, function
        set by setPressListener() and isDown() won't do anything until this is
        called.
    
    myButton:deactivate()
        Stop checking for events, updating isDown and calling press listener.
        
    myButton:destroy()
        Destroy all internals and remove from scene.
        Calls deactivate() if currently active.
    
    
    Getting values back: event handlers and polling
    -----------------------------------------------
    
    myButton:setPressListener(func)
        Set a callback function to be called on touch/release events
        Function must expect a single bool param. True indicates pressed,
        false indicates release. You usually want to set this up before
        calling activate() but don't need to. After deactivate(), the
        function just stops being called; no need to "unregister" it.

    myButton:isDown()
        Poll for whether the button is currently pressed. Returns a bool:
        true if depressed, false if not.
    
]]--


OnScreenButton = {}
OnScreenButton.__index = OnScreenButton

function OnScreenButton.Create(vals)
    local button = {}
    setmetatable(button,OnScreenButton)
    
    -- TODO: extend to allow images and non-3D (button would need to shrink or animates on press)
    
    button.name = vals.name or "button"
    button.x = vals.x
    button.y = vals.y -- y is centre of base and top rises by .depth3d (if 3D), but top is touchable area
    button.radius = vals.radius
    button.outline = vals.outline
    button.topColor = vals.topColor
    button.baseColor = vals.baseColor
    button.scale3d = vals.scale3d
    button.depth3d = vals.depth3d --positive value, depth up from base to top
    button.autoRelease = vals.autoRelease or nil -- time after which to release button automatically

    button.origin = director:createNode({x=button.x, y=button.y})
    
    button.base = director:createCircle({xAnchor=0.5, yAnchor=0.5, x=0, y=0,
           yScale=button.scale3d, radius=button.radius, strokeWidth=0, color=button.baseColor})
    button.mid = director:createRectangle({x=-button.radius, y=0, w=button.radius*2, h=button.depth3d,
           strokeWidth=0, color=button.baseColor, zOrder=1})
    button.top = director:createCircle({xAnchor=0.5, yAnchor=0.5, x=0, y=button.depth3d,
           yScale=button.scale3d, radius=button.radius, strokeWidth=0, color=button.topColor, zOrder=2})
    
    button.origin:addChild(button.base)
    button.origin:addChild(button.top)
    button.origin:addChild(button.mid)
    
    -- originally tried button.base:addChild(button.top), but touch propagation doesn't seem to work...
    -- touch area doesn't match up with top's actual position. Doesn't matter if yScale is used or not.
    -- maybe related to zOrder and/or parent/child... needs some investigation but avoiding for now
    
    if button.outline then
        button.top.strokeWidth=2
        button.top.strokeColor=button.outline
        button.top.radius = button.top.radius-1
    end
    
    button.touch = buttonTouch
    
    return button
end

function OnScreenButton:activate()
    if self.listening then
        dbg.print("already listening. ignoring OnScreenButton:activate()")
        return
    end
    self.top:addEventListener("touch", self)
    system:addEventListener("touch", self)
    self.listening = true
end

function OnScreenButton:deactivate()
    if self.listening then
        system:removeEventListener("touch", self)
        self.top:removeEventListener("touch", self)
        self.listening = false
    end
    if self.releaseTimer then
        self.releaseTimer:cancel()
        self.releaseTimer = nil
    end
end

function OnScreenButton:destroy()
    self:deactivate()
    self.mid:removeFromParent()
    self.top:removeFromParent()
    self.base:removeFromParent()
    self.origin:removeFromParent()
end

function buttonTouch(self, event)
    if self.touched and event.id ~= self.touched then
        return --ignore other fingers once pressed
    end
    
    if not event.target then
        -- global touch
        if self.touched and event.id == self.touched and event.phase == "ended" then
            -- touch released via system listener, could be on or off the button
            self:releaseButton()
            return true
        end
        return false
    end
    
    if event.phase == "began" then
        self.touched = event.id
        self.top.y=self.top.y-self.depth3d
        self.mid.h=0
        if self.pressListener then
            self.pressListener(true)
        end
        if self.autoRelease then
            self.releaseTimer = system:addTimer(self, self.autoRelease, 1) --use "timer" func
        end
    elseif event.phase == "ended" and self.touched then -- .touched false if already done by autoRelease timer
        self:releaseButton()
    end
    
    return true
end

function OnScreenButton:releaseButton()
    if self.releaseTimer then
        self.releaseTimer:cancel()
        self.releaseTimer = nil
    end
    self.top.y=self.top.y+self.depth3d
    self.mid.h=self.depth3d
    if self.pressListener then
        self.pressListener(false) --pass last on-pad coords
    end
    self.touched = nil --reset after listener so released finger id could be checked during that
end

function OnScreenButton:timer()
    self:releaseButton()
end

--func should be a function that expects a bool, true indicates pressed and false released
function OnScreenButton:setPressListener(func)
    self.pressListener = func
end

function OnScreenButton:isDown()
    if self.touched then
        return true
    else
        return false
    end
end
