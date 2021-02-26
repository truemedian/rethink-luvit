local Connection = require 'Connection'
local Logger = require 'Logger'

local function connect(...)
    local conn = Connection.new(...)

    assert(conn:connect())

    return conn
end

return {
    Connection = Connection,
    Logger = Logger,

    connect = connect,
}
