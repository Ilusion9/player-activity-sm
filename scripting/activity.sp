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

enum TimeColumns {
	Recent = 0,
	Total
};

Database hDatabase;
Handle gF_OnGetClientTime;

bool g_FetchedData[MAXPLAYERS + 1];
int g_ClientTime[MAXPLAYERS + 1][TimeColumns];

public void OnPluginStart()
{
	/* Load translation file */
	LoadTranslations("activity.phrases");
	
	/* Connect to the database */
	Database.Connect(Database_OnConnect, "activity");
	
	/* Register a new command */
	RegConsoleCmd("sm_time", Command_Activity);
	RegConsoleCmd("sm_activity", Command_Activity);
	
	/* If there are connected players (on plugin load) then retrieve their data */
	for (int i = 1; i <= MaxClients; i++)
	{
		OnClientConnected(i);

		if (IsClientInGame(i))
		{
			OnClientPostAdminCheck(i);
		}
	}
}

public void Database_OnConnect(Database db, const char[] error, any data)
{
	if (db)
	{
		/* Check if the driver is different than MYSQL */
		char buffer[128];
		db.Driver.GetIdentifier(buffer, sizeof(buffer));
		
		if (!StrEqual(buffer, "mysql", false))
		{
			LogError("Could not connect to the database: expected mysql database.");
			SetFailState("Could not connect to the database.");
		}
		
		/* Save the database handle, so we don't need to connect again on every query */
		hDatabase = db;
		
		/* Create the table if not exists */
		db.Query(Database_FastQuery, "CREATE TABLE IF NOT EXISTS players_activity_table (steamid INT UNSIGNED, date DATE, seconds INT UNSIGNED, PRIMARY KEY (steamid, date));");
	}
	else
	{
		/* If there's no connection, unload this plugin */
		LogError("Could not connect to the database: %s", error);
		SetFailState("Could not connect to the database.");
	}
}

public void OnMapEnd()
{
	/* Merge player's data older than 2 weeks */
	Transaction data = new Transaction();
	
	data.AddQuery("CREATE TEMPORARY TABLE players_activity_table_temp SELECT steamid, min(date), sum(seconds) FROM players_activity_table WHERE date < CURRENT_DATE - INTERVAL 2 WEEK GROUP BY steamid;");
	data.AddQuery("DELETE FROM players_activity_table WHERE date < CURRENT_DATE - INTERVAL 2 WEEK;");
	data.AddQuery("INSERT INTO players_activity_table SELECT * FROM players_activity_table_temp;");
	data.AddQuery("DROP TABLE players_activity_table_temp;");
	
	hDatabase.Execute(data);
}

public void OnClientConnected(int client)
{
	/* Initialise player's data */
	g_FetchedData[client] = false;
	g_ClientTime[client][Recent] = 0;
	g_ClientTime[client][Total] = 0;
}

public void OnClientPostAdminCheck(int client)
{
	int steamId = GetSteamAccountID(client);
	
	if (steamId)
	{
		/* Select player's time from database */
		char query[256];
		
		Format(query, sizeof(query), "SELECT sum(CASE WHEN date >= CURRENT_DATE - INTERVAL 2 WEEK THEN seconds END), sum(seconds) FROM players_activity_table WHERE steamid = %d;", steamId);  
		hDatabase.Query(Database_GetClientTime, query, GetClientUserId(client));
	}
}

public void Database_GetClientTime(Database db, DBResultSet rs, const char[] error, any data)
{
	if (rs)
	{
		int client = GetClientOfUserId(view_as<int>(data));

		if (client)
		{			
			if (rs.FetchRow())
			{
				/* Fetch database result */
				g_ClientTime[client][Recent] = rs.FetchInt(0);
				g_ClientTime[client][Total] = rs.FetchInt(1);
			}
			
			g_FetchedData[client] = true;
			
			Call_StartForward(gF_OnGetClientTime);
			Call_PushCell(client);
			Call_PushCell(g_ClientTime[client][Recent]);
			Call_PushCell(g_ClientTime[client][Total]);
			Call_Finish();
		}
	}
	else
	{
		LogError("Failed to query database: %s", error);
	}
}

public void OnClientDisconnect(int client)
{
	int steamId = GetSteamAccountID(client);
	
	if (steamId)
	{		
		/* Insert player's time into database */
		char query[256];
		
		Format(query, sizeof(query), "INSERT INTO players_activity_table (steamid, date, seconds) VALUES (%d, CURRENT_DATE, %d) ON DUPLICATE KEY UPDATE seconds = seconds + VALUES(seconds);", steamId, GetClientMapTime(client));
		hDatabase.Query(Database_FastQuery, query);
	}
}

public Action Command_Activity(int client, int args)
{
	if (client)
	{
		if (g_FetchedData[client])
		{
			SetGlobalTransTarget(client);
					
			char buffer[128];
			Panel panel = new Panel();
			int mapTime = GetClientMapTime(client);

			Format(buffer, sizeof(buffer), "%t", "Activity Title");
			panel.SetTitle(buffer);

			Format(buffer, sizeof(buffer), "%t", "Activity Recent", float(g_ClientTime[client][Recent] + mapTime) / 3600);
			panel.DrawText(buffer);
			
			Format(buffer, sizeof(buffer), "%t", "Activity Total", (g_ClientTime[client][Total] + mapTime) / 3600);
			panel.DrawText(buffer);
			
			panel.DrawItem("", ITEMDRAW_SPACER);
			panel.CurrentKey = GetMaxPageItems(panel.Style);
			panel.DrawItem("Exit", ITEMDRAW_CONTROL);

			panel.Send(client, Panel_DoNothing, MENU_TIME_FOREVER);
			delete panel;
		}
	}	
	
	return Plugin_Handled;
}

public int Panel_DoNothing(Menu menu, MenuAction action, int param1, int param2) {}

public void Database_FastQuery(Database db, DBResultSet rs, const char[] error, any data)
{
	if (rs)
	{
		return;
	}
	
	LogError("Failed to query database: %s", error);
}

int GetClientMapTime(int client)
{
	float clientTime = GetClientTime(client), gameTime = GetGameTime();

	if (clientTime > gameTime)
	{
		return RoundToZero(gameTime);
	}

	return RoundToZero(clientTime);
}

public APLRes AskPluginLoad2(Handle myself, bool late, char [] error, int err_max)
{
	CreateNative("Activity_GetClientRecentTime", Native_GetClientRecentTime);
	CreateNative("Activity_GetClientTotalTime", Native_GetClientTotalTime);
	gF_OnGetClientTime = CreateGlobalForward("Activity_OnGetClientTime", ET_Event, Param_Cell, Param_Cell, Param_Cell);
	
	RegPluginLibrary("activity");
	return APLRes_Success;
}

public int Native_GetClientRecentTime(Handle hPlugin, int numParams)
{
	int client = GetNativeCell(1);
	
	if (client < 1 || client > MaxClients)
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %d", client);
	}
	
	if (!IsClientInGame(client))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Client %d is not in game", client);
	}
	
	SetNativeCellRef(2, g_ClientTime[client][Recent] + GetClientMapTime(client));
	return g_FetchedData[client];
}

public int Native_GetClientTotalTime(Handle hPlugin, int numParams)
{
	int client = GetNativeCell(1);
	
	if (client < 1 || client > MaxClients)
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %d", client);
	}
	
	if (!IsClientInGame(client))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Client %d is not in game", client);
	}

	SetNativeCellRef(2, g_ClientTime[client][Total] + GetClientMapTime(client));
	return g_FetchedData[client];
}
