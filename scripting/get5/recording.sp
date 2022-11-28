bool StartRecording() {
  char demoFormat[PLATFORM_MAX_PATH];
  g_DemoNameFormatCvar.GetString(demoFormat, sizeof(demoFormat));
  if (StrEqual("", demoFormat)) {
    LogMessage("Demo recording is disabled via get5_demo_name_format.");
    return false;
  }

  if (!IsTVEnabled()) {
    LogError("Demo recording will not work with \"tv_enable 0\". Set \"tv_enable 1\" and restart the map to fix this.");
    g_DemoFileName = "";
    return false;
  }

  char demoName[PLATFORM_MAX_PATH + 1];

  if (!FormatCvarString(g_DemoNameFormatCvar, demoName, sizeof(demoName))) {
    LogError("Failed to format demo filename. Please check your demo file format convar.");
    g_DemoFileName = "";
    return false;
  }

  char demoFolder[PLATFORM_MAX_PATH];
  char variableSubstitutes[][] = {"{MATCHID}", "{DATE}"};
  CheckAndCreateFolderPath(g_DemoPathCvar, variableSubstitutes, 2, demoFolder, sizeof(demoFolder));

  char demoPath[PLATFORM_MAX_PATH];
  FormatEx(demoPath, sizeof(demoPath), "%s%s", demoFolder, demoName);
  FormatEx(g_DemoFileName, sizeof(g_DemoFileName), "%s%s.dem", demoFolder, demoName);
  LogMessage("Recording to %s", g_DemoFileName);

  // Escape unsafe characters and start recording. .dem is appended to the filename automatically.
  ReplaceString(demoPath, sizeof(demoPath), "\"", "\\\"");
  ServerCommand("tv_record \"%s\"", demoPath);
  Stats_SetDemoName(g_DemoFileName);
  return true;
}

void StopRecording(float delay = 0.0) {
  if (StrEqual("", g_DemoFileName)) {
    LogDebug("Demo was not recorded by Get5; not firing Get5_OnDemoFinished() or stopping recording.");
    return;
  }
  char uploadUrl[1024];
  g_DemoUploadURLCvar.GetString(uploadUrl, sizeof(uploadUrl));
  char uploadUrlHeaderKey[1024];
  g_DemoUploadHeaderKeyCvar.GetString(uploadUrlHeaderKey, sizeof(uploadUrlHeaderKey));
  char uploadUrlHeaderValue[1024];
  g_DemoUploadHeaderValueCvar.GetString(uploadUrlHeaderValue, sizeof(uploadUrlHeaderValue));
  DataPack pack = GetDemoInfoDataPack(g_MatchID, g_MapNumber, g_DemoFileName, uploadUrl, uploadUrlHeaderKey,
                                      uploadUrlHeaderValue, g_DemoUploadDeleteAfterCvar.BoolValue);
  if (delay < 0.1) {
    LogDebug("Stopping GOTV recording immediately.");
    StopRecordingCallback(pack);
  } else {
    LogDebug("Starting timer that will end GOTV recording in %f seconds.", delay);
    CreateTimer(delay, Timer_StopGoTVRecording, pack);
  }
  g_DemoFileName = "";
}

static Action Timer_StopGoTVRecording(Handle timer, DataPack pack) {
  StopRecordingCallback(pack);
  return Plugin_Handled;
}

static void StopRecordingCallback(DataPack pack) {
  ServerCommand("tv_stoprecord");
  // We delay this by 15 seconds to allow the server to flush to the file before firing the event.
  // For some servers, this take a pretty long time (up to 8-9 seconds, so 15 for grace).
  CreateTimer(15.0, Timer_FireStopRecordingEvent, pack);
}

static Action Timer_FireStopRecordingEvent(Handle timer, DataPack pack) {
  char matchId[MATCH_ID_LENGTH];
  char demoFileName[PLATFORM_MAX_PATH];
  int mapNumber;
  char uploadUrl[1024];
  char uploadUrlHeaderKey[1024];
  char uploadUrlHeaderValue[1024];
  bool deleteAfterUpload;
  ReadDemoDataPack(pack, matchId, sizeof(matchId), mapNumber, uploadUrl, sizeof(uploadUrl), uploadUrlHeaderKey,
                   sizeof(uploadUrlHeaderKey), uploadUrlHeaderValue, sizeof(uploadUrlHeaderValue), demoFileName,
                   sizeof(demoFileName), deleteAfterUpload);
  delete pack;

  Get5DemoFinishedEvent event = new Get5DemoFinishedEvent(matchId, mapNumber, demoFileName);
  LogDebug("Calling Get5_OnDemoFinished()");
  Call_StartForward(g_OnDemoFinished);
  Call_PushCell(event);
  Call_Finish();
  EventLogger_LogAndDeleteEvent(event);

  UploadDemoToServer(demoFileName, matchId, mapNumber, uploadUrl, uploadUrlHeaderKey, uploadUrlHeaderValue,
                     deleteAfterUpload);
  return Plugin_Handled;
}

