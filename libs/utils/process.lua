local json = require 'json'

local Cursor = require 'Cursor.lua'
local Error = require 'Error.lua'

local protodef = require 'utils/protodef.lua'

local process = {}

function process.init(conn)
    conn.callbacks = {}
    conn.buffers = {}
end

local errcodes = {
    [protodef.Response.CLIENT_ERROR] = {name = 'CLIENT_ERROR', fn = Error.ReqlDriverError},
    [protodef.Response.COMPILE_ERROR] = {name = 'COMPILE_ERROR', fn = Error.ReqlCompileError},
    [protodef.Response.RUNTIME_ERROR] = {name = 'RUNTIME_ERROR', fn = Error.ReqlRuntimeError},
}

function process.handle(self, chunk)
    local callback = self.callbacks[chunk.token]
    local success, data = pcall(json.decode, chunk.data, 1, Cursor.null)

    if not success then
        if callback then
            self.logger:error('Recieved malformed JSON (%s): %s', chunk.token, data)
            return callback.fn(false, 'malformed json', chunk.data)
        else
            return self.logger:error('Recieved malformed JSON (%s, Invalid): %s', chunk.token, data)
        end
    end

    if not callback then
        return self.logger:warning('Invalid token: %s', chunk.token)
    end

    if callback.callee then
        self.logger:debug('<<< %i %s - from: %s ln %s', chunk.token, chunk.data, callback.callee.short_src,
                          callback.callee.currentline)
    end

    if data.t == protodef.Response.SUCCESS_ATOM then
        self.logger:debug('Response SUCCESS_ATOM received for token %s', chunk.token)

        local cursor = Cursor.new(data.r)
        callback.fn(true, cursor)

        if not callback.keepAlive then
            self.callbacks[chunk.token] = nil
        end
    elseif data.t == protodef.Response.SUCCESS_SEQUENCE then
        self.logger:debug('Response SUCCESS_SEQUENCE received for token %s', chunk.token)
        local buffer = self.buffers[chunk.token] or {}

        for _, row in ipairs(data.r) do
            table.insert(buffer, row)
        end

        local cursor = Cursor.new(buffer)
        callback.fn(true, cursor)

        if not callback.keepAlive then
            self.callbacks[chunk.token] = nil
        end

        self.buffers[chunk.token] = nil
    elseif data.t == protodef.Response.SUCCESS_PARTIAL then
        self.logger:debug('Response SUCCESS_PARTIAL received for token %s', chunk.token)
        local buffer = self.buffers[chunk.token] or {}

        for _, row in ipairs(data.r) do
            table.insert(buffer, row)
        end

        self.buffers[chunk.token] = buffer
    elseif errcodes[data.t] then
        local code = errcodes[data.t]
        local err = code.fn(code.name)

        self.logger:warning('Response %s received for token %s', code.name, chunk.token)

        local cursor = Cursor.new(data.r)
        callback.fn(false, cursor, err)

        self.callbacks[chunk.token] = nil
    else
        self.logger:warning('Response UNKNOWN (code %s) received for token %s', data.t, chunk.token)

        callback.fn(false, 'unknown response', data)
        self.callbacks[chunk.token] = nil
    end
end

return process
