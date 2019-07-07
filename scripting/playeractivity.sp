#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

public Plugin myinfo =
{
    name = "Players Activity",
    author = "Ilusion9",
    description = "Informations of player's activity",
    version = "2.5",
    url = "https://github.com/Ilusion9/"
};

Database hDatabase;

public void OnPluginStart()
{
	/* Load translation file */
	LoadTranslations("playeractivity.phrases");
	
	/* Connect to the database */
	Database.Connect(OnDatabaseConnection, "activity");
	
	/* Register a new command */
	RegConsoleCmd("sm_activity", Command_Time);
}

public void OnMapStart()
{
	if (hDatabase)
	{
		/* Merge player's data older than 2 weeks */
		Transaction data = new Transaction();
		
		data.AddQuery("CREATE TEMPORARY TABLE players_activity_table_temp SELECT steamid, min(date), sum(seconds) FROM players_activity_table WHERE date < CURRENT_DATE - INTERVAL 2 WEEK GROUP BY steamid;");
		data.AddQuery("DELETE FROM players_activity_table WHERE date < CURRENT_DATE - INTERVAL 2 WEEK;");
		data.AddQuery("INSERT INTO players_activity_table SELECT * FROM players_activity_table_temp;");
		data.AddQuery("DROP TABLE players_activity_table_temp;");
		
		hDatabase.Execute(data);
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

public Action Command_Time(int client, int args)
{
	if (client)
	{
		int steamId = GetSteamAccountID(client);
		
		if (steamId)
		{
			/* Select player's time from database */
			char query[256];
			
			Format(query, sizeof(query), "SELECT sum(CASE WHEN date >= CURRENT_DATE - INTERVAL 2 WEEK THEN seconds END), sum(seconds), min(date) FROM players_activity_table WHERE steamid = %d;", steamId);  
			hDatabase.Query(OnGetClientTime, query, GetClientUserId(client));
		}
	}	
	
	return Plugin_Handled;
}

public void OnDatabaseConnection(Database db, const char[] error, any data)
{
	if (db)
	{
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

public void OnGetClientTime(Database db, DBResultSet rs, const char[] error, any data)
{
	if (rs)
	{
		int client = GetClientOfUserId(view_as<int>(data));

		if (client)
		{
			/* Get the session time */
			int sessionTime = RoundToZero(GetClientTime(client) / 60);
			
			int pastTime = GetClientMapTime(client);
			int recordTime = pastTime;
			char date[65];
			
			if (rs.FetchRow())
			{
				/* Get the past 2 weeks time */
				pastTime += rs.FetchInt(0);
				
				/* Get the total time */
				recordTime += rs.FetchInt(1);
				
				/* Get the first connection date */
				rs.FetchString(2, date, sizeof(date));
			}
			else
			{
				/* If we cannot find the player into database, then today will be his first connection date */
				FormatTime(date, sizeof(date), "%Y-%m-%d");
			}
			
			/* Display messages from translation file according to the language of the client */
			SetGlobalTransTarget(client);
			
			char row[128];
			Panel panel = new Panel();
			
			Format(row, sizeof(row), "%t", "time_activity");
			panel.SetTitle(row);
			
			Format(row, sizeof(row), "%t", "time_first_seen", date);
			panel.DrawText(row);
			
			Format(row, sizeof(row), "%t", "time_current_session", sessionTime);
			panel.DrawText(row);
			
			Format(row, sizeof(row), "%t", "time_past_weeks", pastTime / 3600);
			panel.DrawText(row);
			
			Format(row, sizeof(row), "%t", "time_on_record", recordTime / 3600);
			panel.DrawText(row);
			
			/* Set the current key to 9 */
			panel.DrawItem("", ITEMDRAW_SPACER);
			panel.CurrentKey = GetMaxPageItems(panel.Style);
			
			/* Display the "Exit" key */
			Format(row, sizeof(row), "%t", "time_panel_exit");
			panel.DrawItem(row, ITEMDRAW_CONTROL);
			
			panel.Send(client, Panel_DoNothing, MENU_TIME_FOREVER);
			delete panel;
		}
	}
	else
	{
		LogError("Failed to query database: %s", error);
	}
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
