local ssl = require 'openssl'

local test = require('./test.lua')

local rethink = require('../init.lua')
local connection = rethink.Connection.new({host = '127.0.0.1', port = 28020, db = false, logLevel = 3})

test.run(function()
    connection:connect()

    print('Starting 2000 query stress test')
    test.prepare(nil)

    local db_name = ssl.base64(ssl.random(40)):gsub('=', ''):gsub('/', ''):gsub('+', '')

    local startingMem = test.formatMemory()
    local startingTime = test.currentTime()

    connection.r.db_create(db_name):run()
    connection.r.db(db_name).table_create('table'):run()

    local waiting = 1000
    local thread = coroutine.running()
    local function done()
        waiting = waiting - 1

        if waiting == 0 then
            assert(coroutine.resume(thread))
        end
    end

    for i = 1, 1000 do
        connection.r.db(db_name).table('table').insert({id = i * i, test = 'wow'}):run(done)
    end

    coroutine.yield()
    waiting = 1000

    for i = 1, 1000 do
        connection.r.db(db_name).table('table').get(i * i):run(done)
    end

    coroutine.yield()

    connection.r.db_drop(db_name):run()

    assert(connection.last_token == 2003)

    connection:close()

    local endingMem = test.formatMemory()
    local endingTime = test.currentTime()

    print('Test Took:    ' .. test.formatTime(endingTime - startingTime))
    print('Pre Testing:  ' .. startingMem)
    print('Post Testing: ' .. endingMem)
end)
