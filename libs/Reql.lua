local json = require 'json'

local Error = require 'Error.lua'

local protocol = require 'utils/protocol.lua'
local protodef = require 'utils/protodef.lua'
local wrappers = require 'utils/wrappers.lua'

---@class Reql
---@field public conn Connection
---@field public root boolean
---@field public parent Reql|nil
---@field private internal table
local Reql = {}

local term_wrappers = {
    datum = wrappers.argPassthrough,
    between = wrappers.argArity4,
    between_deprecated = wrappers.argArity4,
    changes = wrappers.argArityN,
    circle = wrappers.argArityN,
    delete = wrappers.argArityN,
    distance = wrappers.argArityN,
    distinct = wrappers.argArityN,
    during = wrappers.argArity4,
    eq_join = wrappers.argArityN,
    filter = wrappers.argArity3,
    fold = wrappers.argArityN,
    get_all = wrappers.argArityN,
    get_intersecting = wrappers.argArityN,
    get_nearest = wrappers.argArityN,
    group = wrappers.argArityN,
    http = wrappers.argArity3,
    index_create = wrappers.argArityN,
    index_rename = wrappers.argArityN,
    insert = wrappers.argArity3,
    iso8601 = wrappers.argArityN,
    js = wrappers.argArityN,
    make_obj = wrappers.argArity0,
    max = wrappers.argArityN,
    min = wrappers.argArityN,
    order_by = wrappers.argArityN,
    random = wrappers.argArityN,
    reconfigure = wrappers.argArity2,
    reduce = wrappers.argArityN,
    replace = wrappers.argArity3,
    slice = wrappers.argArityN,
    table = wrappers.argArityN,
    table_create = wrappers.argArityN,
    union = wrappers.argArityN,
    update = wrappers.argArity3,
    wait = wrappers.argArity2,
}

function Reql:__index(key)
    if Reql[key] then
        return Reql[key]
    else
        local wrapper = term_wrappers[key]

        if protodef.Term[key] then
            return function(...)
                local args, optargs

                if wrapper then
                    args, optargs = wrapper(...)
                else
                    args = {...}
                end

                if wrappers[key] then
                    args, optargs = wrappers[key](self, args, optargs)
                end

                return Reql.create(self, key, args, optargs)
            end
        end
    end
end

Reql.__typename = 'Reql'
---@type Reql
Reql.raw = setmetatable({root = true}, Reql)

---@param conn Connection
---@return Reql
function Reql.new(conn)
    local self = setmetatable({}, Reql)

    self.conn = conn
    self.root = true

    local node = self

    return node
end

function Reql.create(parent, term, args, optargs)
    local self = setmetatable({}, Reql)

    self.parent = parent
    self.conn = parent.conn
    self.internal = {term = term, termi = protodef.Term[term], args = args, optargs = optargs}

    return self
end

local empty_optarg = setmetatable({}, {__jsontype = 'object'})

---@param options ?table
---@param callback ?function
---@return boolean, Cursor
function Reql:run(options, callback)
    if type(options) == 'function' then
        callback = options
        options = nil
    end

    options = options or {}

    local conn = options.connection or self.conn

    if not conn then
        self.conn.logger:error('Cannot run raw query without options.connection.')
        local err = Error.ReqlDriverError('Connection missing.')

        if callback then
            callback(false, err)
        end

        return false, err
    end

    if conn.socket.closed then
        conn.logger:error('Connection is closed, cannot run query.')
        local err = Error.ReqlDriverError('Connection is closed.')

        if callback then
            callback(false, err)
        end

        return false, err
    end

    local query = {protodef.Term.datum, protocol.serialize(self), options.optargs or empty_optarg}
    local token = options.token or conn:nextToken()

    local success, encoded = pcall(json.encode, query)
    if not success then
        conn.logger:error('Failed to encode query.')
        local err = Error.ReqlUserError('query could not be encoded.')

        if callback then
            callback(false, err, encoded)
        end

        return false, err, encoded
    end

    local should_yield
    if not callback then
        local thread = coroutine.running()

        if not thread then
            conn.logger:error('Cannot run a query outside of a coroutine without a callback.')
            local err = Error.ReqlUserError('no coroutine or callback provided to run.')

            return false, err
        end

        should_yield = true
        callback = function(...)
            -- TODO: replace this with luvit/utils's assertResume
            assert(coroutine.resume(thread, ...))
        end
    else
        should_yield = false
    end

    conn.logger:debug('>>> %i %s', token, encoded)
    conn.callbacks[token] = {fn = callback, callee = debug.getinfo(2, 'Sl')}

    coroutine.wrap(conn.socket.write)(conn.socket, {token = token, data = encoded})

    if should_yield then
        return coroutine.yield()
    end
end

return Reql