static DataPack GetDemoInfoDataPack(const char[] matchId, const int mapNumber, const char[] demoFileName,
                                    const char[] uploadUrl, const char[] uploadHeaderKey,
                                    const char[] uploadHeaderValue, const bool deleteAfterUpload) {
  DataPack pack = CreateDataPack();
  pack.WriteString(matchId);
  pack.WriteCell(mapNumber);
  pack.WriteString(demoFileName);
  pack.WriteString(uploadUrl);
  pack.WriteString(uploadHeaderKey);
  pack.WriteString(uploadHeaderValue);
  pack.WriteCell(deleteAfterUpload);
  return pack;
}

static void ReadDemoDataPack(DataPack pack, char[] matchId, const int matchIdLength, int &mapNumber, char[] uploadUrl,
                             const int uploadUrlLength, char[] uploadHeaderKey, const int uploadHeaderKeyLength,
                             char[] uploadeHeaderValue, const int uploadHeaderValueLength, char[] demoFileName,
                             const int demoFileNameLength, bool &deleteAfterUpload) {
  pack.Reset();
  pack.ReadString(matchId, matchIdLength);
  mapNumber = pack.ReadCell();
  pack.ReadString(demoFileName, demoFileNameLength);
  pack.ReadString(uploadUrl, uploadUrlLength);
  pack.ReadString(uploadHeaderKey, uploadHeaderKeyLength);
  pack.ReadString(uploadeHeaderValue, uploadHeaderValueLength);
  deleteAfterUpload = pack.ReadCell();
}

static void UploadDemoToServer(const char[] demoFileName, const char[] matchId, int mapNumber, const char[] demoUrl,
                               const char[] demoHeaderKey, const char[] demoHeaderValue, const bool deleteAfterUpload) {

  if (StrEqual(demoUrl, "")) {
    LogDebug("Skipping demo upload as upload URL is not set.");
    return;
  }

  if (!LibraryExists("SteamWorks")) {
    LogError(
      "Get5 cannot upload demos to a web server without the SteamWorks extension. Set get5_demo_upload_url to an empty string to remove this message.");
    return;
  }

  Handle demoRequest = CreateGet5HTTPRequest(k_EHTTPMethodPOST, demoUrl);
  if (demoRequest == INVALID_HANDLE) {
    CallUploadEvent(matchId, mapNumber, demoFileName, false);
    return;
  }

  // Set the auth keys only if they are defined. If not, we can still technically POST
  // to an end point that has no authentication.
  if (!StrEqual(demoHeaderKey, "") && !StrEqual(demoHeaderValue, "")) {
    if (!SteamWorks_SetHTTPRequestHeaderValue(demoRequest, demoHeaderKey, demoHeaderValue)) {
      LogError("Failed to add custom header '%s' with value '%s' to demo upload request.", demoHeaderKey,
               demoHeaderValue);
      delete demoRequest;
      CallUploadEvent(matchId, mapNumber, demoFileName, false);
      return;
    }
  }

  if (!SteamWorks_SetHTTPRequestHeaderValue(demoRequest, GET5_HEADER_DEMONAME, demoFileName)) {
    LogError("Failed to add filename header with value '%s' to demo upload request.", demoFileName);
    delete demoRequest;
    CallUploadEvent(matchId, mapNumber, demoFileName, false);
    return;
  }

  if (strlen(matchId) > 0) {
    if (!SteamWorks_SetHTTPRequestHeaderValue(demoRequest, GET5_HEADER_MATCHID, matchId)) {
      LogError("Failed to add match ID header with value '%s' to demo upload request.", matchId);
      delete demoRequest;
      CallUploadEvent(matchId, mapNumber, demoFileName, false);
      return;
    }
  }

  char strMapNumber[5];
  IntToString(mapNumber, strMapNumber, sizeof(strMapNumber));
  if (!SteamWorks_SetHTTPRequestHeaderValue(demoRequest, GET5_HEADER_MAPNUMBER, strMapNumber)) {
    LogError("Failed to add map number header with value '%s' to demo upload request.", strMapNumber);
    delete demoRequest;
    CallUploadEvent(matchId, mapNumber, demoFileName, false);
    return;
  }

  const timeout = 180;
  if (!SteamWorks_SetHTTPRequestNetworkActivityTimeout(demoRequest, timeout)) {
    LogError("Failed to change demo upload request timeout to %d seconds.", timeout);
    delete demoRequest;
    CallUploadEvent(matchId, mapNumber, demoFileName, false);
    return;
  }

  if (!FileExists(demoFileName) ||
      !SteamWorks_SetHTTPRequestRawPostBodyFromFile(demoRequest, "application/octet-stream", demoFileName)) {
    LogError("Failed to add file '%s' as POST body for demo upload request.", demoFileName);
    delete demoRequest;
    CallUploadEvent(matchId, mapNumber, demoFileName, false);
    return;
  }

  SteamWorks_SetHTTPRequestContextValue(
    demoRequest,
    GetDemoInfoDataPack(matchId, mapNumber, demoFileName, demoUrl, demoHeaderKey, demoHeaderValue, deleteAfterUpload));
  SteamWorks_SetHTTPCallbacks(demoRequest, DemoRequestCallback);
  SteamWorks_SendHTTPRequest(demoRequest);
}

