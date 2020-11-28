local wrappers = {}

function wrappers.argPassthrough(...)
    return ...
end

function wrappers.argArity0(opt)
    return {}, opt
end

function wrappers.argArity1(arg1, opt)
    return {arg1}, opt
end

function wrappers.argArity2(arg1, arg2, opt)
    return {arg1, arg2}, opt
end

function wrappers.argArity3(arg1, arg2, arg3, opt)
    return {arg1, arg2, arg3}, opt
end

function wrappers.argArity4(arg1, arg2, arg3, arg4, opt)
    return {arg1, arg2, arg3, arg4}, opt
end

function wrappers.argArityN(...)
    local args = {...}
    local opt = args[#args]

    if type(opt) == 'table' then
        for k in pairs(opt) do
            if type(k) ~= 'string' then
                return args
            end
        end

        args[#args] = nil
        return args, opt
    end

    return args
end

-- Automatically wrap the table passed to `insert' in a datum
function wrappers.insert(reql, args, opt)
    args[1] = reql.raw.datum(args[1])
    return args, opt
end

return wrappers
