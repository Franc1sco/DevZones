#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <devzones>
#include <zombiereloaded>
#include <multicolors>

new bool:hide[MAXPLAYERS+1];
new equipo[MAXPLAYERS+1];

public Plugin:myinfo =
{
	name = "SM DEV Zones - Hide",
	author = "Franc1sco franug",
	description = "",
	version = "1.0",
	url = "http://www.zeuszombie.com/"
};

public OnPluginStart()
{
	HookEvent("player_spawn", PlayerSpawn);
	HookEvent("player_team", Event_PlayerTeam);
}

public OnClientDisconnect(client)
{
	hide[client] = false;
}

public Event_PlayerTeam(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	equipo[client] = GetEventInt(event, "team");
}

public Action:PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if(hide[client]) NoHide(client);
	CreateTimer(4.0, Pasado, client);
}

public Action:Pasado(Handle:timer, any:client)
{
	if(IsClientInGame(client)) 
		if(hide[client]) NoHide(client);
}

public Zone_OnClientEntry(client, String:zone[])
{
	if(StrContains(zone, "hide", false) != 0) return;
	
	PrintHintText(client, "You entered in a hide teammates zone to improve the vision");
	CPrintToChat(client," {darkred}[HIDE TEAMMATES]{lime}You entered in a hide teammates zone to improve the vision");
	
	if(!hide[client]) YesHide(client);
	
}

public Zone_OnClientLeave(client, String:zone[])
{
	if(StrContains(zone, "hide", false) != 0) return;
	
	PrintHintText(client, "You left the hide teammates zone");
	CPrintToChat(client," {darkred}[HIDE TEAMMATES]{lime}You left the hide teammates zone");
	
	if(hide[client]) NoHide(client);

}

public Action:Hook_SetTransmit(entity, client) 
{ 
    if (entity != client && equipo[client] == equipo[entity]) 
        return Plugin_Handled;
     
    return Plugin_Continue; 
}  


NoHide(client)
{
	SDKUnhook(client, SDKHook_SetTransmit, Hook_SetTransmit); 
	
	hide[client] = false;
}

YesHide(client)
{
	SDKHook(client, SDKHook_SetTransmit, Hook_SetTransmit); 
	
	hide[client] = true;
}


