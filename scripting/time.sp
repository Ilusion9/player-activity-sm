#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

public Plugin myinfo =
{
    name = "Time played",
    author = "Ilusion9",
    description = "The time spent on server",
    version = "2.1",
    url = "https://forums.alliedmods.net/"
};

Database hDatabase;

public void OnPluginStart()
{
	LoadTranslations("time.phrases");
	Database.Connect(OnDatabaseConnection, "time");
	
	RegConsoleCmd("sm_time", Command_Time);
}

public void OnClientDisconnect(int client)
{
	int steamId = GetSteamAccountID(client);
	
	if (steamId)
	{		
		char query[256];
		
		Format(query, sizeof(query), "INSERT INTO time_table (steamid, seconds) VALUES (%d, %d) ON DUPLICATE KEY UPDATE seconds = seconds + VALUES(seconds);", steamId, GetClientMapTime(client));
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
			
			Format(query, sizeof(query), "SELECT seconds FROM time_table WHERE steamid = %d;", steamId);  
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
	
		db.Query(OnFastQuery, "CREATE TABLE IF NOT EXISTS time_table (steamid INT UNSIGNED PRIMARY KEY, seconds INT UNSIGNED);");
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
			if (rs.FetchRow())
			{
				PrintToChat(client, "%t", "Time played", (rs.FetchInt(0) + GetClientMapTime(client)) / 3600);
			}
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