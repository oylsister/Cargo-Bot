#pragma semicolon 1

#include <sourcemod>
#include <audio>

#pragma newdecls required

char g_AudioCommand[512][64];
char g_AudioPath[512][PLATFORM_MAX_PATH];

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
}

public void OnMapStart()
{
	int iTotal = 0;

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

public Action Cargo_Command(int client, int args)
{
	return Plugin_Handled;
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
	Format(source, sizeof(source), "csgo/addons/sourcemod/data/cargo_sound/hihi.mp3");
	
	int bot = CallTheBot();
	
	AudioPlayer g_iBot = new AudioPlayer();
	g_iBot.PlayAsClient(bot, source);
	
	return Plugin_Handled;
}