#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

public Plugin myinfo =
{
    name = "Players Activity",
    author = "Ilusion9",
    description = "Informations of players activity",
    version = "2.5",
    url = "https://github.com/Ilusion9/"
};

Database g_Database;
Handle g_Forward_ClientTime;

bool g_HasTimeFetched[MAXPLAYERS + 1];

int g_RecentTime[MAXPLAYERS + 1];
int g_TotalTime[MAXPLAYERS + 1];

public APLRes AskPluginLoad2(Handle myself, bool late, char [] error, int err_max)
{
	CreateNative("Activity_GetClientRecentTime", Native_GetClientRecentTime);
	CreateNative("Activity_GetClientTotalTime", Native_GetClientTotalTime);
	
	RegPluginLibrary("playeractivity");
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("playeractivity.phrases");
	
	Database.Connect(Database_OnConnect, "playeractivity");
	
	RegConsoleCmd("sm_activity", Command_ShowActivity);
	RegConsoleCmd("sm_time", Command_ShowActivity);

	for (int i = 1; i <= MaxClients; i++)
	{
		OnClientConnected(i);
		
		if (IsClientInGame(i)) {
			OnClientPostAdminCheck(i);
		}
	}
	
	g_Forward_ClientTime = CreateGlobalForward("Activity_OnFetchClientTime", ET_Event, Param_Cell, Param_Cell, Param_Cell);
}

public void Database_OnConnect(Database db, const char[] error, any data)
{
	if (!db)
	{
		LogError("Could not connect to the database: %s", error);
		SetFailState("Could not connect to the database.");
	}
	
	char buffer[64];
	db.Driver.GetIdentifier(buffer, sizeof(buffer));
	
	if (!StrEqual(buffer, "mysql", false))
	{
		LogError("Could not connect to the database: expected mysql database.");
		SetFailState("Could not connect to the database.");
	}
		
	g_Database = db;
	db.Query(Database_FastQuery, "CREATE TABLE IF NOT EXISTS players_activity (steamid INT UNSIGNED, date DATE, seconds INT UNSIGNED, PRIMARY KEY (steamid, date));");
}

public void OnMapEnd()
{
	/* Merge players data older than 2 weeks */
	Transaction data = new Transaction();
	
	data.AddQuery("CREATE TEMPORARY TABLE players_activity_temp SELECT steamid, min(date), sum(seconds) FROM players_activity WHERE date < CURRENT_DATE - INTERVAL 2 WEEK GROUP BY steamid;");
	data.AddQuery("DELETE FROM players_activity WHERE date < CURRENT_DATE - INTERVAL 2 WEEK;");
	data.AddQuery("INSERT INTO players_activity SELECT * FROM players_activity_temp;");
	data.AddQuery("DROP TABLE players_activity_temp;");
	
	g_Database.Execute(data);
}

public void OnClientConnected(int client)
{
	g_HasTimeFetched[client] = false;
	
	g_RecentTime[client] = 0;
	g_TotalTime[client] = 0;
}

public void OnClientPostAdminCheck(int client)
{
	int steamId = GetSteamAccountID(client);
	
	if (steamId)
	{
		char query[256];
		Format(query, sizeof(query), "SELECT sum(CASE WHEN date >= CURRENT_DATE - INTERVAL 2 WEEK THEN seconds END), sum(seconds) FROM players_activity WHERE steamid = %d;", steamId);  
		g_Database.Query(Database_GetClientTime, query, GetClientUserId(client));
	}
}

public void Database_GetClientTime(Database db, DBResultSet rs, const char[] error, any data)
{
	if (!rs)
	{
		LogError("Failed to query database: %s", error);
		return;
	}
		
	int client = GetClientOfUserId(view_as<int>(data));

	if (client)
	{		
		if (rs.FetchRow())
		{
			g_RecentTime[client] = rs.FetchInt(0);
			g_TotalTime[client] = rs.FetchInt(1);
		}
		
		g_HasTimeFetched[client] = true;
				
		Call_StartForward(g_Forward_ClientTime);
		Call_PushCell(client);
		Call_PushCell(g_RecentTime[client]);
		Call_PushCell(g_TotalTime[client]);
		Call_Finish();
	}
}

public void OnClientDisconnect(int client)
{
	int steamId = GetSteamAccountID(client);
	
	if (steamId)
	{		
		char query[256];
		Format(query, sizeof(query), "INSERT INTO players_activity (steamid, date, seconds) VALUES (%d, CURRENT_DATE, %d) ON DUPLICATE KEY UPDATE seconds = seconds + VALUES(seconds);", steamId, GetClientMapTime(client));
		g_Database.Query(Database_FastQuery, query);
	}
}

public Action Command_ShowActivity(int client, int args)
{
	if (!client)
	{
		ReplyToCommand(client, "[SM] %t", "Command is in-game only");
		return Plugin_Handled;
	}
	
	if (!g_HasTimeFetched[client])
	{
		ReplyToCommand(client, "[SM] %t", "Activity Unavailable");
		return Plugin_Handled;
	}
	
	SetGlobalTransTarget(client);
			
	char buffer[128];
	Panel panel = new Panel();
	int mapTime = GetClientMapTime(client);

	Format(buffer, sizeof(buffer), "%t", "Activity Title");
	panel.SetTitle(buffer);

	Format(buffer, sizeof(buffer), "%t", "Activity Recent", float(g_RecentTime[client] + mapTime) / 3600);
	panel.DrawText(buffer);
	
	Format(buffer, sizeof(buffer), "%t", "Activity Total", (g_TotalTime[client] + mapTime) / 3600);
	panel.DrawText(buffer);
	
	panel.DrawItem("", ITEMDRAW_SPACER);
	panel.CurrentKey = GetMaxPageItems(panel.Style);
	panel.DrawItem("Exit", ITEMDRAW_CONTROL);

	panel.Send(client, Panel_DoNothing, MENU_TIME_FOREVER);
	delete panel;
	
	return Plugin_Handled;
}

public int Panel_DoNothing(Menu menu, MenuAction action, int param1, int param2) {}

public void Database_FastQuery(Database db, DBResultSet rs, const char[] error, any data)
{
	if (!rs) {	
		LogError("Failed to query database: %s", error);
	}
}

int GetClientMapTime(int client)
{
	float clientTime = GetClientTime(client), gameTime = GetGameTime();
	
	if (clientTime > gameTime) {
		return RoundToZero(gameTime);
	}
	
	return RoundToZero(clientTime);
}

/* Native handler for bool Activity_GetClientRecentTime(int client, int &recentTime) */
public int Native_GetClientRecentTime(Handle hPlugin, int numParams)
{
	int client = GetNativeCell(1);
	
	if (client < 1 || client > MaxClients) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %d", client);
	}
	
	if (!IsClientInGame(client)) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Client %d is not in game", client);
	}
	
	SetNativeCellRef(2, g_RecentTime[client] + GetClientMapTime(client));
	return g_HasTimeFetched[client];
}

/* Native handler for bool Activity_GetClientTotalTime(int client, int &totalTime) */
public int Native_GetClientTotalTime(Handle hPlugin, int numParams)
{
	int client = GetNativeCell(1);
	
	if (client < 1 || client > MaxClients) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %d", client);
	}
	
	if (!IsClientInGame(client)) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Client %d is not in game", client);
	}

	SetNativeCellRef(2, g_TotalTime[client] + GetClientMapTime(client));
	return g_HasTimeFetched[client];
}
