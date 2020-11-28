local fs = require 'fs'

local date = os.date
local format = string.format
local stdout = _G.process.stdout.handle
local openSync, writeSync = fs.openSync, fs.writeSync

local levels = {
    {'[ERROR]  ', 31}, -- red
    {'[WARNING]', 33}, -- yellow
    {'[INFO]   ', 32}, -- green
    {'[DEBUG]  ', 36}, -- cyan
}

do -- format levels
    for _, tag in ipairs(levels) do
        tag[2] = format('\27[1;%im%s\27[0m', tag[2], tag[1])
    end
end

---@class Logger
---@field public level number
---@field public datefmt string
---@field private file number
local Logger = {}
Logger.__index = Logger

---@param logLevel number
---@param dateFormat string
---@param logFile string
---@return Logger
function Logger.new(logLevel, dateFormat, logFile)
    local self = setmetatable({}, Logger)

    self.level = logLevel
    self.datefmt = dateFormat
    self.file = logFile and openSync(logFile, 'a')

    return self
end

---@param level number
---@param msg string
---@vararg any
---@return string|nil
function Logger:log(level, msg, ...)
    if level > self.level then
        return
    end

    local tag = levels[level]
    if not tag then
        return
    end

    msg = format(tostring(msg), ...)
    local d = date(self.datefmt)

    if self.file then
        writeSync(self.file, -1, format('%s | %s | %s\n', d, tag[1], msg))
    end

    stdout:write(format('%s | %s | %s\n', d, tag[2], msg))

    return msg
end

---@param level number
---@param msg string
---@vararg any
---@return string|nil
function Logger:error(level, msg, ...)
    return self:log(1, level, msg, ...)
end

---@param level number
---@param msg string
---@vararg any
---@return string|nil
function Logger:warning(level, msg, ...)
    return self:log(2, level, msg, ...)
end

---@param level number
---@param msg string
---@vararg any
---@return string|nil
function Logger:info(level, msg, ...)
    return self:log(3, level, msg, ...)
end

---@param level number
---@param msg string
---@vararg any
---@return string|nil
function Logger:debug(level, msg, ...)
    return self:log(4, level, msg, ...)
end

return Logger
