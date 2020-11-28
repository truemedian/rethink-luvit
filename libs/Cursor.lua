---@class Cursor
---@field private array table
---@field private index number
---@field private closed boolean
local Cursor = {}
Cursor.null = {}

---@param array table
---@return Cursor
function Cursor.new(array)
    local self = setmetatable({}, Cursor)

    self.array = array
    self.index = 1
    self.closed = false

    return self
end

function Cursor:__index(index)
    if Cursor[index] then
        return Cursor[index]
    elseif type(index) == 'number' then
        return self.array[index]
    end
end

function Cursor:__ipairs()
    return Cursor.nextpair, self, 0
end

function Cursor:__pairs()
    return Cursor.nextpair, self, 0
end

function Cursor:__len()
    return #self.array
end

---@param last_index number|nil
---@return number|nil, any|nil
function Cursor:nextpair(last_index)
    if self.closed then
        return nil
    end

    if last_index then
        local data = self.array[last_index + 1]

        if data == nil then
            return nil
        elseif data == Cursor.null then
            data = nil
        end

        return last_index + 1, data
    else
        local data = self.array[self.index]
        self.index = self.index + 1

        if data == nil then
            self.closed = true

            return nil
        elseif data == Cursor.null then
            data = nil
        end

        return self.index - 1, data
    end
end

---@param last_index number|nil
---@return any|nil
function Cursor:next(last_index)
    local _, data = self:nextpair(last_index)

    return data
end

---@return nil
function Cursor:close()
    self.closed = true
    self.array = nil
end

return Cursor
