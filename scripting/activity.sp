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

Database hDatabase;
int g_ClientTime[MAXPLAYERS + 1][2];

public void OnPluginStart()
{
	/* Load translation file */
	LoadTranslations("activity.phrases");
	
	/* Connect to the database */
	Database.Connect(OnDatabaseConnection, "activity");
	
	/* Register a new command */
	RegConsoleCmd("sm_time", Command_Activity);
	RegConsoleCmd("sm_activity", Command_Activity);
}

public void OnDatabaseConnection(Database db, const char[] error, any data)
{
	if (db)
	{
		/* Check if the driver is different than MYSQL */
		char buffer[128];
		db.Driver.GetIdentifier(buffer, sizeof(buffer));
		
		if (!StrEqual(buffer, "mysql", false))
		{
			LogError("This plugin allows only MYSQL connections.");
			SetFailState("Could not connect to the database.");
		}
		
		/* Save the database handle, so we don't need to connect again on every query */
		hDatabase = db;
		
		/* Create the table if not exists */
		db.Query(OnFastQuery, "CREATE TABLE IF NOT EXISTS players_activity_table (steamid INT UNSIGNED, date DATE, seconds INT UNSIGNED, PRIMARY KEY (steamid, date));");
	}
	else
	{
		/* If there's no connection, unload this plugin */
		LogError("Could not connect to the database: %s", error);
		SetFailState("Could not connect to the database.");
	}
}

public void OnMapStart()
{
	if (hDatabase)
	{
		/* Merge players data older than 2 weeks */
		Transaction data = new Transaction();
		
		data.AddQuery("CREATE TEMPORARY TABLE players_activity_table_temp SELECT steamid, min(date), sum(seconds) FROM players_activity_table WHERE date < CURRENT_DATE - INTERVAL 2 WEEK GROUP BY steamid;");
		data.AddQuery("DELETE FROM players_activity_table WHERE date < CURRENT_DATE - INTERVAL 2 WEEK;");
		data.AddQuery("INSERT INTO players_activity_table SELECT * FROM players_activity_table_temp;");
		data.AddQuery("DROP TABLE players_activity_table_temp;");
		
		hDatabase.Execute(data);
	}
}

public void OnClientConnected(int client)
{
	/* Initialise player's data */
	g_ClientTime[client][0] = 0;
	g_ClientTime[client][1] = 0;
}

public void OnClientPostAdminCheck(int client)
{
	int steamId = GetSteamAccountID(client);
	
	if (steamId)
	{
		/* Select player's time from database */
		char query[256];
		
		Format(query, sizeof(query), "SELECT sum(CASE WHEN date >= CURRENT_DATE - INTERVAL 2 WEEK THEN seconds END), sum(seconds) FROM players_activity_table WHERE steamid = %d;", steamId);  
		hDatabase.Query(OnGetClientTime, query, GetClientUserId(client));
	}
}

public void OnGetClientTime(Database db, DBResultSet rs, const char[] error, any data)
{
	if (rs)
	{
		int client = GetClientOfUserId(view_as<int>(data));

		if (client)
		{			
			if (rs.FetchRow())
			{
				/* Fetch database result */
				g_ClientTime[client][0] = rs.FetchInt(0);
				g_ClientTime[client][1] = rs.FetchInt(1);
			}
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
		hDatabase.Query(OnFastQuery, query);
	}
}

public Action Command_Activity(int client, int args)
{
	if (client)
	{
		SetGlobalTransTarget(client);
				
		char buffer[128];
		Panel panel = new Panel();
		int mapTime = GetClientMapTime(client);

		Format(buffer, sizeof(buffer), "%t", "Activity Title");
		panel.SetTitle(buffer);

		Format(buffer, sizeof(buffer), "%t", "Activity Recent", (g_ClientTime[client][0] + mapTime) / 3600);
		panel.DrawText(buffer);
		
		Format(buffer, sizeof(buffer), "%t", "Activity Total", (g_ClientTime[client][1] + mapTime) / 3600);
		panel.DrawText(buffer);
		
		panel.DrawItem("", ITEMDRAW_SPACER);
		panel.CurrentKey = GetMaxPageItems(panel.Style);
		panel.DrawItem("Exit", ITEMDRAW_CONTROL);

		panel.Send(client, Panel_DoNothing, MENU_TIME_FOREVER);
		delete panel;
	}	
	
	return Plugin_Handled;
}

public int Panel_DoNothing(Menu menu, MenuAction action, int param1, int param2) {}

public void OnFastQuery(Database db, DBResultSet rs, const char[] error, any data)
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
