-- src/protocol.lua
-- PGEC Protocol Command Parsing

local protocol = {}

-- Parse PGEC command
-- Format: command(param1)label(param2)label(param3)
function protocol.parse(message)
    local cmd = {}
    
    -- Extract command name (before first parenthesis)
    cmd.command = message:match("^([^(]+)")
    
    if not cmd.command then
        return nil, "Invalid command format"
    end
    
    -- Extract all parameters
    cmd.params = {}
    
    -- Match pattern: label(value)
    for label, value in message:gmatch("([%w_]+)%(([^)]*)%)") do
        -- First match is the command itself
        if label == cmd.command then
            cmd.params.value = value
        else
            cmd.params[label] = value
        end
    end
    
    return cmd
end

-- Build PGEC command
function protocol.build(command, params)
    local parts = {command}
    
    if params.value then
        table.insert(parts, "(" .. params.value .. ")")
    end
    
    for label, value in pairs(params) do
        if label ~= "value" then
            table.insert(parts, label .. "(" .. value .. ")")
        end
    end
    
    return table.concat(parts, "")
end

return protocol
