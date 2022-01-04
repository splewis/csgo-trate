const float kTimeGivenToTrade = 1.5;

public void Stats_PluginStart() {
  HookEvent("bomb_defused", Stats_BombDefusedEvent);
  HookEvent("bomb_exploded", Stats_BombExplodedEvent);
  HookEvent("bomb_planted", Stats_BombPlantedEvent);
  HookEvent("grenade_thrown", Stats_GrenadeThrownEvent);
  HookEvent("player_blind", Stats_PlayerBlindEvent);
  HookEvent("player_death", Stats_PlayerDeathEvent);
  HookEvent("player_hurt", Stats_DamageDealtEvent, EventHookMode_Pre);
  HookEvent("round_mvp", Stats_RoundMVPEvent);
}

public void Stats_Reset() {
  if (g_StatsKv != null) {
    delete g_StatsKv;
  }
  g_StatsKv = new KeyValues("Stats");
}

public void Stats_InitSeries() {
  Stats_Reset();
  char seriesType[32];
  Format(seriesType, sizeof(seriesType), "bo%d", MaxMapsToPlay(g_MapsToWin));
  g_StatsKv.SetString(STAT_SERIESTYPE, seriesType);
  g_StatsKv.SetString(STAT_SERIES_TEAM1NAME, g_TeamNames[MatchTeam_Team1]);
  g_StatsKv.SetString(STAT_SERIES_TEAM2NAME, g_TeamNames[MatchTeam_Team2]);
  DumpToFile();
}

public void Stats_ResetRoundValues() {
  g_SetTeamClutching[CS_TEAM_CT] = false;
  g_SetTeamClutching[CS_TEAM_T] = false;
  g_TeamFirstKillDone[CS_TEAM_CT] = false;
  g_TeamFirstKillDone[CS_TEAM_T] = false;
  g_TeamFirstDeathDone[CS_TEAM_CT] = false;
  g_TeamFirstDeathDone[CS_TEAM_T] = false;

  for (int i = 1; i <= MaxClients; i++) {
    Stats_ResetClientRoundValues(i);
  }
}

public void Stats_ResetClientRoundValues(int client) {
  g_RoundKills[client] = 0;
  g_RoundClutchingEnemyCount[client] = 0;
  g_PlayerKilledBy[client] = -1;
  g_PlayerKilledByTime[client] = 0.0;
  g_PlayerRoundKillOrAssistOrTradedDeath[client] = false;
  g_PlayerSurvived[client] = true;

  for (int i = 1; i <= MaxClients; i++) {
    g_DamageDone[client][i] = 0;
    g_DamageDoneHits[client][i] = 0;
    g_DamageDoneKill[client][i] = false;
    g_DamageDoneAssist[client][i] = false;
    g_DamageDoneFlashAssist[client][i] = false;
  }
}

public void Stats_RoundStart() {
  for (int i = 1; i <= MaxClients; i++) {
    if (IsPlayer(i)) {
      MatchTeam team = GetClientMatchTeam(i);
      if (team == MatchTeam_Team1 || team == MatchTeam_Team2) {
        IncrementPlayerStat(i, STAT_ROUNDSPLAYED);

        GoToPlayer(i);
        char name[MAX_NAME_LENGTH];
        GetClientName(i, name, sizeof(name));
        g_StatsKv.SetString(STAT_NAME, name);
        GoBackFromPlayer();
      }
    }
  }
}

