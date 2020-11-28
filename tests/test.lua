local uv = require 'uv'

local test = {}

local S_PER_MIN = 60
local MS_PER_S = 1000
local US_PER_MS = 1000
local NS_PER_US = 1000

local NS_PER_MS = NS_PER_US * US_PER_MS
local NS_PER_S = NS_PER_MS * MS_PER_S
local NS_PER_MIN = NS_PER_MS * MS_PER_S * S_PER_MIN

local modf, fmod = math.modf, math.fmod

local MB_PER_GB = 1024
local KB_PER_MB = 1024
local B_PER_KB = 1024

local B_PER_MB = B_PER_KB * KB_PER_MB
local B_PER_GB = B_PER_MB * MB_PER_GB

function test.prepare(agressive_gc)
    if agressive_gc == true then
        -- This makes the garbage collector as agressive as possible (very slow)
        collectgarbage('setpause', 0)
        collectgarbage('setstepmul', 1e16)
    elseif agressive_gc == false then
        -- This essentially disables the garbage collector
        collectgarbage('setpause', 1e16)
        collectgarbage('setstepmul', 0)
    end

    collectgarbage()
end

function test.formatMemory()
    local mem = collectgarbage 'count'

    return ('%s GB %s MB %s KB %s B'):format(modf(mem / B_PER_GB), modf(fmod(mem / B_PER_MB, MB_PER_GB)),
                                             modf(fmod(mem / B_PER_KB, KB_PER_MB)), modf(fmod(mem, B_PER_KB)))
end

function test.currentTime()
    return uv.hrtime()
end

function test.formatTime(ns)
    return ('%s min %s sec %s ms %s us %s ns'):format(modf(ns / NS_PER_MIN), modf(fmod(ns / NS_PER_S, S_PER_MIN)),
                                                      modf(fmod(ns / NS_PER_MS, MS_PER_S)),
                                                      modf(fmod(ns / NS_PER_US, US_PER_MS)), modf(fmod(ns, NS_PER_US)))
end

function test.run(fn)
    coroutine.wrap(fn)()
end

return test
