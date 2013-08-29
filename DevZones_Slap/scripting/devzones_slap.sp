#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <devzones>

//Configure this
#define CHECKER_VALUE 0.1 // checks per second, low value = more precise but more CPU consume, More hight = less precise but less CPU consume

#define TEAM 0 // Apply to what team? - 0 = any, 2 = T , 3 = CT

// end


public Plugin:myinfo =
{
	name = "SM DEV Zones - Slap",
	author = "Franc1sco franug",
	description = "",
	version = "1.1",
	url = "http://www.clanuea.com/"
};

public OnMapStart()
{
	CreateTimer(CHECKER_VALUE, Comprobador, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public Action:Comprobador(Handle:timer)
{
	for (new p = 1; p <= MaxClients; p++)
		if(IsClientInGame(p) && IsPlayerAlive(p) && (!TEAM || TEAM == GetClientTeam(p)))
			if(Zone_IsClientInZone(p, "Slap", false, false))
				SlapPlayer(p, 0, false);
}