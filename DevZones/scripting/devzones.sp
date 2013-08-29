// Based in the plugin "Anti Spawn Camp" of Imdawe

#pragma semicolon 1
#include <sourcemod>
#include <sdktools>

//Configure this
#define CHECKER_VALUE 0.1 // checks per second, low value = more precise but more CPU consume, More hight = less precise but less CPU consume

// end



#define VERSION "1.2"



new beamColorT[4] = {255, 0, 0, 255};
new beamColorCT[4] = {0, 0, 255, 255};
new beamColorN[4 ]= {255, 255, 0, 255};
new beamColorM[4]={0, 255, 0, 255};

new g_CurrentZoneTeam[MAXPLAYERS+1];
new g_CurrentZoneVis[MAXPLAYERS+1];
new String:g_CurrentZoneName[MAXPLAYERS+1][64];
// VARIABLES
new Handle:g_Zones=INVALID_HANDLE;
new g_Editing[MAXPLAYERS+1]={0,...};
new Float:g_Positions[MAXPLAYERS+1][2][3];
new g_ClientSelectedZone[MAXPLAYERS+1]={-1,...};
new bool:FijarNombre[MAXPLAYERS+1];

new g_BeamSprite;
new g_HaloSprite;

new Handle:hOnClientEntry = INVALID_HANDLE;
new Handle:hOnClientLeave = INVALID_HANDLE;

enum listado
{
	String:nombrez[64],
	bool:esta
}

new g_zonas[MAXPLAYERS+1][192][listado];




// PLUGIN INFO
public Plugin:myinfo =
{
	name = "SM DEV Zones",
	author = "Franc1sco franug",
	description = "",
	version = VERSION,
	url = "http://www.clanuea.com/"
};

