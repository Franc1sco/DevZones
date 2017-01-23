#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <devzones>

// configuration
#define ZONE_PREFIX "noentry"
//End


new Float:zone_pos[MAXPLAYERS+1][3];
new Handle:g_hClientTimers[MAXPLAYERS + 1] = {INVALID_HANDLE, ...};

public Plugin:myinfo =
{
	name = "SM DEV Zones - NoEntry",
	author = "Franc1sco franug",
	description = "",
	version = "2.0",
	url = "http://steamcommunity.com/id/franug"
};

public OnClientDisconnect(client)
{
	if (g_hClientTimers[client] != INVALID_HANDLE)
		KillTimer(g_hClientTimers[client]);
	g_hClientTimers[client] = INVALID_HANDLE;
}

public Zone_OnClientEntry(client, String:zone[])
{
	if(client < 1 || client > MaxClients || !IsClientInGame(client) ||!IsPlayerAlive(client)) 
		return;
		
	if(StrContains(zone, ZONE_PREFIX, false) == 0)
	{
		Zone_GetZonePosition(zone, false, zone_pos[client]);
		g_hClientTimers[client] = CreateTimer(0.1, Timer_Repeat, client, TIMER_REPEAT);
		PrintHintText(client, "You can't enter here!");
	}
}

public Zone_OnClientLeave(client, String:zone[])
{
	if(client < 1 || client > MaxClients || !IsClientInGame(client) ||!IsPlayerAlive(client)) 
		return;
		
	if(StrContains(zone, ZONE_PREFIX, false) == 0)
	{
		if (g_hClientTimers[client] != INVALID_HANDLE)
			KillTimer(g_hClientTimers[client]);
		g_hClientTimers[client] = INVALID_HANDLE;
	}
}

public Action:Timer_Repeat(Handle:timer, any:client)
{
	if(!IsClientInGame(client) || !IsPlayerAlive(client))
	{
		if (g_hClientTimers[client] != INVALID_HANDLE)
			KillTimer(g_hClientTimers[client]);
		g_hClientTimers[client] = INVALID_HANDLE;
		return Plugin_Stop;
	}
	new Float:clientloc[3];
	GetClientAbsOrigin(client, clientloc);
	
	KnockbackSetVelocity(client, zone_pos[client], clientloc, 300.0);
	return Plugin_Continue;
}

KnockbackSetVelocity(client, const Float:startpoint[3], const Float:endpoint[3], Float:magnitude)
{
    // Create vector from the given starting and ending points.
    new Float:vector[3];
    MakeVectorFromPoints(startpoint, endpoint, vector);
    
    // Normalize the vector (equal magnitude at varying distances).
    NormalizeVector(vector, vector);
    
    // Apply the magnitude by scaling the vector (multiplying each of its components).
    ScaleVector(vector, magnitude);
    

    TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vector);
}
