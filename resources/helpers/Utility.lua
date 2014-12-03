
-- General utility functions for Lua for use with Marmalade Quick
-- (C) Nick Smith 2014


-- For lopping through number sequences
-- Min defaults to 1. min and max are inclusive. Easy to use with arrays
function circularIncrement(x, max, incBy, min)
    min = min or 1
    incBy = incBy or 1
    x = x + incBy
    if x > max then
        x = min
    elseif x < min then
        x = max
    end
    return x
end

function string.startswith(string1, string2)
   return string.sub(string1,1,string.len(string2))==string2
end

-- Analytics --

-- Add helper functions and values to analytics API ('analytics' is essentially a global table)
-- TODO: make these part of analytics itself

function analytics:setKeys(androidKey, iosKey)
    analytics.androidKey = androidKey
    analytics.iosKey = iosKey
end

function analytics:startSessionWithKeys()
    dbg.assert(analytics.androidKey, "Must call setFlurryKeys before startFlurrySession")
    
    if device:getInfo("platform") == "ANDROID" then
        analytics:startSession(analytics.androidKey)
    elseif device:getInfo("platform") == "IPHONE" then
        analytics:startSession(analytics.iosKey)
    end
end