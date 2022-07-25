#pragma semicolon 1

#include <sourcemod>
#include <clientprefs>
#include <audio>

#pragma newdecls required

char g_AudioCommand[512][64];
char g_AudioPath[512][PLATFORM_MAX_PATH];

Handle g_hCookieMute = INVALID_HANDLE;
bool g_bMuted[MAXPLAYERS+1];

Menu g_AudioMenu;

KeyValues kv;

int iTotal;

public Plugin myinfo = 
{
	name = "Cargo Bot",
	author = "Oylsister",
	description = "Relative to Sympho bot",
	version = "1.0",
	url = ""
}

public void OnPluginStart()
{
	RegConsoleCmd("sm_cargo", Cargo_Command);
	RegAdminCmd("sm_reloadcargo", ReloadCargo_Sound, ADMFLAG_CONFIG);
}

public void OnMapStart()
{
	iTotal = 0;

	char sConfigPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sConfigPath, sizeof(sConfigPath), "configs/cargolist.txt");

	kv = CreateKeyValues("cargo");

	FileToKeyValues(kv, sConfigPath);
	if(KvGotoFirstSubKey(kv))
	{	
		do
		{
			KvGetSectionName(kv, g_AudioCommand[iTotal], 64);
			KvGetString(kv, "path", g_AudioPath[iTotal], 128);
			iTotal++;
		}
		while(KvGotoNextKey(kv));
	}

	delete kv;
}

public void OnClientCookiesCached(int client)
{
	char g_sCookieMute[16];
	GetClientCookie(client, g_hCookieMute, g_sCookieMute, 16);

	if(g_sCookieMute[0] == '\0')
	{
		g_bMuted[client] = false;
		return;
	}

	g_bMuted[client] = true;
	FormatEx(g_sCookieMute, 16, "%b", g_bMuted[client]);
	SetClientCookie(client, g_hCookieMute, g_sCookieMute);
}

public Action ReloadCargo_Sound(int client, int args)
{
	ReplyToCommand(client, " \x04[Cargo]\x01 Reload Config has been sucessful.");
	OnMapStart();
	return Plugin_Handled;
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

	menu.SetTitle("[Cargo Bot] Sound");
	if(filter[0])
		menu = BuildAudioMenu(filter);

	menu.Display(client, MENU_TIME_FOREVER);
	return;
}

Menu BuildAudioMenu(const char[] filter)
{
	Menu menu = new Menu(CargoMenuHandler, MENU_ACTIONS_ALL);

	for(int i = 0; i < iTotal; i++)
	{
		if(!filter[0] || StrContains(g_AudioCommand[i], filter, false) != -1)
		{
			menu.AddItem(g_AudioCommand[i], g_AudioCommand[i]);
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
				EmitPlaySound(g_AudioPath[found]);
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
	for(int i = 0; i < iTotal; i++)
	{
		if(StrEqual(name, g_AudioCommand[i], false))
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

void EmitPlaySound(const char[] uri)
{
	char source[PLATFORM_MAX_PATH];
	Format(source, sizeof(source), "csgo/%s", uri);
	
	int bot = CallTheBot();
	
	AudioPlayer g_iBot = new AudioPlayer();
	g_iBot.PlayAsClient(bot, source);
	
	return;
}