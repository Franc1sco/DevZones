/*  SM DEV Zones
 *
 *  Copyright (C) 2017-2020 Francisco 'Franc1sco' García and Totenfluch
 * 
 * This program is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option) 
 * any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT 
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS 
 * FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with 
 * this program. If not, see http://www.gnu.org/licenses/.
 */

#pragma semicolon 1
#include <sourcemod>
#include <sdktools>


#define VERSION "3.3.2"
#pragma newdecls required

#define MAX_ZONES 256

int beamColorT[4] =  { 255, 0, 0, 255 };
int beamColorCT[4] =  { 0, 0, 255, 255 };
int beamColorN[4] =  { 255, 255, 0, 255 };
int beamColorM[4] =  { 0, 255, 0, 255 };

int g_CurrentZoneTeam[MAXPLAYERS + 1];
int g_CurrentZoneVis[MAXPLAYERS + 1];
char g_CurrentZoneName[MAXPLAYERS + 1][64];
// VARIABLES
Handle g_Zones = INVALID_HANDLE;
int g_Editing[MAXPLAYERS + 1] =  { 0, ... };
float g_Positions[MAXPLAYERS + 1][2][3];
int g_ClientSelectedZone[MAXPLAYERS + 1] =  { -1, ... };
bool g_bFixName[MAXPLAYERS + 1];

int g_BeamSprite;
int g_HaloSprite;

Handle hOnClientEntry = INVALID_HANDLE;
Handle hOnClientLeave = INVALID_HANDLE;


enum g_eList {
	String:liName[64], 
	bool:liThis
};

int g_iZones[2048][MAX_ZONES][g_eList]; // max zones = 256


// cvars

Handle cvar_filter;
Handle cvar_mode;
Handle cvar_checker;
Handle cvar_model;

bool g_bfilter;
float checker;
bool mode_plugin;
char sModel[192];

Handle cvar_timer = INVALID_HANDLE;

Handle hOnZoneCreated;

// PLUGIN INFO
public Plugin myinfo =
{
	name = "SM DEV Zones",
	author = "Franc1sco, root, Totenfluch",
	description = "Adds Custom Zones",
	version = VERSION,
	url = "https://github.com/Franc1sco/DevZones"
};

public void OnPluginStart() {
	cvar_filter = CreateConVar("sm_devzones_filter", "1", "1 = Only allow valid alive clients to be detected in the native zones. 0 = Detect entities and all (you need to add more checkers in the third party plugins).");
	cvar_mode = CreateConVar("sm_devzones_mode", "1", "0 = Use checks every X seconds for check if a player join or leave a zone, 1 = hook zone entities with OnStartTouch and OnEndTouch (less CPU consume)");
	cvar_checker = CreateConVar("sm_devzones_checker", "5.0", "checks and beambox refreshs per second, low value = more precise but more CPU consume, More hight = less precise but less CPU consume");
	cvar_model = CreateConVar("sm_devzones_model", "models/error.mdl", "Use a model for zone entity (IMPORTANT: change this value only on map start)");
	g_Zones = CreateArray(256);
	RegAdminCmd("sm_zones", Command_CampZones, ADMFLAG_CUSTOM6);
	RegConsoleCmd("say", fnHookSay);
	HookEventEx("round_start", Event_OnRoundStart);
	HookEventEx("player_spawn", Event_PlayerSpawn, EventHookMode_Pre);
	HookEventEx("teamplay_round_start", Event_OnRoundStart);
	//HookEvent("round_start", OnRoundStart);
	
	GetCVars();
	
	HookConVarChange(cvar_filter, CVarChange);
	HookConVarChange(cvar_checker, CVarChange);
	HookConVarChange(cvar_mode, CVarChange);
	HookConVarChange(cvar_model, CVarChange);
	
}

// fixes for Zone_IsClientInZone native
public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	resetClient(client);
}

public void OnEntityDestroyed(int entity)
{
	if (entity < 0 || entity > 2048)return;
	
	resetClient(entity);
}
//

public void OnPluginEnd()
{
	RemoveZones();
}

public void resetClient(int client) {
	for (int i = 0; i < MAX_ZONES; i++)
	g_iZones[client][i][liThis] = false;
}

public void CVarChange(Handle convar_hndl, const char[] oldValue, const char[] newValue) {
	GetCVars();
}

// Get int values of cvars if they has being changed
public void GetCVars() {
	g_bfilter = GetConVarBool(cvar_filter);
	mode_plugin = GetConVarBool(cvar_mode);
	checker = GetConVarFloat(cvar_checker);
	GetConVarString(cvar_model, sModel, 192);
	
	if (cvar_timer != INVALID_HANDLE) {
		KillTimer(cvar_timer);
		cvar_timer = INVALID_HANDLE;
	}
	cvar_timer = CreateTimer(checker, BeamBoxAll, _, TIMER_REPEAT);
}

public void OnClientPostAdminCheck(int client) {
	g_ClientSelectedZone[client] = -1;
	g_Editing[client] = 0;
	g_bFixName[client] = false;
	resetClient(client);
}

public Action Event_OnRoundStart(Handle event, const char[] name, bool dontBroadcast) {
	if (mode_plugin)
		RefreshZones();
}

