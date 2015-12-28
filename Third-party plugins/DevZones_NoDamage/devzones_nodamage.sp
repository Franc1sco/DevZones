#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <devzones>

new bool:nodamage[MAXPLAYERS+1];

public Plugin:myinfo =
{
	name = "SM DEV Zones - NoDamage",
	author = "Franc1sco franug",
	description = "",
	version = "1.1",
	url = "http://www.cola-team.es"
};

public OnPluginStart()
{
	HookEvent("player_spawn", PlayerSpawn);
}

public Action:PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	nodamage[client] = false;
	CreateTimer(4.0, SpawnTimer, client);
}

public Action:SpawnTimer(Handle:timer, any:client)
{
	
	if (!IsClientInGame(client))
		return;
		
	nodamage[client] = false;
	
}

public Zone_OnClientEntry(client, String:zone[])
{
	if(StrContains(zone, "nodamage", false) != 0) return;
	
	nodamage[client] = true;
}

public Zone_OnClientLeave(client, String:zone[])
{
	if(StrContains(zone, "nodamage", false) != 0) return;
	
	nodamage[client] = false;
}

public OnClientPutInServer(client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action:OnTakeDamage(client, &attacker, &inflictor, &Float:damage, &damagetype)
{
	if(!IsValidClient(attacker) || !IsValidClient(client)) return Plugin_Continue;
	
	if(nodamage[attacker] || nodamage[client])
	{
		PrintHintText(attacker, "You cant hurt players in this zone!");
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public IsValidClient( client ) 
{ 
    if ( !( 1 <= client <= MaxClients ) || !IsClientInGame(client) ) 
        return false; 
     
    return true; 
}