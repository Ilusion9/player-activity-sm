#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

public Plugin myinfo =
{
    name = "Time played",
    author = "Ilusion9",
    description = "The time spent on server",
    version = "2.2",
    url = "https://forums.alliedmods.net/"
};

Database hDatabase;

public void OnPluginStart()
{
	LoadTranslations("time.phrases");
	Database.Connect(OnDatabaseConnection, "time");
	
	RegConsoleCmd("sm_time", Command_Time);
}

public void OnMapStart()
{
	Transaction data = new Transaction();
	
	data.AddQuery("CREATE TEMPORARY TABLE hours_table_temp SELECT steamid, min(date), sum(seconds) FROM time_table WHERE date < CURRENT_DATE - INTERVAL 2 WEEK GROUP BY steamid;");
	data.AddQuery("DELETE FROM time_table WHERE date < CURRENT_DATE - INTERVAL 2 WEEK;");
	data.AddQuery("INSERT INTO time_table SELECT * FROM hours_table_temp;");
	data.AddQuery("DROP TABLE hours_table_temp;");
	
	hDatabase.Execute(data);
}

public void OnClientDisconnect(int client)
{
	int steamId = GetSteamAccountID(client);
	
	if (steamId)
	{		
		char query[256];
		
		Format(query, sizeof(query), "INSERT INTO time_table (steamid, date, seconds) VALUES (%d, CURRENT_DATE, %d) ON DUPLICATE KEY UPDATE seconds = seconds + VALUES(seconds);", steamId, GetClientMapTime(client));
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
			
			Format(query, sizeof(query), "SELECT sum(CASE WHEN date >= CURRENT_DATE - INTERVAL 2 WEEK THEN seconds END), sum(seconds) FROM time_table WHERE steamid = %d;", steamId);  
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
	
		db.Query(OnFastQuery, "CREATE TABLE IF NOT EXISTS time_table (steamid INT UNSIGNED, date DATE, seconds INT UNSIGNED, PRIMARY KEY (steamid, date));");
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
			int pastTime = GetClientMapTime(client), recordTime = pastTime;

			if (rs.FetchRow())
			{
				pastTime += rs.FetchInt(0);
				recordTime += rs.FetchInt(1);
			}
			
			PrintToChat(client, "%t", "Past Weeks", pastTime / 3600);
			PrintToChat(client, "%t", "On Record", recordTime / 3600);
		}
	}
	else
	{
		LogError("Failed to query database: %s", error);
	}
}

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