public OnPluginStart()
{
	CreateConVar("sm_DevZones", VERSION, "plugin", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	g_Zones = CreateArray(256);
	RegAdminCmd("sm_zones", Command_CampZones, ADMFLAG_ROOT);
	RegConsoleCmd("say",fnHookSay);
	//HookEvent("round_start", OnRoundStart);

	CreateTimer(CHECKER_VALUE, BeamBoxAll, INVALID_HANDLE, TIMER_REPEAT);
	ReadZones();
}

public OnClientPostAdminCheck(client)
{
	g_ClientSelectedZone[client]=-1;
	g_Editing[client]=0;
	FijarNombre[client] = false;
}

/*
public OnClientDisconnect(client)
{
	g_ClientSelectedZone[client]=-1;
	g_Editing[client]=0;
	FijarNombre[client] = false;
}
*/

/*
public Action:OnRoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{

}*/

public OnMapStart()
{

	g_BeamSprite = PrecacheModel("materials/sprites/laser.vmt");
	g_HaloSprite = PrecacheModel("materials/sprites/halo01.vmt");
	ReadZones();
}

public OnMapEnd()
{
	SaveZones(0);
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	BeamBox_OnPlayerRunCmd(client);
}

public Action:Command_CampZones(client, args)
{
	ZoneMenu(client);
}

public getZoneTeamColor(team, color[4])
{
	switch(team)
	{
		case 1:
		{
			color=beamColorM;
		}
		case 2:
		{
			color=beamColorT;
		}
		case 3:
		{
			color=beamColorCT;
		}
		default:
		{
			color=beamColorN;
		}
	}
	// Get zone team -> get zone color
}

public ReadZones()
{
	ClearArray(g_Zones);
	new String:Path[512];
	BuildPath(Path_SM, Path, sizeof(Path), "configs/dev_zones");
	if(!DirExists(Path))
		CreateDirectory(Path, 0777); 

	new String:map[64];
	GetCurrentMap(map, sizeof(map));
	BuildPath(Path_SM, Path, sizeof(Path), "configs/dev_zones/%s.zones.txt", map);
	if(!FileExists(Path))
	{	
		//new Handle:file = OpenFile(Path, "w");
		//CloseHandle(file);
		new Handle:kv = CreateKeyValues("Zones");
		KeyValuesToFile(kv, Path);
	}
	
	
	new Handle:kv = CreateKeyValues("Zones");
	FileToKeyValues(kv, Path);
	if (!KvGotoFirstSubKey(kv))
	{
		PrintToServer("[ERROR] Config file is corrupted: %s", Path);
		return;
	}
	decl Float:pos1[3], Float:pos2[3], String:nombre[64];
	do
	{
		KvGetVector(kv, "cordinate_a", pos1);
		KvGetVector(kv, "cordinate_b", pos2);
		KvGetString(kv, "name", nombre, 64);
		new Handle:trie = CreateTrie();
		SetTrieArray(trie, "corda", pos1, 3);
		SetTrieArray(trie, "cordb", pos2, 3);
		SetTrieValue(trie, "team", KvGetNum(kv, "team", 0));
		SetTrieValue(trie, "vis", KvGetNum(kv, "vis", 0));
		SetTrieString(trie, "name", nombre);
		PushArrayCell(g_Zones, trie);
		//CloseHandle(trie);
	}while(KvGotoNextKey(kv));
	CloseHandle(kv);
}

public SaveZones(client)
{
	new String:Path[512];
	new String:map[64];
	GetCurrentMap(map, sizeof(map));
	BuildPath(Path_SM, Path, sizeof(Path), "configs/dev_zones/%s.zones.txt", map);
	new Handle:file = OpenFile(Path, "w+");
	CloseHandle(file);
	new Float:pos1[3], Float:pos2[3], String:SectName[64], Team, Vis,String:nombre[64];
	new size=GetArraySize(g_Zones);
	new Handle:kv = CreateKeyValues("Zones");
	for(new i=0;i<size;++i)
	{
		IntToString(i, SectName, sizeof(SectName));
		
		new Handle:trie = GetArrayCell(g_Zones, i);
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
	if(client!=0)
		PrintToChat(client, "All zones are saved in file.");
}

public bool:TraceRayDontHitSelf(entity, mask, any:data)
{
	if(entity == data)
		return false;
	return true;
}

public Action:fnHookSay(client,args)
{
	if(!FijarNombre[client]) return;
	
	decl String:sArgs[192];
	GetCmdArgString(sArgs,sizeof(sArgs));
		
	StripQuotes(sArgs);
	
	ReplaceString(sArgs, 192, "'", ".");
	ReplaceString(sArgs, 192, "<", ".");
	//ReplaceString(sArgs, 192, "\"", ".");
	if(strlen(sArgs) > 63)
	{
		PrintToChat(client, "the name is too long, try other name");
		return;
	}
	if(StrEqual(sArgs, "!cancel"))
	{
		PrintToChat(client, "Set name action canceled");
		EditorMenu(client);
		return;
	}
	decl String:ZoneId[64];
	new size = GetArraySize(g_Zones);
	for(new i=0;i<size;++i)
	{
		new Handle:trie = GetArrayCell(g_Zones, i);
		GetTrieString(trie, "name", ZoneId, 64);
		if(StrEqual(ZoneId, sArgs))
		{
			PrintToChat(client, "The name already exist, write other name");
			return;
		}
	}
	
	Format(g_CurrentZoneName[client], 64, sArgs);
	PrintToChat(client, "Zone name set to %s",sArgs);
	FijarNombre[client] = false;
	EditorMenu(client);
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	hOnClientEntry = CreateGlobalForward("Zone_OnClientEntry", ET_Ignore, Param_Cell, Param_String);
	hOnClientLeave = CreateGlobalForward("Zone_OnClientLeave", ET_Ignore, Param_Cell, Param_String);
	CreateNative("Zone_IsClientInZone", Native_InZone);
	CreateNative("Zone_GetZonePosition", Native_Teleport);
    
	return APLRes_Success;
}

public Native_InZone(Handle:plugin, argc)
{  
	
	decl String:name[64];
	
	GetNativeString(2, name, 64);
	new client = GetNativeCell(1);
	new bool:igual = GetNativeCell(3);
	new bool:sensitive = GetNativeCell(4);
	
	new size = GetArraySize(g_Zones);
	for(new i=0;i<size;++i)
	{
		if(igual)
		{
			if(StrEqual(g_zonas[client][i][nombrez], name, sensitive) && g_zonas[client][i][esta])
				return true;
		}
		else
		{
			if(StrContains(g_zonas[client][i][nombrez], name, sensitive) == 0 && g_zonas[client][i][esta])
				return true;
		}
				
	}
	return false;
}

public Native_Teleport(Handle:plugin, argc)
{  
	
	decl String:name[64], String:namezone[64], Float:posA[3], Float:posB[3];
	
	GetNativeString(1, name, 64);
	new bool:sensitive = GetNativeCell(2);
	
	new size = GetArraySize(g_Zones);
	if(size>0)
	{
		for(new i=0;i<size;++i)
		{
			GetTrieString(GetArrayCell(g_Zones, i), "name", namezone, 64);
			if(StrEqual(name, namezone, sensitive))
			{
				GetTrieArray(GetArrayCell(g_Zones, i), "corda", posA, sizeof(posA));
				GetTrieArray(GetArrayCell(g_Zones, i), "cordb", posB, sizeof(posB));
				new Float:ZonePos[3];
				AddVectors(posA, posB, ZonePos);
				ZonePos[0]=FloatDiv(ZonePos[0], 2.0);
				ZonePos[1]=FloatDiv(ZonePos[1], 2.0);
				ZonePos[2]=FloatDiv(ZonePos[2], 2.0);
				SetNativeArray(3, ZonePos, 3);
				return true;
			}
		}
	}
	return false;
}

// beambox.sp

public DrawBeamBox(client)
{
	new zColor[4];
	getZoneTeamColor(g_CurrentZoneTeam[client], zColor);
	TE_SendBeamBoxToClient(client, g_Positions[client][1], g_Positions[client][0], g_BeamSprite, g_HaloSprite,  0, 30, 1.0, 5.0, 5.0, 2, 1.0, zColor, 0);
	CreateTimer(1.0, BeamBox, client, TIMER_REPEAT);
}

public Action:BeamBox(Handle:timer, any:client)
{
	if(IsClientInGame(client))
	{
		if(g_Editing[client]==2)
		{
			new zColor[4];
			getZoneTeamColor(g_CurrentZoneTeam[client], zColor);
			TE_SendBeamBoxToClient(client, g_Positions[client][1], g_Positions[client][0], g_BeamSprite, g_HaloSprite,  0, 30, 1.0, 5.0, 5.0, 2, 1.0, zColor, 0);
			return Plugin_Continue;
		}
	}
	return Plugin_Stop;
}

public Action:BeamBoxAll(Handle:timer, any:data)
{
	new size = GetArraySize(g_Zones);
	new Float:posA[3], Float:posB[3], zColor[4], Team, Vis, String:nombre[64];
	for(new i=0;i<size;++i)
	{
		new Handle:trie = GetArrayCell(g_Zones, i);
		GetTrieArray(trie, "corda", posA, sizeof(posA));
		GetTrieArray(trie, "cordb", posB, sizeof(posB));
		GetTrieValue(trie, "team", Team);
		GetTrieValue(trie, "vis", Vis);
		GetTrieString(trie, "name", nombre, 64);
		//CloseHandle(trie);
		for (new p = 1; p <= MaxClients; p++) 
		{
			if(IsClientInGame(p))
			{
				if(g_ClientSelectedZone[p]!=i && (Vis==1 || GetClientTeam(p)==Vis))
				{
					getZoneTeamColor(Team, zColor);
					TE_SendBeamBoxToClient(p, posA, posB, g_BeamSprite, g_HaloSprite,  0, 30, CHECKER_VALUE, 5.0, 5.0, 2, 1.0, zColor, 0);
				}
				if(IsPlayerAlive(p))
				{
					if(IsbetweenRect(NULL_VECTOR, posA, posB, p))
					{
						if(!g_zonas[p][i][esta])
						{
							// entra
							g_zonas[p][i][esta] = true;
							Format(g_zonas[p][i][nombrez], 64, nombre);
							Call_StartForward(hOnClientEntry);
							Call_PushCell(p);
							Call_PushString(g_zonas[p][i][nombrez]);
							Call_Finish();
						}
					}
					else
					{
						if(g_zonas[p][i][esta])
						{
							// sale
							g_zonas[p][i][esta] = false;
							Format(g_zonas[p][i][nombrez], 64, nombre);
							Call_StartForward(hOnClientLeave);
							Call_PushCell(p);
							Call_PushString(g_zonas[p][i][nombrez]);
							Call_Finish();
						}
					}
				}
			}
		}
	}	
	return Plugin_Continue;
}

public BeamBox_OnPlayerRunCmd(client)
{	
	if(g_Editing[client]==1 || g_Editing[client]==3)
	{
		new Float:pos[3], Float:ang[3], zColor[4];
		getZoneTeamColor(g_CurrentZoneTeam[client], zColor);
		if(g_Editing[client]==1)
		{
			GetClientEyePosition(client, pos);
			GetClientEyeAngles(client, ang);
			TR_TraceRayFilter(pos, ang, MASK_PLAYERSOLID, RayType_Infinite, TraceRayDontHitSelf, client);
			TR_GetEndPosition(g_Positions[client][1]);
		}
		TE_SendBeamBoxToClient(client, g_Positions[client][1], g_Positions[client][0], g_BeamSprite, g_HaloSprite,  0, 30, 0.1, 5.0, 5.0, 2, 1.0, zColor, 0);
	}
}

stock TE_SendBeamBoxToClient(client, Float:uppercorner[3], const Float:bottomcorner[3], ModelIndex, HaloIndex, StartFrame, FrameRate, Float:Life, Float:Width, Float:EndWidth, FadeLength, Float:Amplitude, const Color[4], Speed)
{
	// Create the additional corners of the box
	new Float:tc1[3];
	AddVectors(tc1, uppercorner, tc1);
	tc1[0] = bottomcorner[0];
	
	new Float:tc2[3];
	AddVectors(tc2, uppercorner, tc2);
	tc2[1] = bottomcorner[1];
	
	new Float:tc3[3];
	AddVectors(tc3, uppercorner, tc3);
	tc3[2] = bottomcorner[2];
	
	new Float:tc4[3];
	AddVectors(tc4, bottomcorner, tc4);
	tc4[0] = uppercorner[0];
	
	new Float:tc5[3];
	AddVectors(tc5, bottomcorner, tc5);
	tc5[1] = uppercorner[1];
	
	new Float:tc6[3];
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

bool:IsbetweenRect(Float:Pos[3], Float:Corner1[3], Float:Corner2[3], client=0) 
{ 
	decl Float:Entity[3]; 
	decl Float:field1[2]; 
	decl Float:field2[2]; 
	decl Float:field3[2]; 
	
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

public ZoneMenu(client)
{
	g_ClientSelectedZone[client]=-1;
	g_Editing[client]=0;
	new Handle:Menu = CreateMenu(Handle_ZoneMenu);
	SetMenuTitle(Menu, "Zones");
	AddMenuItem(Menu, "", "Create Zone");
	AddMenuItem(Menu, "", "Edit Zones");
	AddMenuItem(Menu, "", "Save Zones");
	AddMenuItem(Menu, "", "Reload Zones");
	AddMenuItem(Menu, "", "Clear Zones");
	SetMenuExitBackButton(Menu, true);
	DisplayMenu(Menu, client, MENU_TIME_FOREVER);
}

public Handle_ZoneMenu(Handle:tMenu, MenuAction:action, client, item)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			switch(item)
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

public ListZones(client, MenuHandler:handler)
{
	new Handle:Menu = CreateMenu(handler);
	SetMenuTitle(Menu, "Avaliable Zones");
	
	decl String:ZoneName[256], String:ZoneId[64], String:Id[64],TeamId;
	new size = GetArraySize(g_Zones);
	if(size>0)
	{
		for(new i=0;i<size;++i)
		{
			GetTrieValue(GetArrayCell(g_Zones, i), "team", TeamId);
			GetTrieString(GetArrayCell(g_Zones, i), "name", ZoneId, 64);
			IntToString(i, Id, sizeof(Id));
			Format(ZoneName, sizeof(ZoneName), ZoneId);
			AddMenuItem(Menu, Id, ZoneId);
		}
	}else{
		AddMenuItem(Menu, "", "No zones are avaliable", ITEMDRAW_DISABLED);
	}
	SetMenuExitBackButton(Menu, true);
	DisplayMenu(Menu, client, MENU_TIME_FOREVER);
}

public EditorMenu(client)
{
	if(g_Editing[client]==3)
	{	
		DrawBeamBox(client);
		g_Editing[client]=2;
	}
	new Handle:Menu = CreateMenu(MenuHandler_Editor);
	if(g_ClientSelectedZone[client] != -1)
		SetMenuTitle(Menu, "Zone Editor (MODIFY)");
	else
		SetMenuTitle(Menu, "Zone Editor");
		
	if(g_Editing[client]==0)
		AddMenuItem(Menu, "", "Start Zone");
	else
		AddMenuItem(Menu, "", "Restart Zone");
		
	if(g_Editing[client]>0)
	{
		AddMenuItem(Menu, "", "Set Zone name");
		if(g_Editing[client]==2)
			AddMenuItem(Menu, "", "Continue Editing");
		else
			AddMenuItem(Menu, "", "Pause Editing");
		AddMenuItem(Menu, "", "Cancel Zone");
		AddMenuItem(Menu, "", "Save Zone");
		switch(g_CurrentZoneTeam[client])
		{
			case 0:
			{
				AddMenuItem(Menu, "", "Set Zone Yellow");
			}
			case 1:
			{
				AddMenuItem(Menu, "", "Set Zone Green");
			}
			case 2:
			{
				AddMenuItem(Menu, "", "Set Zone Red");
			}
			case 3:
			{
				AddMenuItem(Menu, "", "Set Zone Blue");
			}
		}
		AddMenuItem(Menu, "", "Go to Zone");
		AddMenuItem(Menu, "", "Strech Zone");
		switch(g_CurrentZoneVis[client])
		{
			case 0:
			{
				AddMenuItem(Menu, "", "Visibility: No One");
			}
			case 1:
			{
				AddMenuItem(Menu, "", "Visibility: All");
			}
			case 2:
			{
				AddMenuItem(Menu, "", "Visibility: T");
			}
			case 3:
			{
				AddMenuItem(Menu, "", "Visibility: CT");
			}
		}
	}
	SetMenuExitBackButton(Menu, true);
	DisplayMenu(Menu, client, MENU_TIME_FOREVER);
}

public MenuHandler_Editor(Handle:tMenu, MenuAction:action, client, item)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			switch(item)
			{
				case 0:
				{
					
					// Start
					g_Editing[client]=1;
					new Float:pos[3], Float:ang[3];
					GetClientEyePosition(client, pos);
					GetClientEyeAngles(client, ang);
					TR_TraceRayFilter(pos, ang, MASK_PLAYERSOLID, RayType_Infinite, TraceRayDontHitSelf, client);
					TR_GetEndPosition(g_Positions[client][0]);
					EditorMenu(client);
				}
				case 1:
				{
					PrintToChat(client, "Write in chat the name for the zone\nType !cancel for cancel the operation");
					FijarNombre[client] = true;
					//EditorMenu(client);
				}
				case 2:
				{	
					// Pause
					if(g_Editing[client]==2)
					{
						g_Editing[client]=1;
					}else{
						DrawBeamBox(client);
						g_Editing[client]=2;
					}
					EditorMenu(client);
				}
				case 3:
				{
					// Delete
					if(g_ClientSelectedZone[client] != -1)
						RemoveFromArray(g_Zones, g_ClientSelectedZone[client]);
					g_Editing[client]=0;
					g_ClientSelectedZone[client]=-1;
					ZoneMenu(client);
				}
				case 4:
				{

					// Save
					g_Editing[client]=2;
					new Handle:trie = CreateTrie();
					SetTrieArray(trie, "corda", g_Positions[client][0], 3);
					SetTrieArray(trie, "cordb", g_Positions[client][1], 3);
					SetTrieValue(trie, "team", g_CurrentZoneTeam[client]);
					SetTrieValue(trie, "vis", g_CurrentZoneVis[client]);
					
					
					
					if(g_ClientSelectedZone[client] != -1)
					{
						SetTrieString(trie, "name", g_CurrentZoneName[client]);
						SetArrayCell(g_Zones, g_ClientSelectedZone[client], trie);
						
					}
					else
					{
						Format(g_CurrentZoneName[client], 64, "Zone %i", GetArraySize(g_Zones)+1);
						SetTrieString(trie, "name", g_CurrentZoneName[client]);
						PushArrayCell(g_Zones, trie);
					}
					//CloseHandle(trie);
					PrintToChat(client, "Zone saved");
					g_CurrentZoneTeam[client]=0;
					g_CurrentZoneVis[client]=0;
					g_Editing[client]=0;
					ZoneMenu(client);
					// Save zone
				}
				case 5:
				{
					// Set team
					++g_CurrentZoneTeam[client];
					switch(g_CurrentZoneTeam[client])
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
							g_CurrentZoneTeam[client]=0;
							PrintToChat(client, "The zone is now Yellow");
						}
					}
					EditorMenu(client);
				}
				case 6:
				{
					// Teleport
					new Float:ZonePos[3];
					AddVectors(g_Positions[client][0], g_Positions[client][1], ZonePos);
					ZonePos[0]=FloatDiv(ZonePos[0], 2.0);
					ZonePos[1]=FloatDiv(ZonePos[1], 2.0);
					ZonePos[2]=FloatDiv(ZonePos[2], 2.0);
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
					switch(g_CurrentZoneVis[client])
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
							g_CurrentZoneVis[client]=0;
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
new Float:g_AvaliableScales[5]={1.0, 5.0, 10.0, 50.0, 100.0};
new g_ClientSelectedScale[MAXPLAYERS+1];
new g_ClientSelectedPoint[MAXPLAYERS+1];
public ScaleMenu(client)
{
	g_Editing[client]=3;
	new Handle:Menu = CreateMenu(MenuHandler_Scale);
	SetMenuTitle(Menu, "Strech Zone");
	if(g_ClientSelectedPoint[client]==1)
		AddMenuItem(Menu, "", "Point B");
	else
		AddMenuItem(Menu, "", "Point A");
	AddMenuItem(Menu, "", "+ Width");
	AddMenuItem(Menu, "", "- Width");
	AddMenuItem(Menu, "", "+ Height");
	AddMenuItem(Menu, "", "- Height");
	AddMenuItem(Menu, "", "+ Length");
	AddMenuItem(Menu, "", "- Length");
	decl String:ScaleSize[128];
	Format(ScaleSize, sizeof(ScaleSize), "Scale Size %f", g_AvaliableScales[g_ClientSelectedScale[client]]);
	AddMenuItem(Menu, "", ScaleSize);
	SetMenuExitBackButton(Menu, true);
	DisplayMenu(Menu, client, MENU_TIME_FOREVER);
}

public MenuHandler_Scale(Handle:tMenu, MenuAction:action, client, item)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			switch(item)
			{
				case 0:
				{
					if(g_ClientSelectedPoint[client]==1)
						g_ClientSelectedPoint[client]=0;
					else
						g_ClientSelectedPoint[client]=1;
				}
				case 1:
				{
					g_Positions[client][g_ClientSelectedPoint[client]][0]=FloatAdd(g_Positions[client][g_ClientSelectedPoint[client]][0], g_AvaliableScales[g_ClientSelectedScale[client]]);
				}
				case 2:
				{
					g_Positions[client][g_ClientSelectedPoint[client]][0]=FloatSub(g_Positions[client][g_ClientSelectedPoint[client]][0], g_AvaliableScales[g_ClientSelectedScale[client]]);
				}
				case 3:
				{
					g_Positions[client][g_ClientSelectedPoint[client]][1]=FloatAdd(g_Positions[client][g_ClientSelectedPoint[client]][1], g_AvaliableScales[g_ClientSelectedScale[client]]);
				}
				case 4:
				{
					g_Positions[client][g_ClientSelectedPoint[client]][1]=FloatSub(g_Positions[client][g_ClientSelectedPoint[client]][1], g_AvaliableScales[g_ClientSelectedScale[client]]);
				}
				case 5:
				{
					g_Positions[client][g_ClientSelectedPoint[client]][2]=FloatAdd(g_Positions[client][g_ClientSelectedPoint[client]][2], g_AvaliableScales[g_ClientSelectedScale[client]]);
				}
				case 6:
				{
					g_Positions[client][g_ClientSelectedPoint[client]][2]=FloatSub(g_Positions[client][g_ClientSelectedPoint[client]][2], g_AvaliableScales[g_ClientSelectedScale[client]]);
				}
				case 7:
				{
					++g_ClientSelectedScale[client];
					if(g_ClientSelectedScale[client]==5)
						g_ClientSelectedScale[client]=0;
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

public MenuHandler_ZoneModify(Handle:tMenu, MenuAction:action, client, item)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			new String:aID[64];
			GetMenuItem(tMenu, item, aID, sizeof(aID));
			g_ClientSelectedZone[client] = StringToInt(aID);
			DrawBeamBox(client);
			g_Editing[client]=2;
			if(g_ClientSelectedZone[client]!= -1)
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

public GetClientSelectedZone(client, Float:poses[2][3], &team, &vis)
{
	new Float:posA[3], Float:posB[3];
	if(g_ClientSelectedZone[client]!=-1)
	{
		new Handle:trie = GetArrayCell(g_Zones, g_ClientSelectedZone[client]);
		GetTrieArray(trie, "corda", posA, sizeof(posA));
		GetTrieArray(trie, "cordb", posB, sizeof(posB));
		GetTrieValue(trie, "team", team);
		GetTrieValue(trie, "vis", vis);
		GetTrieString(trie, "name", g_CurrentZoneName[client], 64);
		//CloseHandle(trie);
		poses[0]=posA;
		poses[1]=posB;
	}
}

public ClearZonesMenu(client)
{
	new Handle:Menu = CreateMenu(MenuHandler_ClearZones);
	SetMenuTitle(Menu, "Are you sure, you want to clear all zones on this map?");
	AddMenuItem(Menu, "","NO GO BACK!");
	AddMenuItem(Menu, "","NO GO BACK!");
	AddMenuItem(Menu, "","YES! DO IT!");
	DisplayMenu(Menu, client, 20);
}

public MenuHandler_ClearZones(Handle:tMenu, MenuAction:action, client, item)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			if(item==2)
			{
				ClearArray(g_Zones);
				PrintToChat(client, "Zones cleared");
			}
			ZoneMenu(client);

		}
		case MenuAction_End:
		{
			CloseHandle(tMenu);
		}
	}
}

