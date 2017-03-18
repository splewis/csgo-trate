/**
 * Map vetoing functions
 */
public void CreateVeto() {
  if (g_MapPoolList.Length % 2 == 0) {
    LogError(
        "Warning, the maplist is odd number sized (%d maps), vetos may not function correctly!",
        g_MapPoolList.Length);
  }

  g_VetoCaptains[MatchTeam_Team1] = GetTeamCaptain(MatchTeam_Team1);
  g_VetoCaptains[MatchTeam_Team2] = GetTeamCaptain(MatchTeam_Team2);
  ResetReadyStatus();
  CreateTimer(1.0, Timer_VetoCountdown, _, TIMER_REPEAT);
}

public Action Timer_VetoCountdown(Handle timer) {
    static int warningsPrinted = 0;
    int secondsRemaining = g_VetoCountdown.IntValue;
    if (warningsPrinted >= g_VetoCountdown.IntValue) {
        warningsPrinted = 0;
        MatchTeam startingTeam = OtherMatchTeam(g_LastVetoTeam);
        VetoController(g_VetoCaptains[startingTeam]);
        return Plugin_Stop;
	} else {
        warningsPrinted++;
        secondsRemaining = secondsRemaining - warningsPrinted;
        Get5_MessageToAll("%t", "VetoCountdown", secondsRemaining);
        return Plugin_Continue;
    }
}

static void AbortVeto() {
  Get5_MessageToAll("%t", "CaptainLeftOnVetoInfoMessage");
  Get5_MessageToAll("%t", "ReadyToResumeVetoInfoMessage");
  ChangeState(GameState_PreVeto);
}

public void VetoFinished() {
  ChangeState(GameState_Warmup);
  Get5_MessageToAll("%t", "MapDecidedInfoMessage");
  for (int i = 0; i < g_MapsToPlay.Length; i++) {
    char map[PLATFORM_MAX_PATH];
    g_MapsToPlay.GetString(i, map, sizeof(map));
    Get5_MessageToAll("%t", "MapIsInfoMessage", i + 1, map);
  }

  g_MapChangePending = true;
  CreateTimer(10.0, Timer_NextMatchMap);
}


// Main Veto Controller

public void VetoController(int client) {
  if (!IsPlayer(client) || GetClientMatchTeam(client) == MatchTeam_TeamSpec) {
    AbortVeto();
  }

  int mapsLeft = GetNumMapsLeft();
  int maxMaps = MaxMapsToPlay(g_MapsToWin);

  int mapsPicked = g_MapsToPlay.Length;
  int sidesSet = g_MapSides.Length;

  // This is a dirty hack to get ban/ban/pick/pick/ban/ban
  // instead of straight vetoing until the maplist is the length
  // of the series.
  // This only applies to a standard Bo3 in the 7-map pool.
  // TODO: It should be written more generically.
  bool bo3_hack = false;
  if (maxMaps == 3 && (mapsLeft == 4 || mapsLeft == 5) && g_MapPoolList.Length == 7) {
    bo3_hack = true;
  }

  // This is also a bit hacky.
  // The purpose is to force the veto process to take a
  // ban/ban/ban/ban/pick/pick/last map unused process for BO2's.
  bool bo2_hack = false;
  if (g_BO2Match && (mapsLeft == 3 || mapsLeft == 2)) {
    bo2_hack = true;
  }

  if (sidesSet < mapsPicked) {
    if (g_MatchSideType == MatchSideType_Standard) {
      GiveSidePickMenu(client);

    } else if (g_MatchSideType == MatchSideType_AlwaysKnife) {
      g_MapSides.Push(SideChoice_KnifeRound);
      VetoController(client);

    } else if (g_MatchSideType == MatchSideType_NeverKnife) {
      g_MapSides.Push(SideChoice_Team1CT);
      VetoController(client);
    }

  } else if (mapsLeft == 1) {
    if (g_BO2Match) {
      // Terminate the veto since we've had ban-ban-ban-ban-pick-pick
      VetoFinished();
      return;
    }

    // Only 1 map left in the pool, add it directly to the active maplist.
    char mapName[PLATFORM_MAX_PATH];
    g_MapsLeftInVetoPool.GetString(0, mapName, sizeof(mapName));
    g_MapsToPlay.PushString(mapName);

    if (g_MatchSideType == MatchSideType_Standard) {
      g_MapSides.Push(SideChoice_KnifeRound);
    } else if (g_MatchSideType == MatchSideType_AlwaysKnife) {
      g_MapSides.Push(SideChoice_KnifeRound);
    } else if (g_MatchSideType == MatchSideType_NeverKnife) {
      g_MapSides.Push(SideChoice_Team1CT);
    }

    EventLogger_MapPicked(MatchTeam_TeamNone, mapName, g_MapsToPlay.Length - 1);

    Call_StartForward(g_OnMapPicked);
    Call_PushCell(MatchTeam_TeamNone);
    Call_PushString(mapName);
    Call_Finish();

    VetoFinished();
  } else if (mapsLeft + mapsPicked <= maxMaps || bo3_hack || bo2_hack) {
    GiveMapPickMenu(client);
  } else {
    GiveMapVetoMenu(client);
  }
}


// Map Vetos

