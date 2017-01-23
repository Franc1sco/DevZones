#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <devzones>
#include <sdkhooks>

// configuration
#define ZONE_PREFIX "noblock"
//End

new bool:noblock[MAXPLAYERS+1] = false;

public Plugin:myinfo =
{
	name = "SM DEV Zones - NoBlock",
	author = "Franc1sco franug",
	description = "",
	version = "2.0",
	url = "http://www.cola-team.es"
};

public OnPluginStart()
{
	HookEvent("player_spawn", EventPlayerSpawn);
}

public EventPlayerSpawn(Handle:event,const String:name[],bool:dontBroadcast) 
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	noblock[client] = false;
}

public Zone_OnClientEntry(client, String:zone[])
{
	if(client < 1 || client > MaxClients || !IsClientInGame(client) ||!IsPlayerAlive(client)) 
		return;
		
	if(StrContains(zone, ZONE_PREFIX, false) == 0)
	{
		noblock[client] = true;
	}
}

public Zone_OnClientLeave(client, String:zone[])
{
	if(client < 1 || client > MaxClients || !IsClientInGame(client) ||!IsPlayerAlive(client)) 
		return;
		
	if(StrContains(zone, ZONE_PREFIX, false) == 0)
	{
		noblock[client] = false;
	}
}

public OnClientPutInServer(client)
{
	SDKHook(client, SDKHook_ShouldCollide, ShouldCollide);
}


public bool:ShouldCollide(entity, collisiongroup, contentsmask, bool:result)
{
	if (contentsmask == 33636363)
	{
		if(noblock[entity])
		{
			result = false;
			return false;
		}
	}
	
	return true;
}