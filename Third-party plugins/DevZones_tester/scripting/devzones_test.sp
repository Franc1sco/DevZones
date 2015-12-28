#pragma semicolon 1
#include <sourcemod>
#include <devzones>


public Zone_OnClientEntry(client, String:zone[])
{
	PrintToChatAll("The player %N has entered in zone %s", client, zone);
}

public Zone_OnClientLeave(client, String:zone[])
{
	PrintToChatAll("The player %N has left the zone %s", client, zone);
}