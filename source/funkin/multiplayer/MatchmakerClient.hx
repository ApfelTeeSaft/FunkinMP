package funkin.multiplayer;

import flixel.util.FlxSignal;
import haxe.Http;
import haxe.Json;

typedef MatchPreferences =
{
  region:String,
  skillLevel:String,
  songDifficulty:String,
  gameMode:String
}

typedef MatchInfo =
{
  matchId:String,
  players:Array<PlayerInfo>,
  hostInfo:ConnectionInfo
}

typedef PlayerInfo =
{
  playerId:String,
  username:String,
  skillRating:Float
}

typedef ConnectionInfo =
{
  ip:String,
  port:Int
}

typedef MatchmakerResponse =
{
  status:String,
  ?matchInfo:MatchInfo,
  ?message:String
}

typedef MatchmakingSession =
{
  sessionId:String,
  preferences:MatchPreferences,
  startTime:Float
}

/**
 * Handles matchmaking through a central server
 * Players can find each other and exchange connection info
 */
class MatchmakerClient
{
  public static var instance(get, never):MatchmakerClient;
  static var _instance:Null<MatchmakerClient> = null;

  static function get_instance():MatchmakerClient
  {
    if (_instance == null) _instance = new MatchmakerClient();
    return _instance;
  }

  static final MATCHMAKER_URL = "http://127.0.0.1/api";

  public var onMatchFound(default, null):FlxTypedSignal<MatchInfo->Void> = new FlxTypedSignal();
  public var onMatchmakingFailed(default, null):FlxTypedSignal<String->Void> = new FlxTypedSignal();

  var currentSession:MatchmakingSession = null;
  var isSearching:Bool = false;

  public function new() {}

  public function findMatch(preferences:MatchPreferences):Void
  {
    if (isSearching) return;

    isSearching = true;

    var request = new Http(MATCHMAKER_URL + "/find-match");
    request.setPostData(Json.stringify(
      {
        playerId: NetworkManager.instance.localPlayerId,
        preferences: preferences,
        version: Constants.VERSION
      }));

    request.onData = function(data:String) {
      try
      {
        var response:MatchmakerResponse = Json.parse(data);
        handleMatchmakerResponse(response);
      }
      catch (e:Dynamic)
      {
        onMatchmakingFailed.dispatch("Failed to parse matchmaker response");
      }
    };

    request.onError = function(error:String) {
      isSearching = false;
      onMatchmakingFailed.dispatch("Network error: " + error);
    };

    request.request(true);
  }

  function handleMatchmakerResponse(response:MatchmakerResponse):Void
  {
    isSearching = false;

    switch (response.status)
    {
      case "match_found":
        var matchInfo:MatchInfo = response.matchInfo;
        onMatchFound.dispatch(matchInfo);

      case "searching":
        new flixel.util.FlxTimer().start(2.0, function(_) {
          if (!isSearching) findMatch(currentSession.preferences);
        });

      case "error":
        onMatchmakingFailed.dispatch(response.message ?? "Unknown matchmaker error");
    }
  }

  public function cancelSearch():Void
  {
    if (!isSearching) return;

    isSearching = false;

    var request = new Http(MATCHMAKER_URL + "/cancel-search");
    request.setPostData(Json.stringify(
      {
        playerId: NetworkManager.instance.localPlayerId
      }));
    request.request(true);
  }

  public function reportConnectionResult(matchId:String, success:Bool):Void
  {
    var request = new Http(MATCHMAKER_URL + "/report-connection");
    request.setPostData(Json.stringify(
      {
        matchId: matchId,
        playerId: NetworkManager.instance.localPlayerId,
        success: success
      }));
    request.request(true);
  }
}
