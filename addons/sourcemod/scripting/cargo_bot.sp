#pragma semicolon 1

#include <sourcemod>
#include <clientprefs>
#include <sdktools_voice>
#include <SteamWorks>
#include <audio>

#pragma newdecls required

#define MAX_SAYSOUNDS 512

char g_sAudioCommand[MAX_SAYSOUNDS][64];
char g_sAudioPath[MAX_SAYSOUNDS][PLATFORM_MAX_PATH];

Handle g_hCookieMute = INVALID_HANDLE;
bool g_bMuted[MAXPLAYERS+1];

AudioPlayer g_AudioPlayer[MAXPLAYERS+1];
Menu g_AudioMenu;

int g_iTotal;

ConVar g_Cvar_AntiSpam;
ConVar g_Cvar_MaxSpam;
ConVar g_Cvar_Cooldown;

bool g_bAntiSpam;
int g_iMaxSpam;
float g_fCooldown;

float g_fClientAllowAgain[MAXPLAYERS+1];

int g_iStacking;
int g_iAllAllowAgain;

Handle g_hTimerCheckSpamming = INVALID_HANDLE;

public Plugin myinfo = 
{
	name = "[CS:GO] Cargo Bot",
	author = "Oylsister, Special Thanks: Cruze, Vauff, Impact",
	description = "Relative to Sympho bot which can play sound on their voice channel, so player doesn't need to download sound file.",
	version = "2.0",
	url = "https://github.com/oylsister/Cargo-Bot"
}

public void OnPluginStart()
{
	RegConsoleCmd("sm_cargo", Cargo_Command);
	RegConsoleCmd("sm_mutecargo", MuteCargo_Command);
	RegConsoleCmd("sm_unmutecargo", UnmuteCargo_Command);
	RegConsoleCmd("sm_stopme", StopPlayClientSound_Command);
	RegConsoleCmd("sm_yt", YoutubeCommand);

	RegAdminCmd("sm_reloadcargo", ReloadCargo_Sound, ADMFLAG_CONFIG);
	RegAdminCmd("sm_stopall", StopPlayAllSound_Command, ADMFLAG_GENERIC);

	AddCommandListener(OnClientSay, "say");
	AddCommandListener(OnClientSay, "say_team");

	g_Cvar_AntiSpam = CreateConVar("sm_cargo_enable_antispam", "1.0", "Enable Anti Spaming", _, true, 0.0, true, 1.0);
	g_Cvar_MaxSpam = CreateConVar("sm_cargo_maxspam", "10.0", "Maximum spam that allow in 10 seconds",  _, true, 1.0, false);
	g_Cvar_Cooldown = CreateConVar("sm_cargo_cooldown", "5.0", "Cooldown for each client after use one sound", _, true, 0.0, false);

	g_hCookieMute = RegClientCookie("sm_cargo_bot_mute", "Mute Cargo Bot Sound", CookieAccess_Protected);

	HookConVarChange(g_Cvar_AntiSpam, OnEnableAntiSpamChanged);
	HookConVarChange(g_Cvar_MaxSpam, OnAntiSpamMaxAllowChanged);

	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
			if(!AreClientCookiesCached(i))
				OnClientCookiesCached(i);

	}

	AutoExecConfig(true, "Cargo_bot");
}