public int CreateZoneEntity(float fMins[3], float fMaxs[3], char sZoneName[64]) {
	float fMiddle[3];
	int iEnt = CreateEntityByName("trigger_multiple");
	
	Call_StartForward(hOnZoneCreated);
	Call_PushString(sZoneName);
	Call_Finish();
	
	DispatchKeyValue(iEnt, "spawnflags", "64");
	Format(sZoneName, sizeof(sZoneName), "sm_devzone %s", sZoneName);
	DispatchKeyValue(iEnt, "targetname", sZoneName);
	DispatchKeyValue(iEnt, "wait", "0");
	
	DispatchSpawn(iEnt);
	ActivateEntity(iEnt);
	
	GetMiddleOfABox(fMins, fMaxs, fMiddle);
	
	TeleportEntity(iEnt, fMiddle, NULL_VECTOR, NULL_VECTOR);
	SetEntityModel(iEnt, sModel);
	
	
	// Have the mins always be negative
	fMins[0] = fMins[0] - fMiddle[0];
	if (fMins[0] > 0.0)
		fMins[0] *= -1.0;
	fMins[1] = fMins[1] - fMiddle[1];
	if (fMins[1] > 0.0)
		fMins[1] *= -1.0;
	fMins[2] = fMins[2] - fMiddle[2];
	if (fMins[2] > 0.0)
		fMins[2] *= -1.0;
	
	// And the maxs always be positive
	fMaxs[0] = fMaxs[0] - fMiddle[0];
	if (fMaxs[0] < 0.0)
		fMaxs[0] *= -1.0;
	fMaxs[1] = fMaxs[1] - fMiddle[1];
	if (fMaxs[1] < 0.0)
		fMaxs[1] *= -1.0;
	fMaxs[2] = fMaxs[2] - fMiddle[2];
	if (fMaxs[2] < 0.0)
		fMaxs[2] *= -1.0;
	
	SetEntPropVector(iEnt, Prop_Send, "m_vecMins", fMins);
	SetEntPropVector(iEnt, Prop_Send, "m_vecMaxs", fMaxs);
	SetEntProp(iEnt, Prop_Send, "m_nSolidType", 2);
	
	int iEffects = GetEntProp(iEnt, Prop_Send, "m_fEffects");
	iEffects |= 32;
	SetEntProp(iEnt, Prop_Send, "m_fEffects", iEffects);
	
	HookSingleEntityOutput(iEnt, "OnStartTouch", EntOut_OnStartTouch);
	HookSingleEntityOutput(iEnt, "OnEndTouch", EntOut_OnEndTouch);
	
	return iEnt;
}

public void EntOut_OnStartTouch(const char[] output, int caller, int activator, float delay) {
	// Ignore dead players
	if (g_bfilter)
		if (activator < 1 || activator > MaxClients || !IsClientInGame(activator) || !IsPlayerAlive(activator))
		return;
	
	char sTargetName[256];
	GetEntPropString(caller, Prop_Data, "m_iName", sTargetName, sizeof(sTargetName));
	ReplaceString(sTargetName, sizeof(sTargetName), "sm_devzone ", "");
	
	
	// entra
	char nBuf[64];
	Entity_GetGlobalName(caller, nBuf, sizeof(nBuf));
	int callerId = StringToInt(nBuf);
	g_iZones[activator][callerId][liThis] = true;
	Format(g_iZones[activator][callerId][liName], 64, sTargetName);
	//PrintToChatAll("E::%i::%s::", callerId, sTargetName);
	Call_StartForward(hOnClientEntry);
	Call_PushCell(activator);
	Call_PushString(sTargetName);
	Call_Finish();
}

public void EntOut_OnEndTouch(const char[] output, int caller, int activator, float delay) {
	// Ignore dead players
	if (g_bfilter)
		if (activator < 1 || activator > MaxClients || !IsClientInGame(activator) || !IsPlayerAlive(activator))
		return;
	
	char sTargetName[256];
	GetEntPropString(caller, Prop_Data, "m_iName", sTargetName, sizeof(sTargetName));
	ReplaceString(sTargetName, sizeof(sTargetName), "sm_devzone ", "");
	
	
	// sale
	char nBuf[64];
	Entity_GetGlobalName(caller, nBuf, sizeof(nBuf));
	int callerId = StringToInt(nBuf);
	g_iZones[activator][callerId][liThis] = false;
	Format(g_iZones[activator][callerId][liName], 64, "");
	//PrintToChatAll("EX::%i::%s::", callerId, sTargetName);
	Call_StartForward(hOnClientLeave);
	Call_PushCell(activator);
	Call_PushString(sTargetName);
	Call_Finish();
	
}

public void OnMapStart() {

	for (int i = 1; i < MAXPLAYERS; i++)
		resetClient(i);
	
	
	g_BeamSprite = PrecacheModel("sprites/laserbeam.vmt");
	g_HaloSprite = PrecacheModel("materials/sprites/halo.vmt");
	PrecacheModel(sModel);
	
	ReadZones();
	RefreshZones();
}

public void OnMapEnd() {
	SaveZones(0);
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon) {
	BeamBox_OnPlayerRunCmd(client);
}

public Action Command_CampZones(int client, int args) {
	ZoneMenu(client);
}

public void getZoneTeamColor(int team, int color[4]) {
	switch (team)
	{
		case 1:
		{
			color = beamColorM;
		}
		case 2:
		{
			color = beamColorT;
		}
		case 3:
		{
			color = beamColorCT;
		}
		default:
		{
			color = beamColorN;
		}
	}
}

