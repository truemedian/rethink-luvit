---@class Socket
---@field private closed boolean
local Socket = {}
Socket.__index = Socket

---@param read function
---@param write function
---@param close function
---@param handle userdata
---@return Socket
function Socket.new(read, write, close, handle)
    local self = setmetatable({}, Socket)

    self._read = read
    self._write = write
    self._close = close
    self.handle = handle
    self.closed = false

    return self
end

---@return string
function Socket:read()
    local data, err = self._read()

    if data ~= nil then
        return data
    else
        self.closed = true
        return data, err
    end
end

---@param item table
---@return boolean
function Socket:write(item)
    local success, err = self._write(item)

    if success ~= nil then
        return success
    else
        self.closed = true
        return success, err
    end
end

---@return nil
function Socket:close()
    self.closed = true
    self._close()
end

return Socket
