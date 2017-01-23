#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <devzones>

new Handle:g_hClientTimers[MAXPLAYERS + 1] = {INVALID_HANDLE, ...};
new Handle:cvar_time;

public Plugin:myinfo =
{
	name = "SM DEV Zones - AntiCamp",
	author = "Franc1sco franug",
	description = "",
	version = "2.0",
	url = "http://www.clanuea.com/"
};

public OnPluginStart()
{
	cvar_time = CreateConVar("sm_devzones_anticamptime", "10", "Time in seconds before players must leave the zone or die");
}

public OnClientPutInServer(client)
{
	if (g_hClientTimers[client] != INVALID_HANDLE)
		KillTimer(g_hClientTimers[client]);
	g_hClientTimers[client] = INVALID_HANDLE;
}

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
		
	if((StrContains(zone, "AntiCampCT", false) == 0 && GetClientTeam(client) == 3) || (StrContains(zone, "AntiCampTT", false) == 0 && GetClientTeam(client) == 2))
	{
		new seconds = GetConVarInt(cvar_time);
		g_hClientTimers[client] = CreateTimer(seconds * 1.0, Timer_End, client);
		PrintHintText(client, "You has entered in a AntiCamp Zone for your team\nYou have %i seconds for leave this zone or you will die", seconds);
	}
}

public Zone_OnClientLeave(client, String:zone[])
{
	if(client < 1 || client > MaxClients || !IsClientInGame(client) ||!IsPlayerAlive(client)) 
		return;
		
	if((StrContains(zone, "AntiCampCT", false) == 0 && GetClientTeam(client) == 3) || (StrContains(zone, "AntiCampTT", false) == 0 && GetClientTeam(client) == 2))
	{
		if (g_hClientTimers[client] != INVALID_HANDLE)
			KillTimer(g_hClientTimers[client]);
		g_hClientTimers[client] = INVALID_HANDLE;
	}
}

public Action:Timer_End(Handle:timer, any:client)
{
	if(IsPlayerAlive(client))
	{
		ForcePlayerSuicide(client);
		PrintToChatAll("%N have beeen killed for camp in a anticamp zone",client);
	}
	g_hClientTimers[client] = INVALID_HANDLE;
}