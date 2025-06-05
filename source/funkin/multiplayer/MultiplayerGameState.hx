package funkin.multiplayer;

import flixel.util.FlxSignal;
import funkin.Highscore.Tallies;
import funkin.multiplayer.NetworkManager;

enum MultiplayerGameMode
{
  VERSUS; // Head-to-head competition
  COOPERATIVE; // Play together, dunno how tf that would work (maybe some kind of boss fight mode?)
}

enum MultiplayerGamePhase
{
  WAITING; // Waiting for players
  SONG_LOADING; // Loading song assets
  COUNTDOWN; // 3-2-1 countdown
  SONG_PLAYING; // Song in progress
  SONG_COMPLETE; // Song finished, showing results
  DISCONNECTED; // Connection lost
}

typedef MultiplayerResult =
{
  winner:String,
  localPlayerData:MultiplayerPlayerData,
  remotePlayerData:MultiplayerPlayerData,
  gameMode:MultiplayerGameMode
}

/**
 * Manages multiplayer game state synchronization
 * Handles score sync, song progress, and win conditions
 */
class MultiplayerGameState
{
  public static var instance(get, never):MultiplayerGameState;
  static var _instance:Null<MultiplayerGameState> = null;

  static function get_instance():MultiplayerGameState
  {
    if (_instance == null) _instance = new MultiplayerGameState();
    return _instance;
  }

  // Game state
  public var gameMode(default, null):MultiplayerGameMode = VERSUS;
  public var gamePhase(default, null):MultiplayerGamePhase = WAITING;

  // Player data
  public var localPlayerData(default, null):MultiplayerPlayerData;
  public var remotePlayerData(default, null):MultiplayerPlayerData;

  // Signals
  public var onGameStateChanged(default, null):FlxTypedSignal<MultiplayerGamePhase->Void> = new FlxTypedSignal();
  public var onPlayerScoreUpdated(default, null):FlxTypedSignal<String->Tallies->Void> = new FlxTypedSignal();
  public var onGameEnded(default, null):FlxTypedSignal<MultiplayerResult->Void> = new FlxTypedSignal();

  // Synchronization
  var syncTimer:flixel.util.FlxTimer;
  var lastSyncTime:Float = 0.0;

  public function new()
  {
    localPlayerData = new MultiplayerPlayerData(NetworkManager.instance.localPlayerId);
    remotePlayerData = new MultiplayerPlayerData("");

    setupReplication();
  }

  function setupReplication():Void
  {
    var replicationManager = ReplicationManager.instance;

    // Local player score (authority: client)
    replicationManager.registerProperty("localPlayer", "score", () -> localPlayerData.tallies.score, (value) ->
      {/* Read-only for remote */},
      {
        authority: AUTHORITY_CLIENT,
        frequency: 10.0, // 10Hz for score updates
        interpolate: false,
        reliable: true
      });

    // Health/combo (higher frequency for smooth visuals)
    replicationManager.registerProperty("localPlayer", "combo", () -> localPlayerData.tallies.combo, (value) ->
      {/* Read-only for remote */},
      {
        authority: AUTHORITY_CLIENT,
        frequency: 30.0,
        interpolate: false,
        reliable: false
      });

    // Game phase (authority: host)
    replicationManager.registerProperty("gameState", "phase", () -> gamePhase, (value) -> setGamePhase(value),
      {
        authority: AUTHORITY_HOST,
        frequency: 5.0,
        interpolate: false,
        reliable: true
      });
  }

  public function startMultiplayerSession(mode:MultiplayerGameMode):Void
  {
    gameMode = mode;
    setGamePhase(SONG_LOADING);

    syncTimer = new flixel.util.FlxTimer();
    syncTimer.start(0.1, syncGameState, 0); // 10Hz sync
  }

  public function handleRemoteGameState(message:NetworkMessage):Void
  {
    switch (message.data.type)
    {
      case "score_update":
        updateRemotePlayerScore(message.data);

      case "phase_change":
        setGamePhase(message.data.phase);

      case "game_end":
        handleGameEnd(message.data);
    }
  }

  function updateRemotePlayerScore(data:Dynamic):Void
  {
    remotePlayerData.playerId = data.playerId;
    remotePlayerData.tallies = data.tallies;

    onPlayerScoreUpdated.dispatch(remotePlayerData.playerId, remotePlayerData.tallies);
  }

  public function updateLocalPlayerScore(tallies:Tallies):Void
  {
    localPlayerData.tallies = tallies;

    NetworkManager.instance.sendMessage(
      {
        type: GAME_STATE,
        senderId: NetworkManager.instance.localPlayerId,
        timestamp: NetworkManager.instance.getNetworkTime(),
        data:
          {
            type: "score_update",
            playerId: localPlayerData.playerId,
            tallies: tallies
          }
      });

    onPlayerScoreUpdated.dispatch(localPlayerData.playerId, tallies);
  }

  function setGamePhase(newPhase:MultiplayerGamePhase):Void
  {
    if (gamePhase == newPhase) return;

    var oldPhase = gamePhase;
    gamePhase = newPhase;

    trace('[MULTIPLAYER] Game phase: $oldPhase -> $newPhase');
    onGameStateChanged.dispatch(newPhase);

    if (NetworkManager.instance.isHost)
    {
      NetworkManager.instance.sendMessage(
        {
          type: GAME_STATE,
          senderId: NetworkManager.instance.localPlayerId,
          timestamp: NetworkManager.instance.getNetworkTime(),
          data:
            {
              type: "phase_change",
              phase: newPhase
            }
        });
    }
  }

  public function startSong():Void
  {
    setGamePhase(SONG_PLAYING);
  }

  public function endSong():Void
  {
    setGamePhase(SONG_COMPLETE);
    calculateResult();
  }

  function calculateResult():Void
  {
    var result:MultiplayerResult =
      {
        winner: determineWinner(),
        localPlayerData: localPlayerData,
        remotePlayerData: remotePlayerData,
        gameMode: gameMode
      };

    onGameEnded.dispatch(result);

    NetworkManager.instance.sendMessage(
      {
        type: GAME_STATE,
        senderId: NetworkManager.instance.localPlayerId,
        timestamp: NetworkManager.instance.getNetworkTime(),
        data:
          {
            type: "game_end",
            result: result
          }
      });
  }

  function determineWinner():String
  {
    switch (gameMode)
    {
      case VERSUS:
        if (localPlayerData.tallies.score > remotePlayerData.tallies.score) return localPlayerData.playerId;
        else if (remotePlayerData.tallies.score > localPlayerData.tallies.score) return remotePlayerData.playerId;
        else
          return "tie";

      case COOPERATIVE:
        return "both"; // Both players win in co-op, if not dead

      default:
        return "none";
    }
  }

  function handleGameEnd(data:Dynamic):Void
  {
    var result:MultiplayerResult = data.result;
    onGameEnded.dispatch(result);
  }

  function syncGameState(timer:flixel.util.FlxTimer):Void
  {
    // sync game state for custom mods later on ig
  }

  public function cleanup():Void
  {
    if (syncTimer != null)
    {
      syncTimer.cancel();
      syncTimer = null;
    }

    setGamePhase(WAITING);
  }
}

class MultiplayerPlayerData
{
  public var playerId:String;
  public var tallies:Tallies;
  public var isConnected:Bool = true;
  public var ping:Float = 0.0;

  public function new(playerId:String)
  {
    this.playerId = playerId;
    this.tallies = new Tallies();
  }
}
