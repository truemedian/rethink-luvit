local json = require 'json'
local ssl = require 'openssl'
local net = require 'coro-net'

local Error = require 'Error.lua'
local Logger = require 'Logger.lua'
local Reql = require 'Reql.lua'
local Socket = require 'Socket.lua'

local protocol = require 'utils/protocol.lua'
local process = require 'utils/process.lua'
local crypto = require 'utils/crypto.lua'

local format = string.format
local pack = string.pack

---@class Connection
---@field private listeners table
---@field private options ConnectionOptions
---@field private last_token number
---@field public socket Socket
---@field public logger Logger
---@field public r Reql
---@field public reql Reql
local Connection = {}
Connection.__index = Connection

---@class ConnectionOptions
---@field host string
---@field port number
---@field username string
---@field password string
---@field database string
---@field logLevel number
---@field logFile string
---@field dateFormat string
local default_options = {
    host = '127.0.0.1',
    port = 28015,
    username = 'admin',
    password = '',
    database = 'test',
    logLevel = 3,
    logFile = 'luvitreql.log',
    dateFormat = '%F %T',
}

---@param opts ConnectionOptions
---@return Connection
function Connection.new(opts)
    local self = setmetatable({}, Connection)

    opts = opts or {}
    local options = {}

    for k, v in pairs(default_options) do
        if opts[k] == nil then
            options[k] = v
        else
            options[k] = opts[k]
        end
    end

    self.listeners = {}
    self.options = options
    self.logger = Logger.new(options.logLevel, options.dateFormat, options.logFile)

    self.last_token = 0

    self.r = Reql.new(self)

    if options.database == false then
        self.reql = self.r
    else
        self.reql = self.r.db(options.database)
    end

    process.init(self)
    return self
end

---@return boolean
function Connection:connect()
    if self.socket and not self.socket.closed then
        return true
    end

    return self:_connect(self.options.host, self.options.port)
end

---@return boolean
function Connection:_connect(host, port)
    self.logger:debug('Connecting to %s:%s', host, port)

    local read, write, handle, updateDecoder, updateEncoder, close =
        net.connect {host = host, port = port, encode = protocol.noop_encode, decode = protocol.noop_decode}

    if not read then
        return false,
               self:emit('connectionClosed', self.logger:error('Could not connect to %s:%s (%s)', host, port, write))
    end

    self.logger:info('Connected to %s:%s', host, port)
    self.socket = Socket.new(read, write, close, handle)

    self.socket:write(pack('<I4', 0x34c2bdc3))
    local success, res = pcall(json.decode, self.socket:read())
    if not success then
        self.socket:close()
        return false, self:emit('connectionClosed', self.logger:error('Could not authenticate: %s',
                                                                      Error.ReqlDriverError('error reading JSON data')))
    end

    local nonce = ssl.base64(ssl.random(18), true)
    local client_first_message = format('n=%s,r=%s', self.options.username, nonce)

    self.socket:write(json.encode {
        protocol_version = 0,
        authentication_method = 'SCRAM-SHA-256',
        authentication = 'n,,' .. client_first_message,
    } .. '\0')

    success, res = pcall(json.decode, self.socket:read())
    if not success then
        self.socket:close()
        return false, self:emit('connectionClosed', self.logger:error('Could not authenticate: %s',
                                                                      Error.ReqlDriverError('error reading JSON data')))
    end

    if not res.success then
        self.socket:close()
        return false, self:emit('connectionClosed',
                                self.logger:error('Could not authenticate: %s', Error.ReqlAuthError(res.error)))
    end

    local auth = {}
    local server_first_message = res.authentication
    for k, v in string.gmatch(server_first_message .. ',', '([rsi])=(.-),') do
        auth[k] = v
    end

    auth.i = tonumber(auth.i)
    if auth.r:sub(1, #nonce) ~= nonce then
        self.socket:close()
        return false, self:emit('connectionClosed', self.logger:error('Could not authenticate: %s',
                                                                      Error.ReqlDriverError('invalid nonce received')))
    end

    local client_final_message = 'c=biws,r=' .. auth.r
    local salted_password = crypto.pbkdf('sha256', self.options.password, ssl.base64(auth.s, false), auth.i, 32)
    if not salted_password then
        self.socket:close()
        return false, self:emit('connectionClosed',
                                self.logger:error('Could not authenticate: %s', Error.ReqlDriverError('salt error')))
    end

    local client_key = crypto.hmac('sha256', salted_password, 'Client Key')
    local stored_key = crypto.digest('sha256', client_key)
    local auth_message = table.concat({client_first_message, server_first_message, client_final_message}, ',')
    local client_signature = crypto.hmac('sha256', stored_key, auth_message)
    local client_proof = crypto.xor_string(client_key, client_signature)

    self.socket:write(json.encode {
        authentication = table.concat({client_final_message, ',p=', ssl.base64(client_proof, true)}),
    } .. '\0')

    success, res = pcall(json.decode, self.socket:read())
    if not success then
        self.socket:close()
        return false, self:emit('connectionClosed', self.logger:error('Could not authenticate: %s',
                                                                      Error.ReqlDriverError('error reading JSON data')))
    end

    if not res.success then
        self.socket:close()
        return false, self:emit('connectionClosed',
                                self.logger:error('Could not authenticate: %s', Error.ReqlAuthError(res.error)))
    end

    for k, v in string.gmatch(res.authentication .. ',', '([vV])=(.-),') do
        auth[k] = v
    end

    if not res.success then
        self.socket:close()
        return false, self:emit('connectionClosed', self.logger:error('Could not authenticate: %s',
                                                                      Error.ReqlDriverError('missing server signature')))
    end

    local server_key = crypto.hmac('sha256', salted_password, 'Server Key')
    local server_signature = crypto.hmac('sha256', server_key, auth_message)

    if not crypto.compare_digest(auth.v, server_signature) then
        self.socket:close()
        return false, self:emit('connectionClosed', self.logger:error('Could not authenticate: %s',
                                                                      Error.ReqlAuthError('invalid server signature')))
    end

    self.logger:debug('Authenticated with %s:%s', host, port)
    updateDecoder(protocol.decode)
    updateEncoder(protocol.encode)

    coroutine.wrap(function()
        for data in self.socket.read, self.socket do
            process.handle(self, data)
        end

        self:emit('connectionClosed', self.logger:warning('Connection to %s:%s closed', host, port))
    end)()

    return true, self:emit('connected')
end

---@param event string
---@param fn function
---@return function
function Connection:on(event, fn)
    self.listeners[event] = self.listeners[event] or {}

    table.insert(self.listeners[event], fn)

    return fn
end

---@param event string
---@vararg any
---@return nil
function Connection:emit(event, ...)
    if self.listeners[event] then
        for _, fn in ipairs(self.listeners[event]) do
            coroutine.wrap(fn)(...)
        end
    end
end

---@param event string
---@param fn function
---@return nil
function Connection:removeListener(event, fn)
    if self.listeners[event] then
        for i, v in ipairs(self.listeners[event]) do
            if v == fn then
                table.remove(self.listeners[event], i)
                break
            end
        end
    end
end

---@return number
---@return nil
function Connection:nextToken()
    self.last_token = self.last_token + 1
    return self.last_token
end

---@return nil
function Connection:close()
    return self.socket:close()
end

return Connection
