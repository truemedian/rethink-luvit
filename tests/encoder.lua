local Reql = require('Reql.lua')
local protocol = require('utils/protocol.lua')
local json = require 'json'

local test = require('./test.lua')

local read_query = Reql.raw.db('database').table('table').get('id')
local write_query = Reql.raw.db('database').table('table').insert({id = 'id', data = true})

local iterations = 100000

do
    local startingTime = test.currentTime()
    for i = 1, iterations do
        local serialized = protocol.serialize(read_query)
        json.encode(serialized)
    end
    local endingTime = test.currentTime()

    local serialized = protocol.serialize(read_query)
    local data = json.encode(serialized)

    local totalTime = endingTime - startingTime
    local averageTime = totalTime / iterations

    print(iterations .. ' Get Queries')
    print('  Total: ' .. test.formatTime(totalTime))
    print('  Avg:   ' .. test.formatTime(averageTime))
    print('  --> ' .. data)
end

do
    local startingTime = test.currentTime()
    for i = 1, iterations do
        local serialized = protocol.serialize(write_query)
        json.encode(serialized)
    end
    local endingTime = test.currentTime()

    local totalTime = endingTime - startingTime
    local averageTime = totalTime / iterations

    local serialized = protocol.serialize(write_query)
    local data = json.encode(serialized)

    print(iterations .. ' Insert Queries')
    print('  Total: ' .. test.formatTime(totalTime))
    print('  Avg:   ' .. test.formatTime(averageTime))
    print('  --> ' .. data)
end