public void ReadZones() {
	
	int size = GetArraySize(g_Zones);
	if(size > 0)
	{
		for (int i = 0; i < size; ++i)
		{
			CloseHandle(GetArrayCell(g_Zones, i));
		}
	}
	ClearArray(g_Zones);
	char Path[512];
	BuildPath(Path_SM, Path, sizeof(Path), "configs/dev_zones");
	if (!DirExists(Path))
		CreateDirectory(Path, 0777);
	
	char map[64];
	GetCurrentMap(map, sizeof(map));
	if (StrContains(map, "workshop") != -1) {
		char mapPart[3][64];
		ExplodeString(map, "/", mapPart, 3, 64);
		strcopy(map, sizeof(map), mapPart[2]);
	}
	StringToLowerCase(map);
	BuildPath(Path_SM, Path, sizeof(Path), "configs/dev_zones/%s.zones.txt", map);
	if (!FileExists(Path))
	{
		//Handle file = OpenFile(Path, "w");
		//CloseHandle(file);
		Handle kv = CreateKeyValues("Zones");
		KeyValuesToFile(kv, Path);
	}
	
	
	Handle kv = CreateKeyValues("Zones");
	FileToKeyValues(kv, Path);
	if (!KvGotoFirstSubKey(kv))
	{
		PrintToServer("[ERROR] Config file is corrupted: %s", Path);
		return;
	}
	float pos1[3];
	float pos2[3];
	char nombre[64];
	do
	{
		KvGetVector(kv, "cordinate_a", pos1);
		KvGetVector(kv, "cordinate_b", pos2);
		KvGetString(kv, "name", nombre, 64);
		Handle trie = CreateTrie();
		SetTrieArray(trie, "corda", pos1, 3);
		SetTrieArray(trie, "cordb", pos2, 3);
		SetTrieValue(trie, "team", KvGetNum(kv, "team", 0));
		SetTrieValue(trie, "vis", KvGetNum(kv, "vis", 0));
		SetTrieString(trie, "name", nombre);
		PushArrayCell(g_Zones, trie);
		//CloseHandle(trie);
	} while (KvGotoNextKey(kv));
	CloseHandle(kv);
}

public void SaveZones(int client) {
	char Path[512];
	char map[64];
	GetCurrentMap(map, sizeof(map));
	if (StrContains(map, "workshop") != -1) {
		char mapPart[3][64];
		ExplodeString(map, "/", mapPart, 3, 64);
		strcopy(map, sizeof(map), mapPart[2]);
	}
	StringToLowerCase(map);
	BuildPath(Path_SM, Path, sizeof(Path), "configs/dev_zones/%s.zones.txt", map);
	Handle file = OpenFile(Path, "w+");
	CloseHandle(file);
	float pos1[3];
	float pos2[3];
	char SectName[64];
	int Team;
	int Vis;
	char nombre[64];
	
	int size = GetArraySize(g_Zones);
	Handle kv = CreateKeyValues("Zones");
	for (int i = 0; i < size; ++i)
	{
		IntToString(i, SectName, sizeof(SectName));
		
		Handle trie = GetArrayCell(g_Zones, i);
		GetTrieArray(trie, "corda", pos1, sizeof(pos1));
		GetTrieArray(trie, "cordb", pos2, sizeof(pos2));
		GetTrieValue(trie, "team", Team);
		GetTrieValue(trie, "vis", Vis);
		GetTrieString(trie, "name", nombre, 64);
		//Format(Nombre, 64, "Zone %i", i);
		//SetTrieString(trie, "name", Nombre, true);
		
		KvJumpToKey(kv, SectName, true);
		KvSetString(kv, "name", nombre);
		KvSetVector(kv, "cordinate_a", pos1);
		KvSetVector(kv, "cordinate_b", pos2);
		KvSetNum(kv, "vis", Vis);
		KvSetNum(kv, "team", Team);
		KvGoBack(kv);
	}
	KeyValuesToFile(kv, Path);
	CloseHandle(kv);
	if (client != 0)
		PrintToChat(client, "All zones are saved in file.");
}

public bool TraceRayDontHitSelf(int entity, int mask, any data) {
	if (entity == data)
		return false;
	return true;
}

public Action fnHookSay(int client, int args) {
	if (!g_bFixName[client])return;
	
	char sArgs[192];
	GetCmdArgString(sArgs, sizeof(sArgs));
	
	StripQuotes(sArgs);
	
	ReplaceString(sArgs, 192, "'", ".");
	ReplaceString(sArgs, 192, "<", ".");
	//ReplaceString(sArgs, 192, "\"", ".");
	if (strlen(sArgs) > 45)
	{
		PrintToChat(client, "the name is too long, try other name");
		return;
	}
	if (StrEqual(sArgs, "!cancel"))
	{
		PrintToChat(client, "Set name action canceled");
		EditorMenu(client);
		return;
	}
	char ZoneId[64];
	int size = GetArraySize(g_Zones);
	for (int i = 0; i < size; ++i)
	{
		Handle trie = GetArrayCell(g_Zones, i);
		GetTrieString(trie, "name", ZoneId, 64);
		if (StrEqual(ZoneId, sArgs))
		{
			PrintToChat(client, "The name already exist, write other name");
			return;
		}
	}
	
	Format(g_CurrentZoneName[client], 64, sArgs);
	PrintToChat(client, "Zone name set to %s", sArgs);
	g_bFixName[client] = false;
	EditorMenu(client);
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	hOnClientEntry = CreateGlobalForward("Zone_OnClientEntry", ET_Ignore, Param_Cell, Param_String);
	hOnClientLeave = CreateGlobalForward("Zone_OnClientLeave", ET_Ignore, Param_Cell, Param_String);
	hOnZoneCreated = CreateGlobalForward("Zone_OnCreated", ET_Ignore, Param_String);
	CreateNative("Zone_IsClientInZone", Native_InZone);
	CreateNative("Zone_GetZonePosition", Native_Teleport);
	CreateNative("Zone_CheckIfZoneExists", Native_ZoneExist);
	CreateNative("Zone_isPositionInZone", Native_isPositionInZone);
	/*
		@Param1 -> int client
		@Param2 -> char[64] zoneBuffer
	
		@return true if zone found false if not
	*/
	CreateNative("Zone_getMostRecentActiveZone", Native_getMostRecentActiveZone);
	
	return APLRes_Success;
}

public int Native_InZone(Handle plugin, int argc) {
	char name[64];
	GetNativeString(2, name, 64);
	int client = GetNativeCell(1);
	bool same = GetNativeCell(3);
	bool sensitive = GetNativeCell(4);
	
	int size = GetArraySize(g_Zones);
	for (int i = 0; i < size; ++i)
	{
		if (same)
		{
			if (StrEqual(g_iZones[client][i][liName], name, sensitive) && g_iZones[client][i][liThis])
				return true;
		}
		else
		{
			if (StrContains(g_iZones[client][i][liName], name, sensitive) == 0 && g_iZones[client][i][liThis])
				return true;
		}
		
	}
	return false;
}

