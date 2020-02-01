# Description
This plugin will display informations about the players activity on the server.

# Alliedmods
https://forums.alliedmods.net/showthread.php?p=2625964

# Database configuration
```
"playeractivity" 
{ 
    "driver"            "mysql" // only mysql
    "host"                "" 
    "database"            "" 
    "user"                "" 
    "pass"                "" 
    //"timeout"            "0" 
    //"port"            "0" 
} 
```

# Commands
```
sm_activity - show the player's activity on the server
sm_activityof <steamid> - show this steamid's activity on the server
sm_activitypurge - delete all players activity
```

# Example of output
```
Activity
22 hours - past month
335 hours - total
```

# Forwards and natives
https://github.com/Ilusion9/sm-player-activity/wiki/Forwards-and-natives
