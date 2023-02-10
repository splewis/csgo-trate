# :material-format-list-text: Match Schema

## What is it?

A match configuration file contains everything that Get5 and your server needs to host a series. This includes locking
players to their correct team and side, setting the map(s) and configuring the game rules.

Two files ship with Get5 that give a general idea of what can be included in a match config. A Valve KeyValue
format can be found [here](https://github.com/splewis/get5/blob/master/configs/get5/example_match.cfg), and a JSON
format can be found [here](https://github.com/splewis/get5/blob/master/configs/get5/example_match.json). In this
documentation, we'll go through what each value means, but do note that **only the values** `team1`, `team2` and
`maplist` are required to start a match. Reasonable defaults are used for the other values (Bo3 series,
5v5, empty strings for team names, etc.). We recommend using the JSON format whenever possible, as JSON has way
better support in various programming languages than Valve's KeyValue format (which essentially has none).

## The schema {: #schema }

```typescript title="TypeScript interface definition of a match configuration"
type SteamID = string // (8)
type Get5PlayerSet = { [key: SteamID]: string } | [SteamID] // (9)

interface Get5MatchTeam {
    "players": Get5PlayerSet // (24)
    "coaches": Get5PlayerSet | undefined // (23)
    "name": string | undefined // (16)
    "tag": string | undefined // (17)
    "flag": string | undefined // (18)
    "logo": string | undefined // (19)
    "series_score": number | undefined // (26)
    "matchtext": string | undefined // (27)
    "fromfile": string | undefined // (28)
}

interface Get5MapListFromFile {
    "fromfile": string // (35)
}

interface Get5Match {
    "match_title": string | undefined // (25)
    "matchid": string | undefined // (1)
    "clinch_series": boolean | undefined // (32)
    "num_maps": number | undefined // (2)
    "wingman": boolean | undefined // (37)
    "players_per_team": number | undefined // (3)
    "coaches_per_team": number | undefined // (4)
    "coaches_must_ready": boolean | undefined // (33)
    "min_players_to_ready": number | undefined // (5)
    "min_spectators_to_ready": number | undefined // (6)
    "skip_veto": boolean | undefined // (7)
    "veto_first": "team1" | "team2" | "random" | undefined // (11)
    "veto_mode": ['team1_ban' | 'team2_ban'
        | 'team1_pick' | 'team2_pick'] | undefined // (36)
    "side_type": "standard" | "always_knife" | "never_knife" | undefined // (12)
    "map_sides": ["team1_ct" | "team1_t" | "knife"] | undefined // (31)
    "spectators": { // (10)
        "name": string | undefined // (29)
        "players": Get5PlayerSet | undefined // (30)
        "fromfile": string | undefined // (34)
    } | undefined
    "maplist": string[] | Get5MapListFromFile // (13)
    "favored_percentage_team1": number | undefined // (14)
    "favored_percentage_text": string | undefined // (15)
    "team1": Get5MatchTeam // (20)
    "team2": Get5MatchTeam // (21)
    "cvars": { [key: string]: string | number } | undefined // (22)
}
```

1. _Optional_<br>The ID of the match. This determines the `matchid` parameter in all
   [forwards and events](../events_and_forwards). If you use the [MySQL extension](../stats_system#mysql), you
   should leave this field blank (or omit it), as match IDs will be assigned automatically. If you do want to assign
   match IDs from another source, they **must** be integers (in a string) and must increment between
   matches.<br><br>**`Default: ""`**
2. _Optional_<br>The number of maps to play in the series.<br><br>**`Default: 3`**
3. _Optional_<br>The number of players per team. You should **never** set this to a value higher than the number of
   players you want to actually play in a game, *excluding* coaches.<br><br>**`Default: 5 (2 in wingman)`**
4. _Optional_<br>The maximum number of [coaches](../coaching) per team.<br><br>**`Default: 2`**
5. _Optional_<br>The minimum number of players that must be present for the [`!forceready`](../commands#forceready)
   command to succeed. If not forcing a team ready, **all** players must [`!ready`](../commands#ready) up
   themselves.<br><br>**`Default: 0`**
6. _Optional_<br>The minimum number of spectators that must be [`!ready`](../commands#ready) for the game to
   begin.<br><br>**`Default: 0`**
7. _Optional_<br>Whether to skip the [map selection](../veto) phase. If `true`, `num_maps` are simply played in the
   order they appear in `maplist`, and no map selection is performed by players in-game.<br><br>**`Default: false`**
8. A player's :material-steam: Steam ID. This can be in any format, but we recommend a string representation of SteamID
   64, i.e. `"76561197987713664"`.
9. Players are represented each with a mapping of `SteamID -> PlayerName` as a key-value dictionary. The name
   is optional and should be set to an empty string to let players decide their own name. You can also provide a simple
   string array of `SteamID` disable name-locking.
10. _Optional_<br>The spectators to allow into the game. If not defined, spectators cannot join the
    game.<br><br>**`Default: undefined`**
11. _Optional_<br>The team that makes the first [map selection](../veto) choice.<br><br>**`Default: "team1"`**
12. _Optional_<br>The method used to determine sides during [map selection](../veto).<br><br>`standard` means that the
    team that doesn't pick a map gets the side choice (only if `skip_veto` is `false`).<br><br>`always_knife` means that
    sides are always determined by a knife-round.<br><br>`never_knife` means that `team1` always starts on CT.<br><br>
    This parameter is ignored if `map_sides` is set for all maps. `standard` and `always_knife` behave similarly (knife)
    when `skip_veto` is `true`.<br><br>**`Default: "standard"`**
13. _Required_<br>The map pool to pick from, as an array of strings (`["de_dust2", "de_nuke"]` etc.), or if `skip_veto`
    is `true`, the order of maps played (limited by `num_maps`).<br><br>You can load maps from workshop collections by
    using the syntax `"workshop/map_id/map_name"`, i.e. `"workshop/1193875520/Old Aztec"`. The name parameter is used to
    present the map in the [map selection](../veto) phase. If you provide maps from the community workshop, you must
    have a [Steam Web API key](https://steamcommunity.com/dev) configured for your server, or the match config will fail
    to load.<br><br>Similarly to teams, you can set this to an object with a `fromfile` property to load a map list from
    a separate file.<br><br>If you use workshop maps, it is recommended that you
    set [`mp_match_end_restart 1`](https://totalcsgo.com/command/mpmatchendrestart) on your server, so a new map does
    not load in case it takes a long time to download a workshop map. You can also set `sv_broadcast_ugc_downloads 1`
    and `sv_broadcast_ugc_download_progress_interval 1` if you want to inform players that a workshop map is being
    downloaded. In the vast majority of cases, this process should only take a few seconds.
14. _Optional_<br>Wrapper for the server's `mp_teamprediction_pct`. This determines the chances of `team1`
    winning.<br><br>**`Default: 0`**
15. _Optional_<br>Wrapper for the server's `mp_teamprediction_txt`.<br><br>**`Default: ""`**
16. _Optional_<br>The team's name. Sets `mp_teamname_1` or `mp_teamname_2`. Printed frequently in chat. If you don't
    define a team name, it will be set to `team_` followed by the name of the captain, i.e. `team_s1mple`.
    <br><br>**`Default: ""`**
17. _Optional_<br>A short version of the team name, used in clan tags in-game (requires
    that [`get5_set_client_clan_tags`](../configuration#get5_set_client_clan_tags) is disabled).
    <br><br>**`Default: ""`**
18. _Optional_<br>The ISO-code to use for the in-game flag of the team. Must be a supported country, i.e. `FR`,`UK`,`SE`
    etc.<br><br>**`Default: ""`**
19. _Optional_<br>The team logo (wraps `mp_teamlogo_1` or `mp_teamlogo_2`), which requires to be on a FastDL in order
    for clients to see.<br><br>**`Default: ""`**
20. _Required_<br>The data for the first team.
21. _Required_<br>The data for the second team.
22. _Optional_<br>Various commands to execute on the server when loading the match configuration. This can be both
    regular server-commands and any [`Get5 configuration parameter`](../configuration),
    i.e. `{"mp_friendlyfire": "0", "get5_max_pauses": "2"}`.<br><br>When the match ends, these parameters will by
    default
    be [reset to the value they had before the match was loaded](../configuration#get5_reset_cvars_on_end).<br><br>You
    should avoid putting server-specific parameters, such as [`get5_server_id`](../configuration#get5_server_id), in
    this property, as these are all written to [backups](../backup) and set when restored from.<br><br>
    **`Default: undefined`**
23. _Optional_<br>Similarly to `players`, this object maps [coaches](../coaching) using their Steam ID and
    name, locking them to the coach slot unless removed using [`get5_removeplayer`](../commands#get5_removeplayer).
    Setting a Steam ID as coach takes precedence over being set as a player.<br><br>Note that
    if [`sv_coaching_enabled`](https://totalcsgo.com/command/svcoachingenabled) is disabled, anyone defined as a coach
    will be considered a regular player for the team instead.<br><br>**`Default: undefined`**
24. _Required_<br>The players on the team.
25. _Optional_<br>Sets the server's `mp_teammatchstat_txt` ConVar, but lets you use `{MAPNUMBER}` and `{MAXMAPS}` as
    variables that get replaced with their integer values. You should **not** set `mp_teammatchstat_txt` yourself, as it
    will be overridden by this parameter.<br><br>**`Default: "Map {MAPNUMBER} of {MAXMAPS}"`**
26. _Optional_<br>The current score in the series, this can be used to give a team a map advantage or used as a manual
    backup method.<br><br>**`Default: 0`**
27. _Optional_<br>Assigns values to `mp_teammatchstat_1` and `mp_teammatchstat_2`, respectively. If you don't set this
    value in a BoX series, it is set to each team's map series score automatically.<br><br>**`Default: ""`**
28. _Optional_<br>Match teams can also be loaded from a separate file, allowing you to easily re-use a match
    configuration for different sets of teams. A `fromfile` value could
    be `"addons/sourcemod/configs/get5/team_nip.json"`, and is always relative to the `csgo` directory. The file should
    contain a valid `Get5MatchTeam` object. You **are** allowed to mix filetypes, so a JSON file can point to
    a `fromfile` that's a KeyValue file and vice-versa. If you provide a `fromfile` property, all other properties are
    ignored and team data is only read from the provided file.
29. _Optional_<br>The name of the spectator team.<br><br>**`Default: "casters"`**
30. _Optional_<br>The spectator/caster Steam IDs and names. Setting a Steam ID as spectator takes precedence over being
    set as a player or coach.
31. _Optional_<br>Determines the starting sides for each map. If this array is shorter than `num_maps`, `side_type` will
    determine the side-behavior of the remaining maps.
    <br><br>**`Default: undefined`**
32. _Optional_<br>If `false`, the entire map list will be played, regardless of score. If `true`, a series will be won
    when the series score for a team exceeds the number of maps divided by two.<br><br>**`Default: true`**
33. _Optional_<br>Determines if coaches must also [`!ready`](../commands#ready).<br><br>**`Default: false`**
34. _Optional_<br>Similarly to teams and map list, spectators may also be loaded from another file.
35. _Required_<br>Similarly to teams and spectators, a map list may also be loaded from another file.
36. _Optional_<br>Allows for a [custom configuration](../veto#custom) of map picks/bans. This must be an array of
    strings consisting of any valid combination of `team1_ban`, `team2_ban`, `team1_pick` and `team2_pick`.
37. _Optional_<br>Whether to configure the match for [Wingman mode](../wingman). If this is enabled, `players_per_team`
    defaults to `2` instead of `5`.<br><br>**`Default: false`**

!!! info "Team assignment priority"

    If you define a Steam ID in more than one location in your match configuration, it will be evaluated in this order
    to determine where to put the player:

    1. Spectator
    2. Coach for `team1`
    3. Coach for `team2`
    4. Player for `team1`
    5. Player for `team2`

    If a player's Steam ID was not found in any of these locations, they will be
    [removed from the server](../configuration#get5_check_auths) unless you are
    in [scrim mode](../getting_started#scrims).

## Examples {: #example }

These examples are identical in the way they would work if loaded.

=== "JSON (recommended)"

    !!! tip "Example only"
        
        `map_sides` would only work with `skip_veto: true`.

    ```json title="addons/sourcemod/get5/astralis_vs_navi_3123.json"
    {
      "match_title": "Astralis vs. NaVi",
      "matchid": "3123",
      "clinch_series": true,
      "num_maps": 3,
      "wingman": false,
      "players_per_team": 5,
      "coaches_per_team": 2,
      "coaches_must_ready": true,
      "min_players_to_ready": 2,
      "min_spectators_to_ready": 0,
      "skip_veto": false,
      "veto_first": "team1",
      "side_type": "standard",
      "spectators": {
        "name": "Blast PRO 2021",
        "players": {
          "76561197987511774": "Anders Blume"
        }
      },
      "maplist": [
        "de_dust2",
        "de_nuke",
        "workshop/1193875520/Old Aztec",
        "de_inferno",
        "de_mirage",
        "de_vertigo",
        "de_ancient",
        "de_overpass"
      ],
      "map_sides": [
        "team1_ct",
        "team2_ct",
        "knife"
      ],
      "team1": {
        "fromfile": "addons/sourcemod/get5/team_navi.json"
      },
      "team2": {
        "name": "Astralis",
        "tag": "Astralis",
        "flag": "DK",
        "logo": "astr",
        "players": {
          "76561197990682262": "Xyp9x",
          "76561198010511021": "gla1ve",
          "76561197979669175": "K0nfig",
          "76561198028458803": "BlameF",
          "76561198024248129": "farlig"
        },
        "coaches": {
          "76561197987144812": "Trace"
        }
      },
      "cvars": {
        "hostname": "Get5 Match #3123",
        "mp_friendly_fire": "0",
        "get5_stop_command_enabled": "0",
        "sm_practicemode_can_be_started": "0"
      }
    }
    ```
    `fromfile` example:
    ```json title="addons/sourcemod/get5/team_navi.json"
    {
      "name": "Natus Vincere",
      "tag": "NaVi",
      "flag": "UA",
      "logo": "navi",
      "players": {
        "76561198034202275": "s1mple",
        "76561198044045107": "electronic",
        "76561198246607476": "b1t",
        "76561198121220486": "Perfecto",
        "76561198040577200": "sdy"
      },
      "coaches": {
        "76561198013523865": "B1ad3"
      }
    }
    ```

    And in TypeScript, using the above interface definition file:
    ```typescript title="Typescript JSON example with Node.js"
    const match_schema: Get5Match = {
        "match_title": "Astralis vs. NaVi",
        "matchid": "3123",
        "clinch_series": true,
        "num_maps": 3,
        "wingman": false,
        "players_per_team": 5,
        "coaches_per_team": 2,
        "coaches_must_ready": true,
        "min_players_to_ready": 2,
        "min_spectators_to_ready": 0,
        "skip_veto": false,
        "veto_first": "team1",
        "side_type": "standard",
        "spectators": {
            "name": "Blast PRO 2021",
            "players": {
                "76561197987511774": "Anders Blume"
            }
        },
        "maplist": [
            "de_dust2",
            "de_nuke",
            "workshop/1193875520/Old Aztec",
            "de_inferno",
            "de_mirage",
            "de_vertigo",
            "de_ancient",
            "de_overpass"
        ],
        "map_sides": ["team1_ct", "team2_ct", "knife"], // Example; would only work with "skip_veto": true
        "team1": {
            "fromfile": "addons/sourcemod/get5/team_navi.json"
        },
        "team2": {
            "name": "Astralis",
            "tag": "Astralis",
            "flag": "DK",
            "logo": "astr",
            "players": {
                "76561197990682262": "Xyp9x",
                "76561198010511021": "gla1ve",
                "76561197979669175": "K0nfig",
                "76561198028458803": "BlameF",
                "76561198024248129": "farlig"
            },
            "coaches": {
                "76561197987144812": "Trace"
            }
        },
        "cvars": {
            "hostname": "Get5 Match #3123",
            "mp_friendly_fire": "0",
            "get5_stop_command_enabled": "0",
            "sm_practicemode_can_be_started": "0"
        }
    }
    
    // And the config file could be placed on the server like this:
    const json = JSON.stringify(match_schema);
    fs.writeFileSync('addons/sourcemod/get5/astralis_vs_navi_3123.json', json);
    ```

=== "KeyValue"

    !!! warning "All strings, no brakes"

        Note that `false` does not exist in the KeyValue format and that all numerical values are wrapped in quotes. The
        empty strings as values in dictionaries (`maplist` and `map_sides`) are also required.
    
    ```cfg title="addons/sourcemod/get5/astralis_vs_navi_3123.cfg"
    "Match"
    {
        "match_title"             "Astralis vs. NaVi"
        "matchid"                 "3123"
        "clinch_series"           "1"
        "num_maps"                "3"
        "wingman"                 "0"
        "players_per_team"        "5"
        "coaches_per_team"        "2"
        "coaches_must_ready"      "1"
        "min_players_to_ready"    "2"
        "min_spectators_to_ready" "0"
        "skip_veto"               "0"
        "veto_first"              "team1"
        "side_type"               "standard"
        "spectators"    
        {
            "name" "Blast PRO 2021"
            "players"
            {
                "76561197987511774" "Anders Blume"
            }
        }
        "maplist"
        {
            "de_dust2"                      ""
            "de_nuke"                       ""
            "workshop/1193875520/Old Aztec" ""
            "de_inferno"                    ""
            "de_mirage"                     ""
            "de_vertigo"                    ""
            "de_ancient"                    ""
            "de_overpass"                   ""
        }
        "map_sides"  // Example; would only work with "skip_veto" "1"
        {
            "team1_ct" ""
            "team2_ct" ""
            "knife"    ""
        }
        "team1"
        {
            "fromfile" "addons/sourcemod/get5/team_navi.cfg"
        }
        "team2"
        {
            "name" "Astralis"
            "tag"  "Astralis"
            "flag" "DK"
            "logo" "astr"
            "players"
            {
                "76561197990682262" "Xyp9x"
                "76561198010511021" "gla1ve"
                "76561197979669175" "K0nfig"
                "76561198028458803" "BlameF"
                "76561198024248129" "farlig"
            }
            "coaches"
            {
                "76561197987144812" "Trace"
            }
        }
        "cvars"
        {
            "hostname"                       "Get5 Match #3123"
            "mp_friendly_fire"               "0"
            "get5_stop_command_enabled"      "0"
            "sm_practicemode_can_be_started" "0"
        }
    }
    ```
    `fromfile` example:
    ```cfg title="addons/sourcemod/get5/team_navi.cfg"
    "Team"
    { 
        "name" "Natus Vincere"
        "tag"  "NaVi"
        "flag" "UA"
        "logo" "navi"
        "players"
        {
            "76561198034202275" "s1mple"
            "76561198044045107" "electronic"
            "76561198246607476" "b1t"
            "76561198121220486" "Perfecto"
            "76561198040577200" "sdy"
        }
        "coaches"
        {
            "76561198013523865" "B1ad3"
        }
    }
    ```