public int Native_getMostRecentActiveZone(Handle plugin, int argc) {
	int client = GetNativeCell(1);
	
	int size = GetArraySize(g_Zones);
	for (int i = 0; i < size; ++i) {
		if (g_iZones[client][i][liThis]) {
			SetNativeString(2, g_iZones[client][i][liName], 64);
			return true;
		}
	}
	return false;
}

public int Native_Teleport(Handle plugin, int argc) {
	char name[64];
	char namezone[64];
	float posA[3];
	float posB[3];
	
	GetNativeString(1, name, 64);
	bool sensitive = GetNativeCell(2);
	
	int size = GetArraySize(g_Zones);
	if (size > 0)
	{
		for (int i = 0; i < size; ++i)
		{
			GetTrieString(GetArrayCell(g_Zones, i), "name", namezone, 64);
			if (StrEqual(name, namezone, sensitive))
			{
				GetTrieArray(GetArrayCell(g_Zones, i), "corda", posA, sizeof(posA));
				GetTrieArray(GetArrayCell(g_Zones, i), "cordb", posB, sizeof(posB));
				float ZonePos[3];
				AddVectors(posA, posB, ZonePos);
				ZonePos[0] = FloatDiv(ZonePos[0], 2.0);
				ZonePos[1] = FloatDiv(ZonePos[1], 2.0);
				ZonePos[2] = FloatDiv(ZonePos[2], 2.0);
				SetNativeArray(3, ZonePos, 3);
				return true;
			}
		}
	}
	return false;
}

public int Native_ZoneExist(Handle plugin, int argc) {
	char name[64];
	char namezone[64];
	
	GetNativeString(1, name, 64);
	bool same = GetNativeCell(2);
	bool sensitive = GetNativeCell(3);
	
	int size = GetArraySize(g_Zones);
	if (size > 0)
	{
		for (int i = 0; i < size; ++i)
		{
			GetTrieString(GetArrayCell(g_Zones, i), "name", namezone, 64);
			if (same)if (StrEqual(name, namezone, sensitive))return true;
			else if (StrContains(name, namezone, sensitive) == 0)return true;
		}
	}
	return false;
}

public int Native_isPositionInZone(Handle plugin, int numParams) {
	char zonename[64];
	float pos[3];
	GetNativeString(1, zonename, 64);
	pos[0] = view_as<float>(GetNativeCell(2));
	pos[1] = view_as<float>(GetNativeCell(3));
	pos[2] = view_as<float>(GetNativeCell(4));
	
	int size = GetArraySize(g_Zones);
	if (size > 0) {
		for (int i = 0; i < size; ++i) {
			char name[64];
			GetTrieString(GetArrayCell(g_Zones, i), "name", name, sizeof(name));
			if (StrEqual(name, zonename)) {
				float posA[3];
				float posB[3];
				GetTrieArray(GetArrayCell(g_Zones, i), "corda", posA, sizeof(posA));
				GetTrieArray(GetArrayCell(g_Zones, i), "cordb", posB, sizeof(posB));
				return IsbetweenRect(pos, posA, posB, 0);
			}
		}
	}
	return 0;
}

public void DrawBeamBox(int client) {
	int zColor[4];
	getZoneTeamColor(g_CurrentZoneTeam[client], zColor);
	TE_SendBeamBoxToClient(client, g_Positions[client][1], g_Positions[client][0], g_BeamSprite, g_HaloSprite, 0, 30, 1.0, 5.0, 5.0, 2, 1.0, zColor, 0);
	CreateTimer(1.0, BeamBox, client, TIMER_REPEAT);
}

public Action BeamBox(Handle timer, any client) {
	if (IsClientInGame(client))
	{
		if (g_Editing[client] == 2)
		{
			int zColor[4];
			getZoneTeamColor(g_CurrentZoneTeam[client], zColor);
			TE_SendBeamBoxToClient(client, g_Positions[client][1], g_Positions[client][0], g_BeamSprite, g_HaloSprite, 0, 30, 1.0, 5.0, 5.0, 2, 1.0, zColor, 0);
			return Plugin_Continue;
		}
	}
	return Plugin_Stop;
}

public Action BeamBoxAll(Handle timer, any data) {
	int size = GetArraySize(g_Zones);
	float posA[3];
	float posB[3];
	int zColor[4];
	int Team;
	int Vis;
	char nombre[64];
	for (int i = 0; i < size; ++i)
	{
		Handle trie = GetArrayCell(g_Zones, i);
		GetTrieArray(trie, "corda", posA, sizeof(posA));
		GetTrieArray(trie, "cordb", posB, sizeof(posB));
		GetTrieValue(trie, "team", Team);
		GetTrieValue(trie, "vis", Vis);
		GetTrieString(trie, "name", nombre, 64);
		//CloseHandle(trie);
		for (int p = 1; p <= MaxClients; p++)
		{
			if (IsClientInGame(p))
			{
				if (g_ClientSelectedZone[p] != i && (Vis == 1 || GetClientTeam(p) == Vis)) {
					getZoneTeamColor(Team, zColor);
					TE_SendBeamBoxToClient(p, posA, posB, g_BeamSprite, g_HaloSprite, 0, 30, checker, 5.0, 5.0, 2, 1.0, zColor, 0);
				}
				
				if (mode_plugin)continue;
				
				if (IsPlayerAlive(p))
				{
					if (IsbetweenRect(NULL_VECTOR, posA, posB, p))
					{
						if (!g_iZones[p][i][liThis])
						{
							// entra
							g_iZones[p][i][liThis] = true;
							Format(g_iZones[p][i][liName], 64, nombre);
							Call_StartForward(hOnClientEntry);
							Call_PushCell(p);
							Call_PushString(g_iZones[p][i][liName]);
							Call_Finish();
						}
					}
					else
					{
						if (g_iZones[p][i][liThis])
						{
							// sale
							g_iZones[p][i][liThis] = false;
							Format(g_iZones[p][i][liName], 64, nombre);
							Call_StartForward(hOnClientLeave);
							Call_PushCell(p);
							Call_PushString(g_iZones[p][i][liName]);
							Call_Finish();
						}
					}
				}
			}
		}
	}
	return Plugin_Continue;
}