public void Stats_RoundEnd(int csTeamWinner) {
  // Update team scores.
  GoToMap();
  char mapName[PLATFORM_MAX_PATH];
  GetCleanMapName(mapName, sizeof(mapName));
  g_StatsKv.SetString(STAT_MAPNAME, mapName);
  GoBackFromMap();

  GoToTeam(MatchTeam_Team1);
  g_StatsKv.SetNum(STAT_TEAMSCORE, CS_GetTeamScore(MatchTeamToCSTeam(MatchTeam_Team1)));
  GoBackFromTeam();

  GoToTeam(MatchTeam_Team2);
  g_StatsKv.SetNum(STAT_TEAMSCORE, CS_GetTeamScore(MatchTeamToCSTeam(MatchTeam_Team2)));
  GoBackFromTeam();

  // Update player 1vx, x-kill, and KAST values.
  for (int i = 1; i <= MaxClients; i++) {
    if (IsPlayer(i)) {
      MatchTeam team = GetClientMatchTeam(i);
      if (team == MatchTeam_Team1 || team == MatchTeam_Team2) {
        switch (g_RoundKills[i]) {
          case 1:
            IncrementPlayerStat(i, STAT_1K);
          case 2:
            IncrementPlayerStat(i, STAT_2K);
          case 3:
            IncrementPlayerStat(i, STAT_3K);
          case 4:
            IncrementPlayerStat(i, STAT_4K);
          case 5:
            IncrementPlayerStat(i, STAT_5K);
        }

        if (GetClientTeam(i) == csTeamWinner) {
          switch (g_RoundClutchingEnemyCount[i]) {
            case 1:
              IncrementPlayerStat(i, STAT_V1);
            case 2:
              IncrementPlayerStat(i, STAT_V2);
            case 3:
              IncrementPlayerStat(i, STAT_V3);
            case 4:
              IncrementPlayerStat(i, STAT_V4);
            case 5:
              IncrementPlayerStat(i, STAT_V5);
          }
        }

        if (g_PlayerRoundKillOrAssistOrTradedDeath[i] || g_PlayerSurvived[i]) {
          IncrementPlayerStat(i, STAT_KAST);
        }

        GoToPlayer(i);
        char name[MAX_NAME_LENGTH];
        GetClientName(i, name, sizeof(name));
        g_StatsKv.SetString(STAT_NAME, name);

        g_StatsKv.SetNum(STAT_CONTRIBUTION_SCORE, CS_GetClientContributionScore(i));

        GoBackFromPlayer();
      }
    }
  }

  if (g_DamagePrintCvar.BoolValue) {
    for (int i = 1; i <= MaxClients; i++) {
      if (IsValidClient(i)) {
        PrintDamageInfo(i);
      }
    }
  }
}

public void Stats_UpdateMapScore(MatchTeam winner) {
  GoToMap();

  char winnerString[16];
  GetTeamString(winner, winnerString, sizeof(winnerString));

  g_StatsKv.SetString(STAT_MAPWINNER, winnerString);
  g_StatsKv.SetString(STAT_DEMOFILENAME, g_DemoFileName);

  GoBackFromMap();

  DumpToFile();
}

public void Stats_Forfeit(MatchTeam team) {
  g_StatsKv.SetNum(STAT_SERIES_FORFEIT, 1);
  if (team == MatchTeam_Team1) {
    Stats_SeriesEnd(MatchTeam_Team2);
  } else if (team == MatchTeam_Team2) {
    Stats_SeriesEnd(MatchTeam_Team1);
  } else {
    Stats_SeriesEnd(MatchTeam_TeamNone);
  }
}

public void Stats_SeriesEnd(MatchTeam winner) {
  char winnerString[16];
  GetTeamString(winner, winnerString, sizeof(winnerString));
  g_StatsKv.SetString(STAT_SERIESWINNER, winnerString);
  DumpToFile();
}

