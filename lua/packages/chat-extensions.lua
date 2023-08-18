local networkString = gpm.Package:GetIdentifier( "Networking" )
local ErrorNoHaltWithStack = ErrorNoHaltWithStack
local table_RemoveByIValue = table.RemoveByIValue
local ArgAssert = ArgAssert
local SERVER = SERVER
local ipairs = ipairs
local unpack = unpack
local xpcall = xpcall
local type = type

local string = string
local hook = hook
local net = net

if SERVER then
    util.AddNetworkString( networkString )
end

module( "chat" )

if type( Functions ) ~= "table" then
    Functions = {}
end

if type( Commands ) ~= "table" then
    Commands = {}
end

function GetCommand( command )
    return Functions[ command ]
end

function SetCommand( command, func )
    ArgAssert( command, 1, "string" )

    table_RemoveByIValue( Commands, command )
    Functions[ command ] = nil

    if type( func ) ~= "function" then return end
    Commands[ #Commands + 1 ] = command
    Functions[ command ] = func
end

if SERVER then
    function AddText( ... )
        net.Start( networkString )
            net.WriteTable( { ... } )
        net.Broadcast()
    end

    hook.Add( "PlayerSay", "Chat Commands", function( ply, text, isTeam )
        for _, command in ipairs( Commands ) do
            if not string.StartsWith( text, command ) then continue end

            local argStr = string.match( text, "^" .. command .. "%s*(.*)$" )
            local args = string.Explode( "%s", argStr, true )

            local result = hook.Run( "ChatCommand", ply, command, args, argStr, isTeam )
            if result == false then return "" end

            local func = Functions[ command ]
            if not func then return "" end

            local ok, result = xpcall( func, ErrorNoHaltWithStack, ply, command, args, argStr, isTeam )
            if not ok or not result then return "" end

            return result
        end
    end )

    return
end

net.Receive( networkString, function()
    AddText( unpack( net.ReadTable() ) )
end )

hook.Add( "OnPlayerChat", "Chat Commands", function( ply, text, isTeam, isDead )
    for _, command in ipairs( Commands ) do
        if not string.StartsWith( text, command ) then continue end

        local argStr = string.match( text, "^" .. command .. "%s*(.*)$" )
        local args = string.Explode( "%s", argStr, true )

        local result = hook.Run( "ChatCommand", ply, command, args, argStr, isTeam )
        if result == false then return true end

        local func = Functions[ command ]
        if not func then return true end

        local ok, result = xpcall( func, ErrorNoHaltWithStack, ply, command, args, argStr, isTeam )
        if not ok or not result then return true end

        return result
    end
end )
