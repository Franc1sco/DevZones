#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <devzones>

#define	HIDEHUD_ALL					1<<2

public Plugin:myinfo =
{
	name = "SM DEV Zones - No HUD",
	author = "Franc1sco franug",
	description = "",
	version = "1.0",
	url = "http://steamcommunity.com/id/franug"
};


public Zone_OnClientEntry(client, String:zone[])
{
	if(StrContains(zone, "nohud", false) != 0) return;
	
	SetEntProp(client, Prop_Send, "m_iHideHUD", GetEntProp(client, Prop_Send, "m_iHideHUD") | HIDEHUD_ALL);
}

public Zone_OnClientLeave(client, String:zone[])
{
	if(StrContains(zone, "nohud", false) != 0) return;
	
	SetEntProp(client, Prop_Send, "m_iHideHUD", GetEntProp(client, Prop_Send, "m_iHideHUD") & ~HIDEHUD_ALL);
}