public Action Stats_GrenadeThrownEvent(Event event, const char[] name, bool dontBroadcast) {
  if (g_GameState != Get5State_Live) {
    return Plugin_Continue;
  }

  int attacker = GetClientOfUserId(event.GetInt("userid"));

  if (IsValidClient(attacker)) {

    char weapon[32];
    event.GetString("weapon", weapon, sizeof(weapon));

    EventLogger_GrenadeThrown(attacker, weapon);

    int roundTime = GetMilliSecondsPassedSince(g_RoundStartedTime);
    int attackerTeam = GetClientTeam(attacker);
    int mapNumber = GetMapNumber();

    LogDebug("Calling Get5_OnGrenadeThrown(client=%d, weapon=%s, mapNumber=%d, roundNumber=%d, roundTime=%d, team=%d)",
        attacker, weapon, mapNumber, g_RoundNumber, roundTime, attackerTeam);

    Call_StartForward(g_OnGrenadeThrown);
    Call_PushCell(attacker);
    Call_PushString(weapon);
    Call_PushCell(mapNumber);
    Call_PushCell(g_RoundNumber);
    Call_PushCell(roundTime);
    Call_PushCell(attackerTeam);
    Call_Finish();

  }
  return Plugin_Continue;
}

public Action Stats_PlayerDeathEvent(Event event, const char[] name, bool dontBroadcast) {
  int attacker = GetClientOfUserId(event.GetInt("attacker"));

  if (g_GameState != Get5State_Live || g_DoingBackupRestoreNow) {
    if (g_AutoReadyActivePlayers.BoolValue) {
      // HandleReadyCommand checks for game state, so we don't need to do that here as well.
      HandleReadyCommand(attacker, true);
    }
    return Plugin_Continue;
  }

  int victim = GetClientOfUserId(event.GetInt("userid"));
  int assister = GetClientOfUserId(event.GetInt("assister"));

  bool validAttacker = IsValidClient(attacker);
  bool validVictim = IsValidClient(victim);
  bool validAssister = assister > 0 && IsValidClient(assister);

  if (!validVictim) {
    return Plugin_Continue; // Not sure how this would happen, but it's not something we care about.
  }

  bool headshot = event.GetBool("headshot");
  bool assistedFlash = event.GetBool("assistedflash");

  char weapon[32];
  event.GetString("weapon", weapon, sizeof(weapon));

  int attackerTeam = GetClientTeam(attacker);
  int victimTeam = GetClientTeam(victim);

  IncrementPlayerStat(victim, STAT_DEATHS);
  // used for calculating round KAST
  g_PlayerSurvived[victim] = false;

  if (!g_TeamFirstDeathDone[victimTeam]) {
    g_TeamFirstDeathDone[victimTeam] = true;
    IncrementPlayerStat(victim, (victimTeam == CS_TEAM_CT) ? STAT_FIRSTDEATH_CT : STAT_FIRSTDEATH_T);
  }

  if (validAttacker) {

    if (HelpfulAttack(attacker, victim)) {

      if (!g_TeamFirstKillDone[attackerTeam]) {
        g_TeamFirstKillDone[attackerTeam] = true;
        IncrementPlayerStat(attacker, (attackerTeam == CS_TEAM_CT) ? STAT_FIRSTKILL_CT : STAT_FIRSTKILL_T);
      }

      g_RoundKills[attacker]++;

      g_PlayerKilledBy[victim] = attacker;
      g_PlayerKilledByTime[victim] = GetGameTime();
      g_DamageDoneKill[attacker][victim] = true;
      UpdateTradeStat(attacker, victim);

      IncrementPlayerStat(attacker, STAT_KILLS);
      g_PlayerRoundKillOrAssistOrTradedDeath[attacker] = true;

      if (headshot) {
        IncrementPlayerStat(attacker, STAT_HEADSHOT_KILLS);
      }

      // We need the weapon ID to reliably translate to a knife. The regular "bayonet" - as the only
      // knife - is not prefixed with "knife" for whatever reason, so searching weapon name strings
      // is unsafe.
      CSWeaponID weaponId = CS_AliasToWeaponID(weapon);

      // Other than these constants, all knives can be found after CSWeapon_MAX_WEAPONS_NO_KNIFES.
      // See https://sourcemod.dev/#/cstrike/enumeration.CSWeaponID
      if (weaponId == CSWeapon_KNIFE || weaponId == CSWeapon_KNIFE_GG ||
          weaponId == CSWeapon_KNIFE_T || weaponId == CSWeapon_KNIFE_GHOST ||
          weaponId > CSWeapon_MAX_WEAPONS_NO_KNIFES) {
        IncrementPlayerStat(attacker, STAT_KNIFE_KILLS);
      }

    } else if (attacker == victim) {
      IncrementPlayerStat(attacker, STAT_SUICIDES); // If killed by self; i.e. own grenade.
    } else {
      IncrementPlayerStat(attacker, STAT_TEAMKILLS);
    }
  } else {
    IncrementPlayerStat(victim, STAT_SUICIDES); // Fall damage or world.
  }

  int assisterTeam = 0;

  if (validAssister) {
    assisterTeam = GetClientTeam(assister);
    // Assists should only count towards opposite team
    if (HelpfulAttack(assister, victim)) {
      // You cannot flash-assist and regular-assist for the same kill.
      if (assistedFlash) {
        IncrementPlayerStat(assister, STAT_FLASHBANG_ASSISTS);
        g_DamageDoneFlashAssist[assister][victim] = true;
      } else {
        IncrementPlayerStat(assister, STAT_ASSISTS);
        g_PlayerRoundKillOrAssistOrTradedDeath[assister] = true;
        g_DamageDoneAssist[assister][victim] = true;
      }
    }
  }

  // Update "clutch" (1vx) data structures to check if the clutcher wins the round
  int tCount = CountAlivePlayersOnTeam(CS_TEAM_T);
  int ctCount = CountAlivePlayersOnTeam(CS_TEAM_CT);

  if (tCount == 1 && !g_SetTeamClutching[CS_TEAM_T]) {
    g_SetTeamClutching[CS_TEAM_T] = true;
    int clutcher = GetClutchingClient(CS_TEAM_T);
    g_RoundClutchingEnemyCount[clutcher] = ctCount;
  }

  if (ctCount == 1 && !g_SetTeamClutching[CS_TEAM_CT]) {
    g_SetTeamClutching[CS_TEAM_CT] = true;
    int clutcher = GetClutchingClient(CS_TEAM_CT);
    g_RoundClutchingEnemyCount[clutcher] = tCount;
  }

  int mapNumber = GetMapNumber();
  int roundTime = GetMilliSecondsPassedSince(g_RoundStartedTime);
  int penetrated = event.GetInt("penetrated");
  bool thruSmoke = event.GetBool("thrusmoke");
  bool attackerBlind = event.GetBool("attackerblind");
  bool noScope = event.GetBool("noscope");
  bool friendlyFire = validAttacker ? attackerTeam == victimTeam : false;
  bool assistFriendlyFire = validAssister ? assisterTeam == victimTeam : false;

  EventLogger_PlayerDeath(
    g_RoundNumber,
    roundTime,
    validAttacker ? attacker : 0,
    victim, // we already checked that victim is valid.
    headshot,
    validAssister ? assister : 0,
    assistedFlash,
    weapon,
    friendlyFire,
    assistFriendlyFire,
    penetrated,
    thruSmoke,
    noScope,
    attackerBlind
  );

  LogDebug("Calling Get5_OnPlayerDied(weapon=%s, headshot=%d, mapNumber=%d, roundNumber=%d, roundTime=%d, attacker=%d, victim=%d, assister=%d, assistedFlash=%d, penetrated=%d, thruSmoke=%d, noScope=%d, attackerBlind=%d, attackerTeam=%d, assisterTeam=%d, victimTeam=%d)",
           weapon, headshot, mapNumber, g_RoundNumber, roundTime, attacker, victim, assister, assistedFlash, penetrated, thruSmoke, noScope, attackerBlind, attackerTeam, assisterTeam, victimTeam);

  Call_StartForward(g_OnPlayerDied);
  Call_PushString(weapon);
  Call_PushCell(headshot);
  Call_PushCell(mapNumber);
  Call_PushCell(g_RoundNumber);
  Call_PushCell(roundTime);
  Call_PushCell(attacker);
  Call_PushCell(victim);
  Call_PushCell(assister);
  Call_PushCell(assistedFlash);
  Call_PushCell(penetrated);
  Call_PushCell(thruSmoke);
  Call_PushCell(noScope);
  Call_PushCell(attackerBlind);
  Call_PushCell(attackerTeam);
  Call_PushCell(assisterTeam);
  Call_PushCell(victimTeam);
  Call_Finish();

  return Plugin_Continue;
}

