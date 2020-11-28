
# Rethink Luvit

A database driver for rethinkdb for the [Luvit](https://luvit.io/) environment.

## Notice

Rethink Luvit was built with coroutines in mind, therefore `Connection:connect()` **must** be run inside of a coroutine. This may change in the future.

## Connecting

In order to obtain a Connection instance, you must call `Connection.new` and then use its `connect` method. For example:

```lua
local rethink = require('rethink-luvit')
local connection = rethink.Connection.new(options)

assert(connection:connect())

-- Start using `connection'
```

### Connection Options

`Connection.new` takes a table of optional arguments, these are listed below along with their defaults.
| Name       | Type   | Default         | Description                                                 |
|------------|--------|-----------------|-------------------------------------------------------------|
| host       | string | "127.0.0.1"     | The server's ip                                             |
| port       | number | 28015           | The server's port                                           |
| username   | string | "admin"         | The username to use for authentication                      |
| password   | string | ""              | The password to use for authentication                      |
| database   | string | "test"          | The database to prepend to all queries                      |
| logLevel   | number | 3 (Info)        | The maximum level of information log (see below)            |
| logFile    | string | "luvitreql.log" | The file to duplicate all log information into              |
| dateFormat | string | "%F %T"         | The format (as passed to os.date) to use for log timestamps |

### Log Levels

Rethink Luvit's Logger enumerates logLevel like so:
| Number | Name  | Description                                                                                   |
|--------|-------|-----------------------------------------------------------------------------------------------|
| 0      | -     | absolutely nothing.                                                                           |
| 1      | Error | fatal errors, such as authentication failures.                                                |
| 2      | Warn  | fatal and non-fatal errors (warnings), like connections closing and queries receiving errors. |
| 3      | Info  | errors, and basic information, such as a connection being formed successfully.                |
| 4      | Debug | errors, information, and debug information, including every query sent and received.          |

> Note: debug logging is not useful for most use cases, and *will* affect the performance of your application.

## Example (Synchronous)

```lua
local rethink = require('rethink-luvit')
local connection = rethink.Connection.new()

assert(connection:connect())

local success_insert = connection.table('table').insert({id = 1, test = 'wow'}):run()

local success_get, cursor = connection.table('table').get(1):run()

if success_get then
    for i, data in pairs(cursor) do
        p(data) -- p() is luvit's pretty print function
    end
end
```

## Example (Asynchronous)

```lua
local rethink = require('rethink-luvit')
local connection = rethink.Connection.new()

assert(connection:connect())

connection.table('table').insert({id = 1, test = 'wow'}):run(function(success)
    -- somehow resume here, insert completed
end)

-- somehow yield here, wait for insert to complete

connection.table('table').get(1):run(function(success, cursor)
    if success_get then
        for i, data in pairs(cursor) do
            p(data) -- p() is luvit's pretty print function
        end
    end
end)
```