public void OnEnableAntiSpamChanged(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	g_bAntiSpam = GetConVarBool(g_Cvar_AntiSpam);

	if(g_hTimerCheckSpamming != INVALID_HANDLE)
	{
		KillTimer(g_hTimerCheckSpamming);
		g_hTimerCheckSpamming = INVALID_HANDLE;
	}

	if(g_bAntiSpam)
	{
		CreateTimer(10.0, CheckSpamming, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}
}

public void OnAntiSpamMaxAllowChanged(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	g_iMaxSpam = GetConVarInt(g_Cvar_MaxSpam);
}

public void OnCooldownChanged(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	g_fCooldown = GetConVarFloat(g_Cvar_Cooldown);
}

public void OnClientCookiesCached(int client)
{
	char g_sCookieMute[16];
	GetClientCookie(client, g_hCookieMute, g_sCookieMute, 16);

	if(g_sCookieMute[0] == '\0')
	{
		g_bMuted[client] = false;
		FormatEx(g_sCookieMute, 16, "%b", g_bMuted[client]);
		SetClientCookie(client, g_hCookieMute, g_sCookieMute);
		return;
	}

	g_bMuted[client] = view_as<bool>(StringToInt(g_sCookieMute));
	ToggleMuteCargo(client, g_bMuted[client]);
}

public void OnClientPutInServer(int client)
{
	g_fClientAllowAgain[client] = 0.0;
}

public void OnClientDisconnect(int client)
{
	g_bMuted[client] = false;
	g_fClientAllowAgain[client] = 0.0;
}

public void OnMapStart()
{
	g_iTotal = 0;

	char sConfigPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sConfigPath, sizeof(sConfigPath), "configs/cargolist.txt");

	KeyValues kv = CreateKeyValues("cargo");

	FileToKeyValues(kv, sConfigPath);
	if(KvGotoFirstSubKey(kv))
	{	
		do
		{
			KvGetSectionName(kv, g_sAudioCommand[g_iTotal], 64);
			KvGetString(kv, "path", g_sAudioPath[g_iTotal], 128);
			g_iTotal++;
		}
		while(KvGotoNextKey(kv));
	}

	delete kv;

	if(g_AudioMenu != INVALID_HANDLE)
		delete g_AudioMenu;

	g_AudioMenu = BuildAudioMenu("");

	g_iStacking = 0;

	g_bAntiSpam = g_Cvar_AntiSpam.BoolValue;

	if(g_bAntiSpam && g_hTimerCheckSpamming == INVALID_HANDLE)
		g_hTimerCheckSpamming = CreateTimer(10.0, CheckSpamming, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public void OnMapEnd()
{
	if(g_hTimerCheckSpamming != INVALID_HANDLE)
	{
		KillTimer(g_hTimerCheckSpamming);
		g_hTimerCheckSpamming = INVALID_HANDLE;
	}
}

public Action MuteCargo_Command(int client, int args)
{
	char g_sCookieMute[16];
	g_bMuted[client] = true;
	FormatEx(g_sCookieMute, 16, "%b", g_bMuted[client]);
	SetClientCookie(client, g_hCookieMute, g_sCookieMute);

	ReplyToCommand(client, " \x04[Cargo]\x01 You have Muted Cargo bot.");
	ToggleMuteCargo(client, g_bMuted[client]);

	return Plugin_Handled;
}

public Action UnmuteCargo_Command(int client, int args)
{
	char g_sCookieMute[16];
	g_bMuted[client] = false;
	FormatEx(g_sCookieMute, 16, "%b", g_bMuted[client]);
	SetClientCookie(client, g_hCookieMute, g_sCookieMute);

	ReplyToCommand(client, " \x04[Cargo]\x01 You have Unmuted Cargo bot.");
	ToggleMuteCargo(client, g_bMuted[client]);

	return Plugin_Handled;
}

void ToggleMuteCargo(int client, bool mute)
{
	ListenOverride allow;

	if(mute)
		allow = Listen_No;

	else
		allow = Listen_Yes;

	int bot = CallTheBot();
	if(bot == -1)
	{
		LogError("[Cargo] There is no GOTV Bot present in server.");
		return;
	}

	SetListenOverride(client, bot, allow);
}

public Action OnClientSay(int client, const char[] command, int argc)
{
	char sArg[64];
	GetCmdArg(1, sArg, 64);
	int index = GetAudioIndexByName(sArg);

	if(index != -1)
	{
		if(IsClientAdmin(client))
			PlayAudioToAll(client, g_sAudioPath[index]);

		else
		{
			if(IsClientInCooldown(client))
			{
				PrintToChat(client, " \x04[Cargo]\x01 You are now in cooldown, please wait for more %d seconds.", RoundToNearest(g_fClientAllowAgain[client] - GetEngineTime()));
			}

			else if(g_iAllAllowAgain < GetTime() && !IsClientInCooldown(client))
				PlayAudioToAll(client, g_sAudioPath[index]);
		}
	} 

	return Plugin_Continue;
}

public Action CheckSpamming(Handle timer)
{
	g_iMaxSpam = g_Cvar_MaxSpam.IntValue;

	if(g_iStacking >= g_iMaxSpam)
	{
		StopAllSound();
		g_iAllAllowAgain = GetTime() + 60;
		PrintToChatAll( " \x04[Cargo]\x01 Anti-Spamming has been activated, you can use sound again in %d seconds.", g_iAllAllowAgain - GetTime());
	}
	return Plugin_Continue;
}

public Action StopPlayClientSound_Command(int client, int args)
{
	if(g_AudioPlayer[client] != null && !g_AudioPlayer[client].IsFinished)
	{
		ReplyToCommand(client, " \x04[Cargo]\x01 Stop playing your sound has been successful.");
		delete g_AudioPlayer[client];
		return Plugin_Handled;
	}
	
	ReplyToCommand(client, " \x04[Cargo]\x01 There is none of your sound has been played now.");
	return Plugin_Handled;
}

public Action StopPlayAllSound_Command(int client, int args)
{
	ShowActivity2(client, " \x04[Cargo]\x01", "Has stopped all playing sound.");
	StopAllSound();
	return Plugin_Handled;
}

void StopAllSound()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(g_AudioPlayer[i] != null && !g_AudioPlayer[i].IsFinished)
			delete g_AudioPlayer[i];
	}
}