static void UpdateTradeStat(int attacker, int victim) {
  // Look to see if victim killed any of attacker's teammates recently.
  for (int i = 1; i <= MaxClients; i++) {
    if (IsPlayer(i) && g_PlayerKilledBy[i] == victim &&
        GetClientTeam(i) == GetClientTeam(attacker)) {
      float dt = GetGameTime() - g_PlayerKilledByTime[i];
      if (dt < kTimeGivenToTrade) {
        IncrementPlayerStat(attacker, STAT_TRADEKILL);
        // teammate (i) was traded
        g_PlayerRoundKillOrAssistOrTradedDeath[i] = true;
      }
    }
  }
}

public Action Stats_DamageDealtEvent(Event event, const char[] name, bool dontBroadcast) {
  if (g_GameState != Get5State_Live) {
    return Plugin_Continue;
  }

  int attacker = GetClientOfUserId(event.GetInt("attacker"));
  int victim = GetClientOfUserId(event.GetInt("userid"));

  if (HelpfulAttack(attacker, victim)) {
    int preDamageHealth = GetClientHealth(victim);
    int damage = event.GetInt("dmg_health");
    int postDamageHealth = event.GetInt("health");

    // this maxes the damage variables at 100,
    // so doing 50 damage when the player had 2 health
    // only counts as 2 damage.
    if (postDamageHealth == 0) {
      damage += preDamageHealth;
    }

    g_DamageDone[attacker][victim] += damage;
    g_DamageDoneHits[attacker][victim]++;

    AddToPlayerStat(attacker, STAT_DAMAGE, damage);

    // Damage can be dealt by throwing grenades "at" people, physically, but the regular score board
    // does not count this as utility damage, so neither do we. Hence no 'smokegrenade' or
    // 'flashbang' here.

    char weapon[32];
    event.GetString("weapon", weapon, sizeof(weapon));

    if (StrEqual(weapon, "hegrenade") || StrEqual(weapon, "inferno")) {
      AddToPlayerStat(attacker, STAT_UTILITY_DAMAGE, damage);
    }
  }

  return Plugin_Continue;
}