public void BeamBox_OnPlayerRunCmd(int client) {
	if (g_Editing[client] == 1 || g_Editing[client] == 3)
	{
		float pos[3];
		float ang[3];
		int zColor[4];
		getZoneTeamColor(g_CurrentZoneTeam[client], zColor);
		if (g_Editing[client] == 1)
		{
			GetClientEyePosition(client, pos);
			GetClientEyeAngles(client, ang);
			TR_TraceRayFilter(pos, ang, MASK_PLAYERSOLID, RayType_Infinite, TraceRayDontHitSelf, client);
			TR_GetEndPosition(g_Positions[client][1]);
		}
		TE_SendBeamBoxToClient(client, g_Positions[client][1], g_Positions[client][0], g_BeamSprite, g_HaloSprite, 0, 30, 0.1, 5.0, 5.0, 2, 1.0, zColor, 0);
	}
}

stock void TE_SendBeamBoxToClient(int client, float uppercorner[3], const float bottomcorner[3], int ModelIndex, int HaloIndex, int StartFrame, int FrameRate, float Life, float Width, float EndWidth, int FadeLength, float Amplitude, const int Color[4], int Speed) {
	// Create the additional corners of the box
	float tc1[3];
	AddVectors(tc1, uppercorner, tc1);
	tc1[0] = bottomcorner[0];
	
	float tc2[3];
	AddVectors(tc2, uppercorner, tc2);
	tc2[1] = bottomcorner[1];
	
	float tc3[3];
	AddVectors(tc3, uppercorner, tc3);
	tc3[2] = bottomcorner[2];
	
	float tc4[3];
	AddVectors(tc4, bottomcorner, tc4);
	tc4[0] = uppercorner[0];
	
	float tc5[3];
	AddVectors(tc5, bottomcorner, tc5);
	tc5[1] = uppercorner[1];
	
	float tc6[3];
	AddVectors(tc6, bottomcorner, tc6);
	tc6[2] = uppercorner[2];
	
	// Draw all the edges
	TE_SetupBeamPoints(uppercorner, tc1, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, Color, Speed);
	TE_SendToClient(client);
	TE_SetupBeamPoints(uppercorner, tc2, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, Color, Speed);
	TE_SendToClient(client);
	TE_SetupBeamPoints(uppercorner, tc3, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, Color, Speed);
	TE_SendToClient(client);
	TE_SetupBeamPoints(tc6, tc1, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, Color, Speed);
	TE_SendToClient(client);
	TE_SetupBeamPoints(tc6, tc2, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, Color, Speed);
	TE_SendToClient(client);
	TE_SetupBeamPoints(tc6, bottomcorner, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, Color, Speed);
	TE_SendToClient(client);
	TE_SetupBeamPoints(tc4, bottomcorner, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, Color, Speed);
	TE_SendToClient(client);
	TE_SetupBeamPoints(tc5, bottomcorner, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, Color, Speed);
	TE_SendToClient(client);
	TE_SetupBeamPoints(tc5, tc1, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, Color, Speed);
	TE_SendToClient(client);
	TE_SetupBeamPoints(tc5, tc3, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, Color, Speed);
	TE_SendToClient(client);
	TE_SetupBeamPoints(tc4, tc3, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, Color, Speed);
	TE_SendToClient(client);
	TE_SetupBeamPoints(tc4, tc2, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, Color, Speed);
	TE_SendToClient(client);
	
}

public bool IsbetweenRect(float Pos[3], float Corner1[3], float Corner2[3], int client)
{
	float Entity[3];
	float field1[2];
	float field2[2];
	float field3[2];
	
	if (!client)
	{
		Entity = Pos;
	}
	else
		GetClientAbsOrigin(client, Entity);
	
	Entity[2] = FloatAdd(Entity[2], 25.0);
	
	// Sort Floats... 
	if (FloatCompare(Corner1[0], Corner2[0]) == -1)
	{
		field1[0] = Corner1[0];
		field1[1] = Corner2[0];
	}
	else
	{
		field1[0] = Corner2[0];
		field1[1] = Corner1[0];
	}
	if (FloatCompare(Corner1[1], Corner2[1]) == -1)
	{
		field2[0] = Corner1[1];
		field2[1] = Corner2[1];
	}
	else
	{
		field2[0] = Corner2[1];
		field2[1] = Corner1[1];
	}
	if (FloatCompare(Corner1[2], Corner2[2]) == -1)
	{
		field3[0] = Corner1[2];
		field3[1] = Corner2[2];
	}
	else
	{
		field3[0] = Corner2[2];
		field3[1] = Corner1[2];
	}
	
	// Check the Vectors ... 
	
	if (Entity[0] < field1[0] || Entity[0] > field1[1])
	{
		//PrintToChat(client, "first");
		return false;
	}
	if (Entity[1] < field2[0] || Entity[1] > field2[1])
	{
		//PrintToChat(client, "second");
		return false;
	}
	if (Entity[2] < field3[0] || Entity[2] > field3[1])
	{
		//PrintToChat(client, "third");
		return false;
	}
	
	return true;
}

// menus.sp

public void ZoneMenu(int client)
{
	g_ClientSelectedZone[client] = -1;
	g_Editing[client] = 0;
	Handle Menu2 = CreateMenu(Handle_ZoneMenu);
	SetMenuTitle(Menu2, "Zones");
	AddMenuItem(Menu2, "", "Create Zone");
	AddMenuItem(Menu2, "", "Edit Zones");
	AddMenuItem(Menu2, "", "Save Zones");
	AddMenuItem(Menu2, "", "Reload Zones");
	AddMenuItem(Menu2, "", "Clear Zones");
	SetMenuExitBackButton(Menu2, true);
	DisplayMenu(Menu2, client, MENU_TIME_FOREVER);
}

