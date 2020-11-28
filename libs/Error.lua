---@class Error
---@field public name string
---@field public path string
---@field public message string
---@field public term string
---@field public frames table

---@class ReqlErrors
---@field public ReqlCompileError Error
---@field public ReqlDriverError Error
---@field public ReqlAuthError Error
---@field public ReqlRuntimeError Error
---@field public ReqlResourceLimitError Error
---@field public ReqlUserError Error
---@field public ReqlInternalError Error
---@field public ReqlTimeoutError Error
---@field public ReqlPermissionsError Error
---@field public ReqlQueryLogicError Error
---@field public ReqlNonExistenceError Error
---@field public ReqlAvailabilityError Error
---@field public ReqlOpFailedError Error
---@field public ReqlOpIndeterminateError Error
local errors = {}

local hierarchy = {
    ReqlCompileError = 'ReqlError',
    ReqlDriverError = 'ReqlError',
    ReqlAuthError = 'ReqlDriverError',
    ReqlRuntimeError = 'ReqlError',
    ReqlResourceLimitError = 'ReqlRuntimeError',
    ReqlUserError = 'ReqlRuntimeError',
    ReqlInternalError = 'ReqlRuntimeError',
    ReqlTimeoutError = 'ReqlRuntimeError',
    ReqlPermissionsError = 'ReqlRuntimeError',
    ReqlQueryLogicError = 'ReqlRuntimeError',
    ReqlNonExistenceError = 'ReqlQueryLogicError',
    ReqlAvailabilityError = 'ReqlRuntimeError',
    ReqlOpFailedError = 'ReqlAvailabilityError',
    ReqlOpIndeterminateError = 'ReqlAvailabilityError',
}

local function calculateHierarchy(str)
    local previous = hierarchy[str]

    if type(previous) == 'string' then
        previous = calculateHierarchy(previous)
    else
        return {str}
    end

    previous[#previous + 1] = str

    hierarchy[str] = previous
    return previous
end

for k in pairs(hierarchy) do
    calculateHierarchy(k)
end

for k, v in pairs(hierarchy) do
    hierarchy[k] = table.concat(v, '/')
end

local metatable = {
    __tostring = function(self)
        return self.message
    end,
}

local function factory(errorName, topLevelName)
    return function(message, term, frames)
        if term then
            frames = type(frames) == 'table' and frames or {}

            message = ('%s | %s in: %s (%s)'):format(errorName, message, term, table.concat(frames, ', '))
        else
            message = ('%s | %s'):format(errorName, message)
        end

        return setmetatable({name = topLevelName, path = errorName, message = message, term = term, frames = frames},
                            metatable)
    end
end

function errors.__index(self, name)
    local fullName = hierarchy[name]

    if fullName then
        self[name] = factory(hierarchy[name], name)
        return self[name]
    else
        return nil
    end
end

return setmetatable({}, errors)