public Action Stats_BombPlantedEvent(Event event, const char[] name, bool dontBroadcast) {
  if (g_GameState != Get5State_Live) {
    return Plugin_Continue;
  }

  g_BombPlantedTime = GetEngineTime();

  int client = GetClientOfUserId(event.GetInt("userid"));
  int site = event.GetInt("site");
  if (IsValidClient(client)) {
    IncrementPlayerStat(client, STAT_BOMBPLANTS);
    EventLogger_BombPlanted(client, site);

    int mapNumber = GetMapNumber();
    int roundTime = GetMilliSecondsPassedSince(g_RoundStartedTime);

    LogDebug("Calling Get5_OnBombPlanted(client=%d, site=%d, mapNumber=%d, roundNumber=%d, roundTime=%d)",
               client, site, mapNumber, g_RoundNumber, roundTime);

    Call_StartForward(g_OnBombPlanted);
    Call_PushCell(client);
    Call_PushCell(site);
    Call_PushCell(mapNumber);
    Call_PushCell(g_RoundNumber);
    Call_PushCell(roundTime);
    Call_Finish();

  }

  return Plugin_Continue;
}

public Action Stats_BombDefusedEvent(Event event, const char[] name, bool dontBroadcast) {
  if (g_GameState != Get5State_Live) {
    return Plugin_Continue;
  }

  int client = GetClientOfUserId(event.GetInt("userid"));
  int site = event.GetInt("site");
  if (IsValidClient(client)) {
    IncrementPlayerStat(client, STAT_BOMBDEFUSES);

    int timeRemaining = (GetCvarIntSafe("mp_c4timer") * 1000) - GetMilliSecondsPassedSince(g_BombPlantedTime);
    int mapNumber = GetMapNumber();
    int roundTime = GetMilliSecondsPassedSince(g_RoundStartedTime);

    EventLogger_BombDefused(client, site, timeRemaining);

    LogDebug("Calling Get5_OnBombDefused(client=%d, site=%d, mapNumber=%d, roundNumber=%d, roundTime=%d, timeRemaining=%d)",
                   client, site, mapNumber, g_RoundNumber, roundTime, timeRemaining);

    Call_StartForward(g_OnBombDefused);
    Call_PushCell(client);
    Call_PushCell(site);
    Call_PushCell(mapNumber);
    Call_PushCell(g_RoundNumber);
    Call_PushCell(roundTime);
    Call_PushCell(timeRemaining);
    Call_Finish();

  }

  return Plugin_Continue;
}

