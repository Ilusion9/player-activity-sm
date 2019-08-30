#if defined _activity_included
 #endinput
#endif
#define _activity_included

/**
 * Called when the client's time is fetched from database
 * 
 * @param	client		Client's index
 * @param	recentTime	Client's recent time in seconds (past two weeks)
 * @param	totalTime	Client's total time in seconds
 */
forward void Activity_OnFetchClientTime(int client, int recentTime, int totalTime);

/**
 * Returns the client's recent time (past two weeks)
 *
 * @param client		Client's index
 * @param recentTime		Client's recent time in seconds (past two weeks)
 * @return			True if the client's time was fetched from database
 */
native bool Activity_GetClientRecentTime(int client, int &recentTime);

/**
 * Returns the client's total time
 *
 * @param client		Client's index
 * @param totalTime		Client's total time in seconds
 * @return			True if the client's time was fetched from database
 */
native bool Activity_GetClientTotalTime(int client, int &totalTime);

public SharedPlugin __pl_activity = 
{
	name = "activity",
	file = "activity.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_activity_SetNTVOptional()
{
	MarkNativeAsOptional("Activity_GetClientRecentTime");
	MarkNativeAsOptional("Activity_GetClientTotalTime");
}
#endif