public Action ReloadCargo_Sound(int client, int args)
{
	ReplyToCommand(client, " \x04[Cargo]\x01 Reload Config has been sucessful.");
	OnMapStart();
	return Plugin_Handled;
}

public Action YoutubeCommand(int client, int args)
{
	if(args == 0)
	{
		ReplyToCommand(client, " \x04[Cargo]\x01 Usage: sm_yt <path>");
		return Plugin_Handled;
	}

	char sUrl[256];
	GetCmdArgString(sUrl, sizeof(sUrl));

	Handle request = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, sUrl);
	
	if(request == null)
	{
		ReplyToCommand(client, " \x04[Cargo]\x01 Request URL is not valid");
		return Plugin_Handled;
	}

	bool setnetwork = SteamWorks_SetHTTPRequestNetworkActivityTimeout(request, 30);
	bool setcontext = SteamWorks_SetHTTPRequestContextValue(request, client == 0 ? client : GetClientSerial(client));
	bool setcallback = SteamWorks_SetHTTPCallbacks(request, TitleReceived);
	
	if(!setnetwork || !setcontext || !setcallback)
	{
		ReplyToCommand(client, " \x04[Cargo]\x01 Error in setting request properties, Request has been cancelled.");
		CloseHandle(request);
		return Plugin_Handled;
	}
	
	bool sentrequest = SteamWorks_SendHTTPRequest(request);
	if(!sentrequest)
	{
		ReplyToCommand(client, " \x04[Cargo]\x01 Error in sending request, Request has been cancelled.");
		CloseHandle(request);
		return Plugin_Handled;
	}
	
	SteamWorks_PrioritizeHTTPRequest(request);

	if(g_iAllAllowAgain < GetTime() || IsClientAdmin(client))
		PlayAudioToAll(client, sUrl, true);

	return Plugin_Handled;
}

public int TitleReceived(Handle hRequest, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode eStatusCode, int serial)
{
	int client;
	
	if(serial == 0)
	{
		client = serial;
	}
	else if(serial > 0)
	{
		client = GetClientFromSerial(serial);
		if(client == 0)
		{
			PrintToServer("[Cargo] Client Index From Serial is not valid.");
			CloseHandle(hRequest);
			return 0;
		}
	}
	
	if(!bRequestSuccessful || bFailure)
	{
		PrintToChatAll(" \x04[Cargo]\x01 There was an error in the request");
		CloseHandle(hRequest);
		return 0;
	}
	
	if(hRequest == INVALID_HANDLE)
	{
		PrintToChatAll(" \x04[Cargo]\x01 The requested URL handle is invalid.");
		return 0;
	}

	int bodysize;
	bool bodyexists = SteamWorks_GetHTTPResponseBodySize(hRequest, bodysize);
	if(!bodyexists)
	{
		PrintToChatAll(" \x04[Cargo]\x01 Could not get body response size");
		CloseHandle(hRequest);
		return 0;
	}

	char sTitle[1000000];

	bool exists = false;

	exists = SteamWorks_GetHTTPResponseBodyData(hRequest, sTitle, bodysize);
	if(exists == false)
	{
		PrintToChatAll(" \x04[Cargo]\x01 Could not get body data or body data is blank [Body size: %i]", bodysize);
		CloseHandle(hRequest);
		return 0;
	}
	
	int startPoint = -1, endPoint = -1;
	
	if((startPoint = StrContains(sTitle, "<title>", false)) == -1)
	{
		PrintToChatAll(" \x04[Cargo]\x01 Couldn't find any title.");
		CloseHandle(hRequest);
		return 0;
	}
	startPoint = startPoint+7;
	if((endPoint = StrContains(sTitle, "</title>", false)) == -1)
	{
		PrintToChatAll(" \x04[Cargo]\x01 Couldn't find any title.");
		CloseHandle(hRequest);
		return 0;
	}

	sTitle[endPoint] = '\0';

	if(StrContains(sTitle[startPoint], "YouTube", false) != -1)
		PrintToChatAll(" \x04[Cargo]\x01 \x07Youtube \x01Link: %s", sTitle[startPoint]);

	else
		PrintToChatAll(" \x04[Cargo]\x01 This link is not youtube video!");

	CloseHandle(hRequest);
	return 0;
}