public Action Stats_BombExplodedEvent(Event event, const char[] name, bool dontBroadcast) {
  if (g_GameState != Get5State_Live) {
    return Plugin_Continue;
  }

  int client = GetClientOfUserId(event.GetInt("userid"));
  int site = event.GetInt("site");
  if (IsValidClient(client)) {
    EventLogger_BombExploded(client, site);
  }

  return Plugin_Continue;
}

public Action Stats_PlayerBlindEvent(Event event, const char[] name, bool dontBroadcast) {
  if (g_GameState != Get5State_Live) {
    return Plugin_Continue;
  }

  float duration = event.GetFloat("blind_duration");

  if (duration < 2.5) {
    // 2.5 is an arbitrary value that closely matches the "enemies flashed" column of the in-game
    // scoreboard.
    return Plugin_Continue;
  }

  int victim = GetClientOfUserId(event.GetInt("userid"));
  int attacker = GetClientOfUserId(event.GetInt("attacker"));

  if (attacker == victim || !IsValidClient(attacker) || !IsValidClient(victim)) {
    return Plugin_Continue;
  }

  int victimTeam = GetClientTeam(victim);
  if (victimTeam == CS_TEAM_SPECTATOR || victimTeam == CS_TEAM_NONE) {
    return Plugin_Continue;
  }

  if (GetClientTeam(attacker) != victimTeam) {
    IncrementPlayerStat(attacker, STAT_ENEMIES_FLASHED);
  } else {
    IncrementPlayerStat(attacker, STAT_FRIENDLIES_FLASHED);
  }

  return Plugin_Continue;
}

public Action Stats_RoundMVPEvent(Event event, const char[] name, bool dontBroadcast) {
  if (g_GameState != Get5State_Live) {
    return Plugin_Continue;
  }

  int client = GetClientOfUserId(event.GetInt("userid"));

  if (IsValidClient(client)) {
    IncrementPlayerStat(client, STAT_MVP);

    int reason = event.GetInt("reason");
    int mapNumber = GetMapNumber();
    int clientTeam = GetClientTeam(client);

    EventLogger_MVP(client, reason);

    LogDebug("Calling Get5_OnPlayerBecameMVP(client=%d, mapNumber=%d, roundNumber=%d, clientTeam=%d, reason=%d)",
               client, mapNumber, g_RoundNumber, clientTeam, reason);

    Call_StartForward(g_OnPlayerBecameMVP);
    Call_PushCell(client);
    Call_PushCell(mapNumber);
    Call_PushCell(g_RoundNumber);
    Call_PushCell(clientTeam);
    Call_PushCell(reason);
    Call_Finish();

  }

  return Plugin_Continue;
}

