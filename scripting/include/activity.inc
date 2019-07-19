#if defined _activity_included
 #endinput
#endif
#define _activity_included

/**
 * Called when the database returns the client's time (on connecting).
 * 
 * @param	client		Client index
 * @param	recentTime	Client recent time (past two weeks)
 * @param	totalTime	Client total time
 */
 forward void Activity_OnGetClientTime(int client, int recentTime, int totalTime);

/**
 * Returns the client's recent time (past two weeks).
 *
 * @param client		Client index.
 * @return				True if the database fetched client's data.
 */
native bool Activity_GetClientRecentTime(int client);

/**
 * Returns the client's total time.
 *
 * @param client		Client index.
 * @return				True if the database fetched client's data.
 */
native bool Activity_GetClientTotalTime(int client);

/* DO NOT EDIT BELOW THIS LINE */

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
