get5
===========================

[![Build status](http://ci.splewis.net/job/get5/badge/icon)](http://ci.splewis.net/job/get5/)
[![GitHub Downloads](https://img.shields.io/github/downloads/splewis/get5/total.svg?style=flat-square&label=Downloads)](https://github.com/splewis/get5/releases/latest)

**Status: Supported, actively developed.**

Get5 is a standalone [SourceMod](http://www.sourcemod.net/) plugin for CS:GO servers for running matches. It is originally based on [pugsetup](https://github.com/splewis/csgo-pug-setup) and is inspired by [eBot](https://github.com/deStrO/eBot-CSGO).

The core idea behind its use is all match details being fully defined in a single config file. Check out [this example config](configs/get5/example_match.cfg). Its main target use-case is tournaments and leagues (online or LAN). All that is required of the server-admins is to load match config file to the server and the match should run without any more manual actions from the admins. This plugin is not invasive - most of its functionality is built to work within how the CS:GO server normally operates, not replacing its functionality. **No, it is not recommended for your new matchmaking service. It is intended for competitive play, not pickup games.**

It is meant to be relatively easy to use for tournament admins.

Features of this include:
- Locking players to the correct team by their [Steam ID](https://github.com/splewis/get5/wiki/Authentication-and-Steam-IDs)
- In-game [map veto](https://github.com/splewis/get5/wiki/Map-Vetoes) support from the match's maplist
- Support for multi-map series (Bo1, Bo2, Bo3, Bo5, etc.)
- Warmup and !ready system for each team
- Automatic GOTV demo recording
- [Advanced backup system](https://github.com/splewis/get5/wiki/Match-backups) built on top of valve's backup system
- Knifing for sides
- [Pausing support](https://github.com/splewis/get5/wiki/Pausing)
- Coaching support
- Automatically executing match config files
- Automatically setting team names/logos/match text values for spectator/GOTV clients
- [Stats collection](https://github.com/splewis/get5/wiki/Stats-system) and optional MySQL result/stats upload
- Allows lightweight usage for [scrims](https://github.com/splewis/get5/wiki/Using-get5-for-scrims)
- Has its own [event logging](https://github.com/splewis/get5/wiki/Event-logs) system you can interface with

Get5 also aims to make it easy to build automation for it. Commands are added so that a remote server can manage get5, collect stats, etc. The [get5 web panel](https://github.com/splewis/get5-web) is an (functional) proof-of-concept for this.

## Download and Installation

#### Requirements
You must have sourcemod installed on the game server. You can download it at http://www.sourcemod.net/downloads.php. Note that sourcemod also requires MetaMod:Source to be on the server. You can download it at http://www.metamodsource.net/downloads.php. You must have a 1.9+ build of sourcemod.

#### Download
Download a release package from the [releases section](https://github.com/splewis/get5/releases) or a [the latest development build](http://ci.splewis.net/job/get5/lastSuccessfulBuild/).

Release and development builds are currently compiled against sourcemod 1.10 and should work on sourcemod 1.10 or later.

#### Installation
Extract the download archive into the csgo/ directory on the server. Once the plugin first loads on the server, you can edit general get5 cvars in the autogenerated ``cfg/sourcemod/get5.cfg``. You should also have 3 config files: ``cfg/get5/warmupcfg``, ``cfg/get5/knife.cfg``, ``cfg/get5/live.cfg``. These can be edited, but I recommend **not** blindly pasting another config in (e.g. ESL, CEVO). Configs that execute warmup commands (``mp_warmup_end``, for example) **will** cause problems.

If you need more help, see the [step-by-step guide in the wiki](https://github.com/splewis/get5/wiki/Step-by-step-installation-guide).

#### Optional steps/plugins

The get5 releases contain 2 additional plugins, disabled by default. They are in ``addons/sourcemod/plugins/disabled``. To enable one, move it up a directory to ``addons/sourcemod/plugins``.

##### get5_apistats

``get5_apistats`` is for integration with the [get5 web panel](https://github.com/splewis/get5-web). You don't need it unless you're using the web panel. Note you need the [Steamworks](https://forums.alliedmods.net/showthread.php?t=229556) extension for this plugin.

**NOTE**: The HTTP API requests this plugin sends are **not** part of a public API. They are the communication between this plugin and the [get5-web](https://github.com/splewis/get5-web) project; you should not rely on the API being stable. If you're a developer writing your own server listening to get5_apistats, consider forking the get5_apistats plugin and renaming it to something else.

##### get5_mysqlstats

``get5_mysqlstats``: is an optional plugin for recording match stats. To use it, create a "get5" section in your ``addons/sourcemod/configs/databases.cfg`` file and use [these MySQL commands](misc/import_stats.sql) to create the tables. You can also set ``get5_mysql_force_matchid`` to a matchid to make get5 ignore the matchid in match configs, and use the one in the cvar. Otherwise, the matchid will be set based on matchid returned by MySQL from the SQL ``insert`` statement.


## Quickstart

To use get5, you generally create a [match config](https://github.com/splewis/get5#match-schema). In this file, you'll set up the match - what players, what map(s), etc.


Once you create the match config anywhere under the server's ``csgo`` directory, run ``get5_loadmatch <file>`` in the server console. Everything will happen automatically after that.

If you don't want to create a match config, you can set ``get5_check_auths 0`` in ``cfg/sourcemod/get5.cfg`` and then run the ``get5_creatematch`` command once all players are in the server.

Alternatively, you can also up your server for [scrims](https://github.com/splewis/get5/wiki/Using-get5-for-scrims) by creating a scrim template specifying your team and run ``get5_scrim`` in console.

The ``!get5`` command in-game will let you run the ``get5_creatematch`` and ``get5_scrim`` via a simple menu.


## Commands

Generally admin commands will have a ``get5_`` prefix and must be used in console. Commands intended for general player usage are created with ``sm_`` prefixes, which means sourcemod automtically registers a ``!`` chat version of the command. (For example: sm_ready in console is equivalent to !ready in chat)

Some client commands are available also for admin usage. For example, sm_pause and sm_unpause will force pauses if executed by the server (e.g., through rcon).

#### Client Commands (these can be typed by all players in chat)
- ``!ready``: marks a client's team as ready to begin
- ``!unready``: marks a client's team as not-ready
- ``!pause``: requests a freezetime pause
- ``!unpause``: requests an unpause, requires the other team to confirm
- ``!tech``: requests a technical pause (technical pauses have no time limit or max number of uses)
- ``!coach``: moves a client to coach for their team
- ``!stay``: elects to stay after a knife round win
- ``!swap``: elects to swap after a knife round win
- ``!stop``: asks to reload the last match backup file, requires other team to confirm
- ``!forceready``: force readies your team, letting your team start regardless of player numbers/whether they are ready

#### Server/Admin Commands (meant to be used by admins in console)
- ``get5_loadmatch``: loads a match config file (JSON or keyvalues) relative from the ``csgo`` directory
- ``get5_loadbackup``: loads a get5 backup file
- ``get5_loadteam``: loads a team section from a file into a team
- ``get5_loadmatch_url``: loads a remote (JSON formatted) match config by sending a HTTP(S) GET to the given url, this requires the [Steamworks](https://forums.alliedmods.net/showthread.php?t=229556) extension. When specifying an url with http:// or https:// in front, you have to put it in quotation marks. 
- ``get5_endmatch``: force ends the current match
- ``get5_creatematch``: creates a Bo1 match with the current players on the server on the current map
- ``get5_scrim``: creates a Bo1 match with the using settings from ``configs/get5/scrim_template.cfg``
- ``get5_addplayer``: adds a steamid to a team (any format for steamid)
- ``get5_removeplayer``: removes a steamid from all teams (any format for steamid)
- ``get5_forceready``: marks all teams as ready
- ``get5_dumpstats``: dumps current match stats to a file
- ``get5_status``: replies with JSON formatted match state (available to all clients)
- ``get5_listbackups``: lists backup files for the current matchid or a given matchid

#### Other commands

- ``!get5`` opens a menu that wraps some common commands. It's mostly intended for people using scrim settings, and has menu buttons for starting a scrim, force-starting, force-ending, adding a ringer, and loading the most recent backup file.

## Match Schema

See the example config in [Valve KeyValues format](configs/get5/example_match.cfg) or [JSON format](configs/get5/example_match.json) to learn how to format the configs. Both example files contain equivalent match data.

Of the below fields, only the ``team1`` and ``team2`` fields are actually required. Reasonable defaults are used for entires (bo3 series, 5v5, empty strings for team names, etc.)

- ``matchid``: a string matchid used to identify the match
- ``num_maps``: number of maps in the series. This must be an odd number or 2.
- ``maplist``: list of the maps in use (an array of strings in JSON, mapnames as keys for KeyValues), you should always use an odd-sized maplist
- ``skip_veto``: whether the veto will be skipped and the maps will come from the maplist (in the order given)
- ``veto_first``: either "team1", or "team2". If not set, or set to any other value, team 1 will veto first.
- ``side_type``: either "standard", "never_knife", or "always_knife"; standard means the team that doesn't pick a map gets the side choice, never_knife means team1 is always on CT first, and always knife means there is always a knife round
- ``players_per_team``: maximum players per team (doesn't include a coach spot, default: 5)
- ``min_players_to_ready``: minimum players a team needs to be able to ready up (default: 1)
- ``favored_percentage_team1``: wrapper for ``mp_teamprediction_pct``
- ``favored_percentage_text`` wrapper for ``mp_teamprediction_txt``
- ``cvars``: cvars to be set during the match warmup/knife round/live state
- ``spectators``: see the team schema below (only the ``players`` and ``name`` sections are used for spectators)
- ``team1``: see the team schema below
- ``team2``: see the team schema below

Fields you may use, you aren't generally needed to:
- ``match_title``: wrapper on the ``mp_teammatchstat_txt`` cvar, but can use {MAPNUMBER} and {MAXMAPS} as variables that get replaced with their integer values. In a BoX series, you probably don't want to set this since get5 automatically sets mp_teamscore cvars for the current series score, and take the place of the mp_teammatchstat cvars.

#### Team Schema
Only ``name`` and ``players`` are required.

- ``name``: team name (wraps ``mp_teamname_1`` and is displayed often in chat messages)
- ``tag``: team tag (or short name), this replaces client "clan tags"
- ``flag``: team flag (2 letter country code, wraps ``mp_teamflag_1``)
- ``logo`` team logo (wraps ``mp_teamlogo_1``)
- ``players``: list of Steam id's for users on the team (not used if ``get5_check_auths`` is set to 0). You can also force player names in here; in JSON you may use either an array of steamids or a dictionary of steamids to names.
- ``series_score``: current score in the series, this can be used to give a team a map advantage or used as a manual backup method, defaults to 0
- ``matchtext``: wraps ``mp_teammatchstat_1``, you probably don't want to set this, in BoX series mp_teamscore cvars are automatically set and take the place of the mp_teammatchstat cvars

There is advice on handling these match configs in [the wiki](https://github.com/splewis/get5/wiki/Managing-match-configs).

Instead of the above fields, you can also use "fromfile" and a filename, where that file contains the other above fields. This is available for both json and keyvalue format.s

## ConVars
Note: these are auto-executed on plugin start by the auto-generated (the 1st time the plugin starts) file ``cfg/sourcemod/get5.cfg``.

You should either set these in the above file, or in the match config's ``cvars`` section. Note: cvars set in the ``cvars`` section will override other settings. Please see [the wiki](https://github.com/splewis/get5/wiki/Full-list-of-get5-cvars) for a full list of cvars. You may also just look at the ``cfg/sourcemod/get5.cfg`` file directly on your server and see the cvar descriptions and values in the autogenerated file.

## API for developers

Get5 can be interacted with in several ways. At a glance:

1. You can write another sourcemod plugin that uses the [get5 natives and forwards](scripting/include/get5.inc). This is exactly what the [get5_apistats](scripting/get5_apistats.sp) and [get5_mysqlstats](get5_mysqlstats.sp) plugins do. Considering starting from those plugin and making any changes you want (forking the get5 plugin itself is strongly discouraged; but just making another plugin using the get5 plugin api like get5_apistats does is encouraged).

1. You can read [event logs](https://github.com/splewis/get5/wiki/Event-logs) from a file on disk (set by ``get5_event_log_format``), through a RCON
connection to the server console since they are output there, or through another sourcemod plugin (see #1).

1. You can read the [stats](https://github.com/splewis/get5/wiki/Stats-system) get5 collects from a file on disk (set by ``get5_stats_path_format``), or through another sourcemod plugin (see #1).

1. You can execute the ``get5_loadmatch`` command or ``get5_loadmatch_url`` commands via another plugin or via a RCON connection to begin matches. Of course, you could execute any get5 command you want as well.

## Other things

### Reporting bugs

Please make a [github issue](https://github.com/splewis/get5/issues) and fill out as much information as possible. Reproducible steps and a clear version number will help tremendously!

### Contributions

Pull requests are welcome. Please follow the general coding formatting style as much as possible. If you're concerned about a pull request not being merged, please feel free to make an  [issue](https://github.com/splewis/get5/issues) and inquire if the feature is worth adding.