static int GetPlayerStat(int client, const char[] field) {
  GoToPlayer(client);
  int value = g_StatsKv.GetNum(field);
  GoBackFromPlayer();
  return value;
}

static int SetPlayerStat(int client, const char[] field, int newValue) {
  GoToPlayer(client);
  g_StatsKv.SetNum(field, newValue);
  GoBackFromPlayer();
  return newValue;
}

public int AddToPlayerStat(int client, const char[] field, int delta) {
  int value = GetPlayerStat(client, field);
  return SetPlayerStat(client, field, value + delta);
}

static int IncrementPlayerStat(int client, const char[] field) {
  LogDebug("Incrementing player stat %s for %L", field, client);
  return AddToPlayerStat(client, field, 1);
}

static void GoToMap() {
  char mapNumberString[32];
  Format(mapNumberString, sizeof(mapNumberString), "map%d", GetMapStatsNumber());
  g_StatsKv.JumpToKey(mapNumberString, true);
}

static void GoBackFromMap() {
  g_StatsKv.GoBack();
}

static void GoToTeam(MatchTeam team) {
  GoToMap();

  if (team == MatchTeam_Team1)
    g_StatsKv.JumpToKey("team1", true);
  else
    g_StatsKv.JumpToKey("team2", true);
}

static void GoBackFromTeam() {
  GoBackFromMap();
  g_StatsKv.GoBack();
}

static void GoToPlayer(int client) {
  MatchTeam team = GetClientMatchTeam(client);
  GoToTeam(team);

  char auth[AUTH_LENGTH];
  if (GetAuth(client, auth, sizeof(auth))) {
    g_StatsKv.JumpToKey(auth, true);
  }
}

static void GoBackFromPlayer() {
  GoBackFromTeam();
  g_StatsKv.GoBack();
}

public int GetMapStatsNumber() {
  int x = GetMapNumber();
  if (g_MapChangePending) {
    return x - 1;
  } else {
    return x;
  }
}

static int GetClutchingClient(int csTeam) {
  int client = -1;
  int count = 0;
  for (int i = 1; i <= MaxClients; i++) {
    if (IsPlayer(i) && IsPlayerAlive(i) && GetClientTeam(i) == csTeam) {
      client = i;
      count++;
    }
  }

  if (count == 1) {
    return client;
  } else {
    return -1;
  }
}

public void DumpToFile() {
  char path[PLATFORM_MAX_PATH + 1];
  if (FormatCvarString(g_StatsPathFormatCvar, path, sizeof(path))) {
    DumpToFilePath(path);
  }
}

public bool DumpToFilePath(const char[] path) {
  return IsJSONPath(path) ? DumpToJSONFile(path) : g_StatsKv.ExportToFile(path);
}

public bool DumpToJSONFile(const char[] path) {
  g_StatsKv.Rewind();
  g_StatsKv.GotoFirstSubKey(false);
  JSON_Object stats = EncodeKeyValue(g_StatsKv);
  g_StatsKv.Rewind();

  File stats_file = OpenFile(path, "w");
  if (stats_file == null) {
    LogError("Failed to open stats file");
    return false;
  }

  // Mark the JSON buffer static to avoid running into limited haep/stack space, see
  // https://forums.alliedmods.net/showpost.php?p=2620835&postcount=6
  static char jsonBuffer[65536];  // 64 KiB
  stats.Encode(jsonBuffer, sizeof(jsonBuffer));
  json_cleanup_and_delete(stats);
  stats_file.WriteString(jsonBuffer, false);

  stats_file.Flush();
  stats_file.Close();

  return true;
}