public Action Cargo_Command(int client, int args)
{
	char sArg[32];
	GetCmdArg(1, sArg, 32);
	CargoMenu(client, sArg);
	return Plugin_Handled;
}

void CargoMenu(int client, const char[] filter = "")
{
	Menu menu = g_AudioMenu;

	if(filter[0])
		menu = BuildAudioMenu(filter);

	menu.SetTitle("[Cargo Bot] Sound");
	menu.Display(client, MENU_TIME_FOREVER);
	return;
}

Menu BuildAudioMenu(const char[] filter)
{
	Menu menu = new Menu(CargoMenuHandler, MENU_ACTIONS_ALL);

	for(int i = 0; i < g_iTotal; i++)
	{
		if(!filter[0] || StrContains(g_sAudioCommand[i], filter, false) != -1)
		{
			menu.AddItem(g_sAudioCommand[i], g_sAudioCommand[i]);
		}
	}
	menu.ExitButton = true;
	return menu;
}

public int CargoMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char info[64];
			menu.GetItem(param2, info, sizeof(info));

			int found = GetAudioIndexByName(info);

			if(found == -1)
			{
				PrintToChat(param1, " \x04[Cargo]\x01 Encounter error in Command index please contract Admin for fix.");
				LogError("Invalid Index has been selected in menu!");
			}

			else
			{
				if(IsClientAdmin(param1))
					PlayAudioToAll(param1, g_sAudioPath[found]);

				else
				{
					if(IsClientInCooldown(param1))
					{
						PrintToChat(param1, " \x04[Cargo]\x01 You are now in cooldown, please wait for more %d seconds.", RoundToNearest(g_fClientAllowAgain[param1] - GetEngineTime()));
					}

					else if(g_iAllAllowAgain < GetTime() && !IsClientInCooldown(param1))
						PlayAudioToAll(param1, g_sAudioPath[found]);
				}
			}

		}
		case MenuAction_End:
		{
			if(menu != g_AudioMenu)
				delete menu;
		}
	}
	return 0;
}

int GetAudioIndexByName(const char[] name)
{
	for(int i = 0; i < g_iTotal; i++)
	{
		if(StrEqual(name, g_sAudioCommand[i], false))
			return i;
	}
	return -1;
}

int CallTheBot()
{
	int client = -1;
	
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && IsClientSourceTV(i))
		{
			client = i;
			break;
		}
	}
	
	return client;
}

void PlayAudioToAll(int client, const char[] uri, bool youtube = false)
{
	char source[PLATFORM_MAX_PATH];

	if(!IsClientAdmin(client))
	{
		SetClientCooldown(client);
		g_iStacking++;
	}

	if(!youtube)
		Format(source, sizeof(source), "csgo/%s", uri);

	else
		Format(source, sizeof(source), "%s", uri);
	
	int bot = CallTheBot();
	
	if(bot == -1)
	{
		LogError("[Cargo] There is no GOTV Bot present in server.");
		return;
	}
	
	g_AudioPlayer[client] = new AudioPlayer();
	g_AudioPlayer[client].PlayAsClient(bot, source);
	
	return;
}

void SetClientCooldown(int client)
{
	g_fCooldown = g_Cvar_Cooldown.FloatValue;

	g_fClientAllowAgain[client] = GetEngineTime() + g_fCooldown;
}

bool IsClientInCooldown(int client)
{
	if(g_fClientAllowAgain[client] < GetEngineTime())
		return true;

	return false;
}

bool IsClientAdmin(int client)
{
	return CheckCommandAccess(client, "sm_admin", ADMFLAG_BAN);
}