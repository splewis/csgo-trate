# :material-format-list-text: Match Schema

## What is it?

A match configuration file contains everything that Get5 and your server needs to host a series. This includes locking
players to their correct team and side, setting the map(s) and configuring the game rules.

Two files ship with Get5 that give a general idea of what can be included in a match config. A Valve KeyValue
format can be found [here](https://github.com/splewis/get5/blob/master/configs/get5/example_match.cfg), and a JSON
format can be found [here](https://github.com/splewis/get5/blob/master/configs/get5/example_match.json). In this
documentation, we'll go through what each value means, but do note that **only the values** `team1` and `team2` are
required to start a match. Reasonable defaults are used for the other values (Bo3 series,
5v5, empty strings for team names, etc.). We recommend using the JSON format whenever possible, as JSON has way
better support in various programming languages than Valve's KeyValue format (which essentially has none).

## The schema

```typescript title="TypeScript interface definition of a match configuration"
type Get5PlayerSteamID = string; // (8)
type Get5PlayerSet = { [key: Get5PlayerSteamID]: string }; // (9)

interface Get5MatchTeam {
    "players": Get5PlayerSet, // (24)
    "coaches": Get5PlayerSet // (23)
    "name": string, // (16)
    "tag": string, // (17)
    "flag": string, // (18)
    "logo": string, // (19)
    "series_score": number, // (26)
    "matchtext": string // (27)
}

interface Get5MatchTeamFromFile {
    "fromfile": string // (28)
}

interface Get5Match {
    "match_title": string // (28)
    "matchid": string, // (1)
    "num_maps": number, // (2)
    "players_per_team": number, // (3)
    "coaches_per_team": number, // (4)
    "min_players_to_ready": number, // (5)
    "min_spectators_to_ready": number, // (6)
    "skip_veto": boolean, // (7),
    "veto_first": "team1" | "team2", // (11)
    "side_type": "standard" | "always_knife" | "never_knife", // (12)
    "spectators": { // (10)
        "name": string // (29)
        "players": Get5PlayerSet // (30)
    },
    "map_list": [string], // (13)
    "favored_percentage_team1": number, // (14)
    "favored_percentage_text": string, // (15)
    "team1": Get5MatchTeam | Get5MatchTeamFromFile, // (20)
    "team2": Get5MatchTeam | Get5MatchTeamFromFile, // (21)
    "cvars": { [key: string]: string } // (22)
}
```

1. _Optional_ - The ID of the match. This determines the `matchid` parameter in all the forwards and events.
   **`Default: ""`**
2. _Optional_ - The number of maps to play in the series. **`Default: 3`**
3. _Optional_ - The number of players per team. **`Default: 5`**
4. _Optional_ - The maximum number of coaches per team. **`Default: 2`**
5. _Optional_ - The minimum number of players of each team that must type [`!ready`](../commands/#ready) for the game to
   begin. **`Default: 1`**
6. _Optional_ - The minimum number of spectators that must be [`!ready`](../commands/#ready) for the game to begin.
   **`Default: 0`**
7. _Optional_ - Whether to skip the veto phase. If set to `true`, `team1` will start on CT. If `false`, sides are
   determined by `side_type`. **`Default: false`**
8. A player's :material-steam: Steam ID. This can be in any format, but we recommend a string representation of SteamID
   64, i.e. `"76561197987713664"`.
9. Players are represented each with a mapping of `Get5PlayerSteamID -> PlayerName` as a key-value dictionary. The name
   is optional and should be set to an empty string to let players decide their own name.
10. _Optional_ - The spectators to allow into the game. If not defined, spectators cannot join the
    game. **`Default: undefined`**
11. _Optional_ - The team that vetoes first. **`Default: team1`**
12. _Optional_ - The method used to determine sides. `standard` means that the team that doesn't pick a map gets the
    side choice. `always_knife` means that sides are always determined by a knife-round and `never_kninfe` means that
    `team1` always starts on CT. **`Default: standard`**
13. _Required_ - The map pool to pick from, as an array of strings (`["de_dust2", "de_nuke"]` etc.), or if `skip_veto`
    is `true`, the order of maps played (limited by `num_maps`). **This should always be odd-sized if using the in-game
    veto system.**
14. _Optional_ - Wrapper for the server's `mp_teamprediction_pct`. This determines the chances of `team1`
    winning. **`Default: 0`**
15. _Optional_ - Wrapper for the server's `mp_teamprediction_txt`. **`Default: ""`**
16. _Required_ - The team's name. Sets `mp_teamname_1` or `mp_teamname_2`. Printed frequently in chat.
17. _Optional_ - A short version of the team name, used in clan tags in-game (
    if [`get5_set_client_clan_tags`](../configuration#get5_set_client_clan_tags) is disabled). **`Default: ""`**
18. _Optional_ - The ISO-code to use for the in-game flag of the team. Must be a supported country, i.e. `FR`, `UK`
    , `SE` etc. **`Default: ""`**
19. _Optional_ - The team logo (wraps `mp_teamlogo_1` or `mp_teamlogo_2`), which requires to be on a FastDL in order for
    clients to see. **`Default: ""`**
20. _Required_ - The data for the first team.
21. _Required_ - The data for the second team.
22. _Optional_ - Various commands to execute on the server when loading the match configuration. This can be both
    regular server-commands and any [`Get5 configuration parameter`](configuration.md),
    i.e. `{"hostname": "Match #3123 - Astralis vs. NaVi"}`. **`Default: undefined`**
23. _Optional_ - Similarly to `players`, this object maps coaches using their Steam ID and
    name. **`Default: undefined`**
24. _Required_ - The players on the team.
25. _Optional_ - Wrapper of the server's `mp_teammatchstat_txt` cvar, but can use `{MAPNUMBER}` and `{MAXMAPS}` as
    variables that get replaced with their integer values. In a BoX series, you probably don't want to set this since
    Get5 automatically sets `mp_teamscore` cvars for the current series score, and take the place of
    the `mp_teammatchstat` cvars. **`Default: Map {MAPNUMBER} of {MAXMAPS}`**
26. _Optional_ - The current score in the series, this can be used to give a team a map advantage or used as a manual
    backup method. **`Default: 0`**
27. _Optional_ - Wraps `mp_teammatchstat_1` and `mp_teammatchstat_2`. You probably don't want to set this, in BoX
    series, `mp_teamscore` cvars are automatically set and take the place of the `mp_teammatchstat_x`
    cvars. **`Default: ""`**
28. Match teams can also be loaded from a separate file, allowing you to easily re-use a match configuration for
    different sets of teams.
    A `fromfile` value could be `"addons/sourcemod/configs/get5/team_nip.json"`, and that file should contain a valid
    `Get5MatchTeam` object.
29. _Optional_ - The name of the spectator team. **`Default: casters`**
30. _Optional_ - The spectator/caster Steam IDs and names.

!!! warning "SteamID64 in `.cfg` files"

    You may have trouble using SteamID64 inside a KeyValue (`.cfg`) match config. The Valve KeyValue parser will
    interpret any integer string as an integer (even if read as a string), and this value will
    not fit inside a SourceMod-internal 32-bit cell. For `.cfg`, use the regular steamID, i.e. `STEAM_0:0:13723968`.
    This is *not* a problem if you use the JSON format. Also, remember not to pass SteamID 64 as numbers, as they are
    too large to reliably handle in JavaScript; always enclose them in quotes.

#### Example

```typescript title="JSON example with Node.SJ"
const match_schema: Match = {
    "match_title": "Astralis vs. NaVi",
    "matchid": "3123",
    "num_maps": 3,
    "players_per_team": 5,
    "coaches_per_team": 2,
    "min_players_to_ready": 2,
    "min_spectators_to_ready": 0,
    "skip_veto": false,
    "veto_first": "team1",
    "side_type": "always_knife",
    "spectators": {
        "name": "Blast PRO 2021",
        "players": {
            "76561197987511774": "Anders Blume"
        }
    },
    "map_list": ["de_dust2", "de_nuke", "de_inferno", "de_mirage", "de_vertigo", "de_ancient", "de_overpass"],
    "team1": {
        "name": "Natus Vincere",
        "tag": "NaVi",
        "flag": "UA",
        "logo": "nv",
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
    },
    "team2": {
        "name": "Astralis",
        "tag": "Astralis",
        "flag": "DK",
        "logo": "as",
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
        "get5_end_match_on_empty_server": "0",
        "get5_stop_command_enabled": "0"
    }
}

// And the config file could be placed on the server like this:
const json = JSON.stringify(match_schema);
fs.writeFileSync('addons/sourcemod/get5/astralis_vs_navi_3123.json', json);
```