public int Handle_ZoneMenu(Handle tMenu, MenuAction action, int client, int item) {
	switch (action)
	{
		case MenuAction_Select:
		{
			switch (item)
			{
				case 0:
				{
					EditorMenu(client);
				}
				case 1:
				{
					ListZones(client, MenuHandler_ZoneModify);
				}
				case 2:
				{
					SaveZones(client);
					ZoneMenu(client);
				}
				case 3:
				{
					ReadZones();
					PrintToChat(client, "Zones are reloaded");
					ZoneMenu(client);
				}
				case 4:
				{
					ClearZonesMenu(client);
				}
			}
		}
		case MenuAction_End:
		{
			CloseHandle(tMenu);
		}
	}
}

public void ListZones(int client, MenuHandler handler)
{
	Handle Menu2 = CreateMenu(handler);
	SetMenuTitle(Menu2, "Avaliable Zones");
	
	char ZoneName[256];
	char ZoneId[64];
	char Id[64];
	int TeamId;
	int size = GetArraySize(g_Zones);
	if (size > 0)
	{
		for (int i = 0; i < size; ++i)
		{
			GetTrieValue(GetArrayCell(g_Zones, i), "team", TeamId);
			GetTrieString(GetArrayCell(g_Zones, i), "name", ZoneId, 64);
			IntToString(i, Id, sizeof(Id));
			Format(ZoneName, sizeof(ZoneName), ZoneId);
			AddMenuItem(Menu2, Id, ZoneId);
		}
	} else {
		AddMenuItem(Menu2, "", "No zones are avaliable", ITEMDRAW_DISABLED);
	}
	SetMenuExitBackButton(Menu2, true);
	DisplayMenu(Menu2, client, MENU_TIME_FOREVER);
}

public void EditorMenu(int client) {
	if (g_Editing[client] == 3)
	{
		DrawBeamBox(client);
		g_Editing[client] = 2;
	}
	Handle Menu2 = CreateMenu(MenuHandler_Editor);
	if (g_ClientSelectedZone[client] != -1)
		SetMenuTitle(Menu2, "Zone Editor (MODIFY)");
	else
		SetMenuTitle(Menu2, "Zone Editor");
	
	if (g_Editing[client] == 0)
		AddMenuItem(Menu2, "", "Start Zone");
	else
		AddMenuItem(Menu2, "", "Restart Zone");
	
	if (g_Editing[client] > 0)
	{
		AddMenuItem(Menu2, "", "Set Zone name");
		if (g_Editing[client] == 2)
			AddMenuItem(Menu2, "", "Continue Editing");
		else
			AddMenuItem(Menu2, "", "Pause Editing");
		AddMenuItem(Menu2, "", "Cancel Zone");
		AddMenuItem(Menu2, "", "Save Zone");
		switch (g_CurrentZoneTeam[client])
		{
			case 0:
			{
				AddMenuItem(Menu2, "", "Set Zone Yellow");
			}
			case 1:
			{
				AddMenuItem(Menu2, "", "Set Zone Green");
			}
			case 2:
			{
				AddMenuItem(Menu2, "", "Set Zone Red");
			}
			case 3:
			{
				AddMenuItem(Menu2, "", "Set Zone Blue");
			}
		}
		AddMenuItem(Menu2, "", "Go to Zone");
		AddMenuItem(Menu2, "", "Strech Zone");
		switch (g_CurrentZoneVis[client])
		{
			case 0:
			{
				AddMenuItem(Menu2, "", "Visibility: No One");
			}
			case 1:
			{
				AddMenuItem(Menu2, "", "Visibility: All");
			}
			case 2:
			{
				AddMenuItem(Menu2, "", "Visibility: T");
			}
			case 3:
			{
				AddMenuItem(Menu2, "", "Visibility: CT");
			}
		}
	}
	SetMenuExitBackButton(Menu2, true);
	DisplayMenu(Menu2, client, MENU_TIME_FOREVER);
}