static bool IsTVEnabled() {
  ConVar tvEnabledCvar = FindConVar("tv_enable");
  if (tvEnabledCvar == null) {
    LogError("Failed to get tv_enable cvar");
    return false;
  }
  if (tvEnabledCvar.BoolValue) {
    // GOTV can be enabled without the bot actually running; map restart is
    // required, so it might be disabled in edge-cases.
    LOOP_CLIENTS(i) {
      if (IsClientConnected(i) && IsClientSourceTV(i)) {
        return true;
      }
    }
  }
  return false;
}

int GetTvDelay() {
  if (IsTVEnabled()) {
    bool tvEnable1 = GetCvarIntSafe("tv_enable1") > 0;
    int tvDelay = GetCvarIntSafe("tv_delay");
    if (!tvEnable1) {
      return tvDelay;
    }
    int tvDelay1 = GetCvarIntSafe("tv_delay1");
    if (tvDelay < tvDelay1) {
      LogDebug("tv_delay1 is longer than the default tv_delay; using that.");
      return tvDelay1;
    }
    return tvDelay;
  }
  return 0;
}

float GetCurrentMatchRestartDelay() {
  ConVar mp_match_restart_delay = FindConVar("mp_match_restart_delay");
  if (mp_match_restart_delay == INVALID_HANDLE) {
    return 1.0;  // Shouldn't really be possible, but as a safeguard.
  }
  return mp_match_restart_delay.FloatValue;
}

void SetCurrentMatchRestartDelay(float delay) {
  ConVar mp_match_restart_delay = FindConVar("mp_match_restart_delay");
  if (mp_match_restart_delay != INVALID_HANDLE) {
    mp_match_restart_delay.FloatValue = delay;
  }
}

static void DemoRequestCallback(Handle request, bool failure, bool requestSuccessful, EHTTPStatusCode statusCode,
                                DataPack pack) {
  char matchId[MATCH_ID_LENGTH];
  char demoFileName[PLATFORM_MAX_PATH];
  int mapNumber;
  char uploadUrl[1024];
  char uploadUrlHeaderKey[1024];
  char uploadUrlHeaderValue[1024];
  bool deleteAfterUpload;
  ReadDemoDataPack(pack, matchId, sizeof(matchId), mapNumber, uploadUrl, sizeof(uploadUrl), uploadUrlHeaderKey,
                   sizeof(uploadUrlHeaderKey), uploadUrlHeaderValue, sizeof(uploadUrlHeaderValue), demoFileName,
                   sizeof(demoFileName), deleteAfterUpload);
  delete pack;

  if (failure || !requestSuccessful) {
    LogError("Failed to upload demo '%s' to '%s'.", demoFileName, uploadUrl);
    delete request;
    CallUploadEvent(matchId, mapNumber, demoFileName, false);
    return;
  }

  int status = view_as<int>(statusCode);
  if (status >= 300 || status < 200) {
    LogError("Demo request failed with HTTP status code: %d.", statusCode);
    int responseSize;
    SteamWorks_GetHTTPResponseBodySize(request, responseSize);
    char[] response = new char[responseSize];
    if (SteamWorks_GetHTTPResponseBodyData(request, response, responseSize)) {
      LogError("Response body: %s", response);
    } else {
      LogError("Failed to read response body.");
    }
    delete request;
    CallUploadEvent(matchId, mapNumber, demoFileName, false);
    return;
  }

  LogDebug("Demo request succeeded. HTTP status code: %d.", statusCode);
  if (deleteAfterUpload) {
    LogDebug(
      "get5_demo_delete_after_upload set to true when demo request started; deleting the file from the game server.");
    if (FileExists(demoFileName)) {
      if (!DeleteFile(demoFileName)) {
        LogError("Unable to delete demo file %s.", demoFileName);
      }
    }
  }
  delete request;
  CallUploadEvent(matchId, mapNumber, demoFileName, true);
}

static void CallUploadEvent(const char[] matchId, const int mapNumber, const char[] demoFileName, const bool success) {
  Get5DemoUploadEndedEvent event = new Get5DemoUploadEndedEvent(matchId, mapNumber, demoFileName, success);
  LogDebug("Calling Get5_OnDemoUploadEnded()");
  Call_StartForward(g_OnDemoUploadEnded);
  Call_PushCell(event);
  Call_Finish();
  EventLogger_LogAndDeleteEvent(event);
}