public void GiveMapVetoMenu(int client) {
  Menu menu = new Menu(MapVetoMenuHandler);
  menu.SetTitle("%T", "MapVetoBanMenuText", client);
  menu.ExitButton = false;
  // Don't paginate the menu if we have 7 maps or less, as they will fit
  // on one page when we don't add the pagination options
  if (g_MapsLeftInVetoPool.Length <= 7) {
    menu.Pagination = MENU_NO_PAGINATION;
  }

  char mapName[PLATFORM_MAX_PATH];
  for (int i = 0; i < g_MapsLeftInVetoPool.Length; i++) {
    g_MapsLeftInVetoPool.GetString(i, mapName, sizeof(mapName));
    menu.AddItem(mapName, mapName);
  }
  menu.Display(client, MENU_TIME_FOREVER);
}

public int MapVetoMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
  if (action == MenuAction_Select) {
    int client = param1;
    char mapName[PLATFORM_MAX_PATH];
    menu.GetItem(param2, mapName, sizeof(mapName));
    RemoveStringFromArray(g_MapsLeftInVetoPool, mapName);

    MatchTeam team = GetClientMatchTeam(client);
    Get5_MessageToAll("%t", "TeamVetoedMapInfoMessage", g_FormattedTeamNames[team], mapName);

    EventLogger_MapVetoed(team, mapName);

    Call_StartForward(g_OnMapVetoed);
    Call_PushCell(team);
    Call_PushString(mapName);
    Call_Finish();

    VetoController(GetNextTeamCaptain(client));
    g_LastVetoTeam = team;

  } else if (action == MenuAction_Cancel) {
    AbortVeto();

  } else if (action == MenuAction_End) {
    delete menu;
  }
}


// Map Picks

public void GiveMapPickMenu(int client) {
  Menu menu = new Menu(MapPickMenuHandler);
  menu.SetTitle("%T", "MapVetoPickMenuText", client);
  menu.ExitButton = false;
  // Don't paginate the menu if we have 7 maps or less, as they will fit
  // on one page when we don't add the pagination options
  if (g_MapsLeftInVetoPool.Length <= 7) {
    menu.Pagination = MENU_NO_PAGINATION;
  }

  char mapName[PLATFORM_MAX_PATH];
  for (int i = 0; i < g_MapsLeftInVetoPool.Length; i++) {
    g_MapsLeftInVetoPool.GetString(i, mapName, sizeof(mapName));
    menu.AddItem(mapName, mapName);
  }
  menu.Display(client, MENU_TIME_FOREVER);
}

public int MapPickMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
  if (action == MenuAction_Select) {
    int client = param1;
    MatchTeam team = GetClientMatchTeam(client);
    char mapName[PLATFORM_MAX_PATH];
    menu.GetItem(param2, mapName, sizeof(mapName));

    g_MapsToPlay.PushString(mapName);
    RemoveStringFromArray(g_MapsLeftInVetoPool, mapName);

    Get5_MessageToAll("%t", "TeamPickedMapInfoMessage", g_FormattedTeamNames[team], mapName,
                      g_MapsToPlay.Length);
    g_LastVetoTeam = team;

    EventLogger_MapPicked(team, mapName, g_MapsToPlay.Length - 1);

    Call_StartForward(g_OnMapPicked);
    Call_PushCell(team);
    Call_PushString(mapName);
    Call_Finish();

    VetoController(GetNextTeamCaptain(client));

  } else if (action == MenuAction_Cancel) {
    AbortVeto();

  } else if (action == MenuAction_End) {
    delete menu;
  }
}


// Side Picks

public void GiveSidePickMenu(int client) {
  Menu menu = new Menu(SidePickMenuHandler);
  menu.ExitButton = false;
  char mapName[PLATFORM_MAX_PATH];
  g_MapsToPlay.GetString(g_MapsToPlay.Length - 1, mapName, sizeof(mapName));
  menu.SetTitle("%T", "MapVetoSidePickMenuText", client, mapName);
  menu.AddItem("CT", "CT");
  menu.AddItem("T", "T");
  menu.Display(client, MENU_TIME_FOREVER);
}

public int SidePickMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
  if (action == MenuAction_Select) {
    int client = param1;
    MatchTeam team = GetClientMatchTeam(client);

    char choice[PLATFORM_MAX_PATH];
    menu.GetItem(param2, choice, sizeof(choice));
    int selectedSide;

    if (StrEqual(choice, "CT")) {
      selectedSide = CS_TEAM_CT;
      if (team == MatchTeam_Team1)
        g_MapSides.Push(SideChoice_Team1CT);
      else
        g_MapSides.Push(SideChoice_Team1T);
    } else {
      selectedSide = CS_TEAM_T;
      if (team == MatchTeam_Team1)
        g_MapSides.Push(SideChoice_Team1T);
      else
        g_MapSides.Push(SideChoice_Team1CT);
    }

    char mapName[PLATFORM_MAX_PATH];
    g_MapsToPlay.GetString(g_MapsToPlay.Length - 1, mapName, sizeof(mapName));

    EventLogger_SidePicked(team, mapName, g_MapsToPlay.Length - 1, selectedSide);
    Get5_MessageToAll("%t", "TeamSelectSideInfoMessage", g_FormattedTeamNames[team], choice,
                      mapName);

    VetoController(client);

  } else if (action == MenuAction_Cancel) {
    AbortVeto();

  } else if (action == MenuAction_End) {
    delete menu;
  }
}


// Helpers

static int GetNumMapsLeft() {
  return g_MapsLeftInVetoPool.Length;
}
