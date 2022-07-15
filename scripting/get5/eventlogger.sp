public void EventLogger_LogAndDeleteEvent(Get5Event event) {

  int options = g_PrettyPrintJsonCvar.BoolValue ? JSON_ENCODE_PRETTY : 0;
  int bufferSize = event.EncodeSize(options);

  char[] buffer = new char[bufferSize];
  event.Encode(buffer, bufferSize, options);

  char logPath[PLATFORM_MAX_PATH];
  if (FormatCvarString(g_EventLogFormatCvar, logPath, sizeof(logPath))) {
    File hLogFile = OpenFile(logPath, "a+");

    if (hLogFile) {
      LogToOpenFileEx(hLogFile, buffer);
      CloseHandle(hLogFile);
    } else {
      LogError("Could not open file \"%s\"", logPath);
    }
  }

  LogDebug("Calling Get5_OnEvent(data=%s)", buffer);

  Call_StartForward(g_OnEvent);
  Call_PushCell(event);
  Call_PushString(buffer);
  Call_Finish();

  json_cleanup_and_delete(event);

}

/*static void AddMapData(JSON_Object params) {
  char mapName[PLATFORM_MAX_PATH];
  GetCleanMapName(mapName, sizeof(mapName));
  params.SetString("map_name", mapName);
  params.SetInt("map_number", Get5_GetMapNumber());
}

static void AddTeam(JSON_Object params, const char[] key, MatchTeam team) {
  char value[16];
  GetTeamString(team, value, sizeof(value));
  params.SetString(key, value);
}

static void AddCSTeam(JSON_Object params, const char[] key, int team) {
  char value[16];
  CSTeamString(team, value, sizeof(value));
  params.SetString(key, value);
}

static void AddPlayer(JSON_Object params, const char[] key, int client) {
  char value[64];
  if (IsValidClient(client)) {
    Format(value, sizeof(value), "%L", client);
  } else {
    Format(value, sizeof(value), "none");
  }
  params.SetString(key, value);
}

static void AddIpAddress(JSON_Object params, int client) {
  char value[32];
  if (IsValidClient(client)) {
    GetClientIP(client, value, sizeof(value));
  }
  params.SetString("ip", value);
}
*/

/*public void EventLogger_SideSwap(int team1Side, int team2Side) {
  EventLogger_StartEvent();
  AddMapData(params);
  AddCSTeam(params, "team1_side", team1Side);
  AddCSTeam(params, "team2_side", team2Side);
  params.SetInt("team1_score", CS_GetTeamScore(MatchTeamToCSTeam(MatchTeam_Team1)));
  params.SetInt("team2_score", CS_GetTeamScore(MatchTeamToCSTeam(MatchTeam_Team2)));
  EventLogger_EndEvent("side_swap");
}
*/
