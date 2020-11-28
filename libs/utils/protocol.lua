local protocol = {}

function protocol.decode(buffer, index)
    local head = buffer:sub(index, index + 12)

    local token, length = string.unpack('<I8I4', head)

    local start_index = index + 12
    local end_index = start_index + length - 1

    if #buffer > end_index then
        return {token = token, data = buffer:sub(start_index, end_index)}, end_index + 1
    elseif #buffer == end_index then
        return {token = token, data = buffer:sub(start_index, end_index)}
    else
        return nil
    end
end

function protocol.noop_decode(buffer, index)
    return buffer
end

function protocol.encode(item)
    local data = item.data

    return string.pack('<I8I4', item.token, #data) .. data
end

function protocol.noop_encode(item)
    return item
end

function protocol.serialize_args(insert, args)
    local new = {}

    for i, arg in pairs(args) do
        if insert then
            i = i + 1
        end

        local metatable = getmetatable(arg)

        if metatable and metatable.__typename == 'Reql' then
            new[i] = protocol.serialize(arg)
        else
            new[i] = arg
        end
    end

    return new
end

function protocol.serialize(reql)
    local arguments = protocol.serialize_args(not reql.parent.root, reql.internal.args)
    local current = {reql.internal.termi, arguments, reql.internal.optargs}
    local query = current

    while not reql.parent.root do
        reql = reql.parent

        arguments = protocol.serialize_args(not reql.parent.root, reql.internal.args)
        current[2][1] = {reql.internal.termi, arguments, reql.internal.optargs}
        current = current[2][1]
    end

    return query
end

return protocol