public int MenuHandler_Editor(Handle tMenu, MenuAction action, int client, int item) {
	switch (action)
	{
		case MenuAction_Select:
		{
			switch (item)
			{
				case 0:
				{
					
					// Start
					g_Editing[client] = 1;
					float pos[3];
					float ang[3];
					GetClientEyePosition(client, pos);
					GetClientEyeAngles(client, ang);
					TR_TraceRayFilter(pos, ang, MASK_PLAYERSOLID, RayType_Infinite, TraceRayDontHitSelf, client);
					TR_GetEndPosition(g_Positions[client][0]);
					EditorMenu(client);
				}
				case 1:
				{
					PrintToChat(client, "Write in chat the name for the zone\nType !cancel for cancel the operation");
					g_bFixName[client] = true;
					//EditorMenu(client);
				}
				case 2:
				{
					// Pause
					if (g_Editing[client] == 2)
					{
						g_Editing[client] = 1;
					} else {
						DrawBeamBox(client);
						g_Editing[client] = 2;
					}
					EditorMenu(client);
				}
				case 3:
				{
					// Delete
					if (g_ClientSelectedZone[client] != -1)
						RemoveFromArray(g_Zones, g_ClientSelectedZone[client]);
					g_Editing[client] = 0;
					g_ClientSelectedZone[client] = -1;
					ZoneMenu(client);
					if (mode_plugin)RefreshZones();
				}
				case 4:
				{
					
					// Save
					g_Editing[client] = 2;
					Handle trie = CreateTrie();
					SetTrieArray(trie, "corda", g_Positions[client][0], 3);
					SetTrieArray(trie, "cordb", g_Positions[client][1], 3);
					SetTrieValue(trie, "team", g_CurrentZoneTeam[client]);
					SetTrieValue(trie, "vis", g_CurrentZoneVis[client]);
					
					
					
					if (g_ClientSelectedZone[client] != -1)
					{
						SetTrieString(trie, "name", g_CurrentZoneName[client]);
						SetArrayCell(g_Zones, g_ClientSelectedZone[client], trie);
						
					}
					else
					{
						Format(g_CurrentZoneName[client], 64, "Zone %i", GetArraySize(g_Zones) + 1);
						SetTrieString(trie, "name", g_CurrentZoneName[client]);
						PushArrayCell(g_Zones, trie);
					}
					//CloseHandle(trie);
					PrintToChat(client, "Zone saved");
					g_CurrentZoneTeam[client] = 0;
					g_CurrentZoneVis[client] = 0;
					g_Editing[client] = 0;
					ZoneMenu(client);
					if (mode_plugin)RefreshZones();
					// Save zone
				}
				case 5:
				{
					// Set team
					++g_CurrentZoneTeam[client];
					switch (g_CurrentZoneTeam[client])
					{
						case 1:
						{
							PrintToChat(client, "The zone is now Green");
						}
						case 2:
						{
							PrintToChat(client, "The zone is now Red");
						}
						case 3:
						{
							PrintToChat(client, "The zone is now Blue");
						}
						case 4:
						{
							g_CurrentZoneTeam[client] = 0;
							PrintToChat(client, "The zone is now Yellow");
						}
					}
					EditorMenu(client);
				}
				case 6:
				{
					// Teleport
					float ZonePos[3];
					AddVectors(g_Positions[client][0], g_Positions[client][1], ZonePos);
					ZonePos[0] = FloatDiv(ZonePos[0], 2.0);
					ZonePos[1] = FloatDiv(ZonePos[1], 2.0);
					ZonePos[2] = FloatDiv(ZonePos[2], 2.0);
					TeleportEntity(client, ZonePos, NULL_VECTOR, NULL_VECTOR);
					EditorMenu(client);
					PrintToChat(client, "You are teleported to the zone");
				}
				case 7:
				{
					// Scaling
					ScaleMenu(client);
				}
				case 8:
				{
					++g_CurrentZoneVis[client];
					switch (g_CurrentZoneVis[client])
					{
						case 1:
						{
							PrintToChat(client, "The zone is visible for ALL");
						}
						case 2:
						{
							PrintToChat(client, "The zone is visible for Terror");
						}
						case 3:
						{
							PrintToChat(client, "The zone is visible for Counter-Terrors");
						}
						case 4:
						{
							g_CurrentZoneVis[client] = 0;
							PrintToChat(client, "The zone is invisible");
						}
					}
					EditorMenu(client);
				}
			}
		}
		case MenuAction_Cancel:
		{
			ZoneMenu(client);
		}
		case MenuAction_End:
		{
			CloseHandle(tMenu);
		}
	}
}

float g_AvaliableScales[5] =  { 1.0, 5.0, 10.0, 50.0, 100.0 };
int g_ClientSelectedScale[MAXPLAYERS + 1];
int g_ClientSelectedPoint[MAXPLAYERS + 1];

public void ScaleMenu(int client) {
	g_Editing[client] = 3;
	Handle Menu2 = CreateMenu(MenuHandler_Scale);
	SetMenuTitle(Menu2, "Strech Zone");
	if (g_ClientSelectedPoint[client] == 1)
		AddMenuItem(Menu2, "", "Point B");
	else
		AddMenuItem(Menu2, "", "Point A");
	AddMenuItem(Menu2, "", "+ Width");
	AddMenuItem(Menu2, "", "- Width");
	AddMenuItem(Menu2, "", "+ Height");
	AddMenuItem(Menu2, "", "- Height");
	AddMenuItem(Menu2, "", "+ Length");
	AddMenuItem(Menu2, "", "- Length");
	char ScaleSize[128];
	Format(ScaleSize, sizeof(ScaleSize), "Scale Size %f", g_AvaliableScales[g_ClientSelectedScale[client]]);
	AddMenuItem(Menu2, "", ScaleSize);
	SetMenuExitBackButton(Menu2, true);
	DisplayMenu(Menu2, client, MENU_TIME_FOREVER);
}

public int MenuHandler_Scale(Handle tMenu, MenuAction action, int client, int item)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			switch (item)
			{
				case 0:
				{
					if (g_ClientSelectedPoint[client] == 1)
						g_ClientSelectedPoint[client] = 0;
					else
						g_ClientSelectedPoint[client] = 1;
				}
				case 1:
				{
					g_Positions[client][g_ClientSelectedPoint[client]][0] = FloatAdd(g_Positions[client][g_ClientSelectedPoint[client]][0], g_AvaliableScales[g_ClientSelectedScale[client]]);
				}
				case 2:
				{
					g_Positions[client][g_ClientSelectedPoint[client]][0] = FloatSub(g_Positions[client][g_ClientSelectedPoint[client]][0], g_AvaliableScales[g_ClientSelectedScale[client]]);
				}
				case 3:
				{
					g_Positions[client][g_ClientSelectedPoint[client]][1] = FloatAdd(g_Positions[client][g_ClientSelectedPoint[client]][1], g_AvaliableScales[g_ClientSelectedScale[client]]);
				}
				case 4:
				{
					g_Positions[client][g_ClientSelectedPoint[client]][1] = FloatSub(g_Positions[client][g_ClientSelectedPoint[client]][1], g_AvaliableScales[g_ClientSelectedScale[client]]);
				}
				case 5:
				{
					g_Positions[client][g_ClientSelectedPoint[client]][2] = FloatAdd(g_Positions[client][g_ClientSelectedPoint[client]][2], g_AvaliableScales[g_ClientSelectedScale[client]]);
				}
				case 6:
				{
					g_Positions[client][g_ClientSelectedPoint[client]][2] = FloatSub(g_Positions[client][g_ClientSelectedPoint[client]][2], g_AvaliableScales[g_ClientSelectedScale[client]]);
				}
				case 7:
				{
					++g_ClientSelectedScale[client];
					if (g_ClientSelectedScale[client] == 5)
						g_ClientSelectedScale[client] = 0;
				}
			}
			ScaleMenu(client);
		}
		case MenuAction_Cancel:
		{
			EditorMenu(client);
		}
		case MenuAction_End:
		{
			CloseHandle(tMenu);
		}
	}
}

