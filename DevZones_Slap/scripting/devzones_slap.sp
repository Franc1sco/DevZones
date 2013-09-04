#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <devzones>

#define ZONE_PREFIX_CT "SlapCT"
#define ZONE_PREFIX_TT "SlapTT"
#define ZONE_PREFIX_ANY "SlapANY"
#define REPEAT_VALUE 0.1



public Plugin:myinfo =
{
	name = "SM DEV Zones - Slap",
	author = "Franc1sco franug",
	description = "",
	version = "2.0",
	url = "http://www.clanuea.com/"
};

new Handle:g_hClientTimers[MAXPLAYERS + 1] = {INVALID_HANDLE, ...};

public OnClientDisconnect(client)
{
	if (g_hClientTimers[client] != INVALID_HANDLE)
		KillTimer(g_hClientTimers[client]);
	g_hClientTimers[client] = INVALID_HANDLE;
}

public Zone_OnClientEntry(client, String:zone[])
{
	if((StrContains(zone, ZONE_PREFIX_CT, false) == 0 && GetClientTeam(client) == 3) || (StrContains(zone, ZONE_PREFIX_TT, false) == 0 && GetClientTeam(client) == 2) || StrContains(zone, ZONE_PREFIX_ANY, false) == 0)
	{
		g_hClientTimers[client] = CreateTimer(REPEAT_VALUE, Timer_Repeat, client, TIMER_REPEAT);
	}
}

public Zone_OnClientLeave(client, String:zone[])
{
	if((StrContains(zone, ZONE_PREFIX_CT, false) == 0 && GetClientTeam(client) == 3) || (StrContains(zone, ZONE_PREFIX_TT, false) == 0 && GetClientTeam(client) == 2) || StrContains(zone, ZONE_PREFIX_ANY, false) == 0)
	{
		if (g_hClientTimers[client] != INVALID_HANDLE)
			KillTimer(g_hClientTimers[client]);
		g_hClientTimers[client] = INVALID_HANDLE;
	}
}

public Action:Timer_Repeat(Handle:timer, any:client)
{
	if(!IsPlayerAlive(client))
	{
		if (g_hClientTimers[client] != INVALID_HANDLE)
			KillTimer(g_hClientTimers[client]);
		g_hClientTimers[client] = INVALID_HANDLE;
		return Plugin_Stop;
	}
	SlapPlayer(client, 0, false);
	return Plugin_Continue;
}