JSON_Object EncodeKeyValue(KeyValues kv) {
  char keyBuffer[256];
  char valBuffer[256];
  char sectionName[256];
  JSON_Object json_kv = new JSON_Object();

  do {
    if (kv.GotoFirstSubKey(false)) {
      // Current key is a section. Browse it recursively.
      JSON_Object obj = EncodeKeyValue(kv);
      kv.GoBack();
      kv.GetSectionName(sectionName, sizeof(sectionName));
      json_kv.SetObject(sectionName, obj);
    } else {
      // Current key is a regular key, or an empty section.
      KvDataTypes keyType = kv.GetDataType(NULL_STRING);
      kv.GetSectionName(keyBuffer, sizeof(keyBuffer));
      if (keyType == KvData_String) {
        kv.GetString(NULL_STRING, valBuffer, sizeof(valBuffer));
        json_kv.SetString(keyBuffer, valBuffer);
      } else if (keyType == KvData_Int) {
        json_kv.SetInt(keyBuffer, kv.GetNum(NULL_STRING));
      } else if (keyType == KvData_Float) {
        json_kv.SetFloat(keyBuffer, kv.GetFloat(NULL_STRING));
      } else {
        LogDebug("Can't JSON encode key '%s' with type %d", keyBuffer, keyType);
      }
    }
  } while (kv.GotoNextKey(false));

  return json_kv;
}

static void PrintDamageInfo(int client) {
  if (!IsPlayer(client))
    return;

  int team = GetClientTeam(client);
  if (team != CS_TEAM_T && team != CS_TEAM_CT)
    return;

  char message[256];

  int otherTeam = (team == CS_TEAM_T) ? CS_TEAM_CT : CS_TEAM_T;
  for (int i = 1; i <= MaxClients; i++) {
    if (IsPlayer(i) && GetClientTeam(i) == otherTeam) {
      int health = IsPlayerAlive(i) ? GetClientHealth(i) : 0;
      char name[64];
      GetClientName(i, name, sizeof(name));

      g_DamagePrintFormat.GetString(message, sizeof(message));
      ReplaceStringWithInt(message, sizeof(message), "{DMG_TO}", g_DamageDone[client][i], false);
      ReplaceStringWithInt(message, sizeof(message), "{HITS_TO}", g_DamageDoneHits[client][i], false);

      if (g_DamageDoneKill[client][i]) {
          ReplaceString(message, sizeof(message), "{KILL_TO}", "{GREEN}X{NORMAL}", false);
      } else if (g_DamageDoneAssist[client][i]) {
          ReplaceString(message, sizeof(message), "{KILL_TO}", "{YELLOW}A{NORMAL}", false);
      } else if (g_DamageDoneFlashAssist[client][i]) {
          ReplaceString(message, sizeof(message), "{KILL_TO}", "{YELLOW}F{NORMAL}", false);
      } else {
          ReplaceString(message, sizeof(message), "{KILL_TO}", "–", false);
      }

      ReplaceStringWithInt(message, sizeof(message), "{DMG_FROM}", g_DamageDone[i][client], false);
      ReplaceStringWithInt(message, sizeof(message), "{HITS_FROM}", g_DamageDoneHits[i][client], false);

      if (g_DamageDoneKill[i][client]) {
          ReplaceString(message, sizeof(message), "{KILL_FROM}", "{DARK_RED}X{NORMAL}", false);
      } else if (g_DamageDoneAssist[i][client]) {
          ReplaceString(message, sizeof(message), "{KILL_FROM}", "{YELLOW}A{NORMAL}", false);
      } else if (g_DamageDoneFlashAssist[i][client]) {
          ReplaceString(message, sizeof(message), "{KILL_FROM}", "{YELLOW}F{NORMAL}", false);
      } else {
          ReplaceString(message, sizeof(message), "{KILL_FROM}", "–", false);
      }

      ReplaceString(message, sizeof(message), "{NAME}", name, false);
      ReplaceStringWithInt(message, sizeof(message), "{HEALTH}", health, false);

      Colorize(message, sizeof(message));
      PrintToChat(client, message);
    }
  }
}
