#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

public Plugin myinfo =
{
    name = "Players Activity",
    author = "Ilusion9",
    description = "Informations of players activity",
    version = "2.5",
    url = "https://forums.alliedmods.net/"
};

Database hDatabase;

public void OnPluginStart()
{
	LoadTranslations("playeractivity.phrases");
	Database.Connect(OnDatabaseConnection, "playeractivity");
	
	RegConsoleCmd("sm_time", Command_Time);
	RegConsoleCmd("sm_activity", Command_Time);
}

public void OnMapStart()
{
	if (hDatabase)
	{
		Transaction data = new Transaction();
		
		data.AddQuery("CREATE TEMPORARY TABLE `activity_table_temp` SELECT steamid, min(date), sum(seconds) FROM `activity_table` WHERE date < CURRENT_DATE - INTERVAL 2 WEEK GROUP BY steamid;");
		data.AddQuery("DELETE FROM `activity_table` WHERE date < CURRENT_DATE - INTERVAL 2 WEEK;");
		data.AddQuery("INSERT INTO `activity_table` SELECT * FROM `activity_table_temp`;");
		data.AddQuery("DROP TABLE `activity_table_temp`;");
		
		hDatabase.Execute(data);
	}
}

public void OnClientDisconnect(int client)
{
	int steamId = GetSteamAccountID(client);
	
	if (steamId)
	{		
		char query[256];
		
		Format(query, sizeof(query), "INSERT INTO `activity_table` (steamid, date, seconds) VALUES (%d, CURRENT_DATE, %d) ON DUPLICATE KEY UPDATE seconds = seconds + VALUES(seconds);", steamId, GetClientMapTime(client));
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
			char query[256];
			
			Format(query, sizeof(query), "SELECT sum(CASE WHEN date >= CURRENT_DATE - INTERVAL 2 WEEK THEN seconds END), sum(seconds) FROM `activity_table` WHERE steamid = %d;", steamId);  
			hDatabase.Query(OnGetClientTime, query, GetClientUserId(client));
		}
	}	
	
	return Plugin_Handled;
}

public void OnDatabaseConnection(Database db, const char[] error, any data)
{
	if (db)
	{
		hDatabase = db;
	
		db.Query(OnFastQuery, "CREATE TABLE IF NOT EXISTS `activity_table` (steamid INT UNSIGNED, date DATE, seconds INT UNSIGNED, PRIMARY KEY (steamid, date));");
	}
	else
	{
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
			int sessionTime = RoundToZero(GetClientTime(client) / 60);
			int pastTime = GetClientMapTime(client);
			int recordTime = pastTime;

			if (rs.FetchRow())
			{
				pastTime += rs.FetchInt(0);
				recordTime += rs.FetchInt(1);
			}
			
			SetGlobalTransTarget(client);
			
			char row[128];
			Panel panel = new Panel();
			
			Format(row, sizeof(row), "%t", "activity_table");
			panel.SetTitle(row);

			Format(row, sizeof(row), "%t", "time_current_session", sessionTime);
			panel.DrawText(row);
			
			Format(row, sizeof(row), "%t", "time_past_weeks", pastTime / 3600);
			panel.DrawText(row);
			
			Format(row, sizeof(row), "%t", "time_on_record", recordTime / 3600);
			panel.DrawText(row);
			
			panel.DrawItem("", ITEMDRAW_SPACER);
			panel.CurrentKey = GetMaxPageItems(panel.Style);
			
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