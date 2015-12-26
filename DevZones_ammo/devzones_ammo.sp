#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <devzones>

new bool:infiniteammo[MAXPLAYERS+1];

new activeOffset = -1;
new clip1Offset = -1;
new clip2Offset = -1;
new secAmmoTypeOffset = -1;
new priAmmoTypeOffset = -1;

public Plugin:myinfo =
{
	name = "SM DEV Zones - Infinite Ammo",
	author = "Franc1sco franug",
	description = "",
	version = "1.0",
	url = "http://steamcommunity.com/id/franug"
};

public OnPluginStart()
{
	HookEvent("player_spawn", PlayerSpawn);
	HookEvent("weapon_fire", EventWeaponFire);
	
	activeOffset = FindSendPropOffs("CAI_BaseNPC", "m_hActiveWeapon");
	
	clip1Offset = FindSendPropOffs("CBaseCombatWeapon", "m_iClip1");
	clip2Offset = FindSendPropOffs("CBaseCombatWeapon", "m_iClip2");
	
	priAmmoTypeOffset = FindSendPropOffs("CBaseCombatWeapon", "m_iPrimaryAmmoCount");
	secAmmoTypeOffset = FindSendPropOffs("CBaseCombatWeapon", "m_iSecondaryAmmoCount");
}

public Action:PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	infiniteammo[client] = false;
	CreateTimer(4.0, Pasado, GetClientUserId(client));
}

public Action:Pasado(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if(client != 0 && IsClientInGame(client)) infiniteammo[client] = false;
}

public Zone_OnClientEntry(client, String:zone[])
{
	if(StrContains(zone, "ammo", false) != 0) return;
	PrintHintText(client, "UNLIMITED AMMO ZONE");
	infiniteammo[client] = true;
}

public Zone_OnClientLeave(client, String:zone[])
{
	if(StrContains(zone, "ammo", false) != 0) return;
	
	infiniteammo[client] = false;
}

public Action:EventWeaponFire(Handle:event, const String:name[], bool:dontBroadcast)
{
    // Get all required event info.
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(infiniteammo[client]) Client_ResetAmmo(client);
}

public Client_ResetAmmo(client)
{
	new zomg = GetEntDataEnt2(client, activeOffset);
	if (clip1Offset != -1 && zomg != -1)
		SetEntData(zomg, clip1Offset, GetEntData(zomg, clip1Offset, 4)+1, 4, true);
	if (clip2Offset != -1 && zomg != -1)
		SetEntData(zomg, clip2Offset, GetEntData(zomg, clip2Offset, 4)+1, 4, true);
	if (priAmmoTypeOffset != -1 && zomg != -1)
		SetEntData(zomg, priAmmoTypeOffset, GetEntData(zomg, priAmmoTypeOffset, 4)+1, 4, true);
	if (secAmmoTypeOffset != -1 && zomg != -1)
		SetEntData(zomg, secAmmoTypeOffset, GetEntData(zomg, secAmmoTypeOffset, 4)+1, 4, true);
		
}