public int MenuHandler_ZoneModify(Handle tMenu, MenuAction action, int client, int item)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char aID[64];
			GetMenuItem(tMenu, item, aID, sizeof(aID));
			g_ClientSelectedZone[client] = StringToInt(aID);
			DrawBeamBox(client);
			g_Editing[client] = 2;
			if (g_ClientSelectedZone[client] != -1)
				GetClientSelectedZone(client, g_Positions[client], g_CurrentZoneTeam[client], g_CurrentZoneVis[client]);
			EditorMenu(client);
			
		}
		case MenuAction_Cancel:
		{
			ZoneMenu(client);
		}
		case MenuAction_End:
		{
			CloseHandle(tMenu);
		}
	}
}

public void GetClientSelectedZone(int client, float poses[2][3], int &team, int &vis)
{
	float posA[3];
	float posB[3];
	if (g_ClientSelectedZone[client] != -1)
	{
		Handle trie = GetArrayCell(g_Zones, g_ClientSelectedZone[client]);
		GetTrieArray(trie, "corda", posA, sizeof(posA));
		GetTrieArray(trie, "cordb", posB, sizeof(posB));
		GetTrieValue(trie, "team", team);
		GetTrieValue(trie, "vis", vis);
		GetTrieString(trie, "name", g_CurrentZoneName[client], 64);
		//CloseHandle(trie);
		poses[0] = posA;
		poses[1] = posB;
	}
}

public void ClearZonesMenu(int client) {
	Handle Menu2 = CreateMenu(MenuHandler_ClearZones);
	SetMenuTitle(Menu2, "Are you sure, you want to clear all zones on this map?");
	AddMenuItem(Menu2, "", "NO GO BACK!");
	AddMenuItem(Menu2, "", "NO GO BACK!");
	AddMenuItem(Menu2, "", "YES! DO IT!");
	DisplayMenu(Menu2, client, 20);
}

public int MenuHandler_ClearZones(Handle tMenu, MenuAction action, int client, int item)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			if (item == 2)
			{
				ClearArray(g_Zones);
				PrintToChat(client, "Zones cleared");
				RemoveZones();
			}
			ZoneMenu(client);
			
		}
		case MenuAction_End:
		{
			CloseHandle(tMenu);
		}
	}
}


stock void GetMiddleOfABox(const float vec1[3], const float vec2[3], float buffer[3]) {
	float mid[3];
	MakeVectorFromPoints(vec1, vec2, mid);
	mid[0] = mid[0] / 2.0;
	mid[1] = mid[1] / 2.0;
	mid[2] = mid[2] / 2.0;
	AddVectors(vec1, mid, buffer);
}

stock void RefreshZones() {
	RemoveZones();
	int size = GetArraySize(g_Zones);
	float posA[3];
	float posB[3];
	char nombre[64];
	for (int i = 0; i < size; ++i)
	{
		Handle trie = GetArrayCell(g_Zones, i);
		GetTrieArray(trie, "corda", posA, sizeof(posA));
		GetTrieArray(trie, "cordb", posB, sizeof(posB));
		GetTrieString(trie, "name", nombre, 64);
		int zone = CreateZoneEntity(posA, posB, nombre);
		char id[8];
		IntToString(i, id, sizeof(id));
		Entity_SetGlobalName(zone, id);
	}
}

stock void RemoveZones()
{
	// First remove any old zone triggers
	int iEnts = GetMaxEntities();
	char sClassName[64];
	for (int i = MaxClients; i < iEnts; i++)
	{
		if (IsValidEntity(i)
			 && IsValidEdict(i)
			 && GetEdictClassname(i, sClassName, sizeof(sClassName))
			 && StrContains(sClassName, "trigger_multiple") != -1
			 && GetEntPropString(i, Prop_Data, "m_iName", sClassName, sizeof(sClassName))
			 && StrContains(sClassName, "sm_devzone") != -1)
		{
			UnhookSingleEntityOutput(i, "OnStartTouch", EntOut_OnStartTouch);
			UnhookSingleEntityOutput(i, "OnEndTouch", EntOut_OnEndTouch);
			AcceptEntityInput(i, "Kill");
		}
	}
} 

/**
 * Gets the Global Name of an entity.
 *
 * @param entity            Entity index.
 * @param buffer            Return/Output buffer.
 * @param size        Max size of buffer.
 * @return          Number of non-null bytes written.
 */
stock int Entity_GetGlobalName(int entity, char[] buffer, int size)
{
    return GetEntPropString(entity, Prop_Data, "m_iGlobalname", buffer, size);
}

/**
 * Sets the Global Name of an entity.
 *
 * @param entity            Entity index.
 * @param name        The global name you want to set.
 * @return          True on success, false otherwise.
 */
stock bool Entity_SetGlobalName(int entity, const char[] name, any:...)
{
    char format[128];
    VFormat(format, sizeof(format), name, 3);

    return DispatchKeyValue(entity, "globalname", format);
}

/**
 * Converts the given string to lower case
 *
 * @param szString     Input string for conversion and also the output
 * @return             void
 */
stock void StringToLowerCase(char[] szInput) 
{
    int iIterator = 0;

    while (szInput[iIterator] != EOS) 
    {
        if (!IsCharLower(szInput[iIterator])) szInput[iIterator] = CharToLower(szInput[iIterator]);
        else szInput[iIterator] = szInput[iIterator];

        iIterator++;
    }

    szInput[iIterator + 1] = EOS;
}
