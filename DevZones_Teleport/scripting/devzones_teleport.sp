#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <devzones>


public Plugin:myinfo =
{
	name = "SM DEV Zones - Teleport",
	author = "Franc1sco franug",
	description = "",
	version = "1.0",
	url = "http://www.clanuea.com/"
};

public Zone_OnClientEntry(client, String:zone[])
{
	if(StrContains(zone, "teleport", false) == 0)
	{
		decl String:targetzone[64], Float:Position[3];
		strcopy(targetzone, 64, zone);
		ReplaceString(targetzone, 64, "teleport", "target", false);
		if(Zone_GetZonePosition(targetzone, false, Position))
			TeleportEntity(client, Position, NULL_VECTOR, NULL_VECTOR);
	}
}