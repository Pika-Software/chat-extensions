local chat = _G.chat
if not chat then
    chat = {}; _G.chat = chat
end

local functions = {}

function chat.GetCommand( cmd )
    return functions[ cmd ]
end

local commands = {}

do

    local table_RemoveByValue = table.RemoveByValue
    local ArgAssert = ArgAssert
    local type = type

    function chat.SetCommand( cmd, func )
        ArgAssert( cmd, 1, "string" )

        table_RemoveByValue( commands, cmd )

        if type( func ) == "function" then
            commands[ #commands + 1 ] = cmd
            functions[ cmd ] = func
            return
        end

        functions[ cmd ] = nil
    end

end

local ipairs = ipairs
local xpcall = xpcall
local string = string
local hook = hook

local packageName = gpm.Package:GetIdentifier()

if SERVER then

    util.AddNetworkString( packageName )

    function chat.AddText( ... )
        net.Start( packageName )
            net.WriteTable( {...} )
        net.Broadcast()
    end

    hook.Add( "PlayerSay", packageName, function( ply, text, isTeam )
        for _, cmd in ipairs( commands ) do
            if not string.StartsWith( text, cmd ) then continue end

            local argStr = string.match( text, "^" .. cmd .. "%s*(.*)$" )
            local args = string.Explode( "%s", argStr, true )

            local result = hook.Run( "ChatCommand", ply, cmd, args, argStr, isTeam )
            if result == false then return "" end

            local func = functions[ cmd ]
            if not func then return "" end

            local ok, result = xpcall( func, ErrorNoHaltWithStack, ply, cmd, args, argStr, isTeam )
            if not ok or not result then return "" end

            return ""
        end
    end )

end

if CLIENT then

    do

        local net_ReadTable = net.ReadTable
        local unpack = unpack

        net.Receive( packageName, function()
            local tbl = net_ReadTable()
            if not tbl then return end
            chat.AddText( unpack( tbl ) )
        end )

    end

    hook.Add( "OnPlayerChat", packageName, function( ply, text, isTeam, isDead )
        for _, cmd in ipairs( commands ) do
            if not string.StartsWith( text, cmd ) then continue end

            local argStr = string.match( text, "^" .. cmd .. "%s*(.*)$" )
            local args = string.Explode( "%s", argStr, true )

            local result = hook.Run( "ChatCommand", ply, cmd, args, argStr, isTeam )
            if result == false then return true end

            local func = functions[ cmd ]
            if not func then return true end

            local ok, result = xpcall( func, ErrorNoHaltWithStack, ply, cmd, args, argStr, isTeam )
            if not ok or not result then return true end

            return true
        end
    end )

end
