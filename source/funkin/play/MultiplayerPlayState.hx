package funkin.play;

import funkin.play.PlayState;
import funkin.ui.multiplayer.MultiplayerPlayStateOverlay;
import funkin.multiplayer.*;
import funkin.multiplayer.MultiplayerInputManager.InputEvent;
import funkin.multiplayer.MultiplayerInputManager.InputAction;
import funkin.multiplayer.NetworkManager.NetworkMessage;

/**
 * Extended PlayState for multiplayer functionality
 * Handles synchronized gameplay and score tracking
 */
class MultiplayerPlayState extends PlayState
{
  var multiplayerOverlay:MultiplayerPlayStateOverlay;
  var lastSyncTime:Float = 0.0;
  var syncInterval:Float = 1.0 / 20.0; // 20Hz sync

  override function create():Void
  {
    super.create();

    multiplayerOverlay = new MultiplayerPlayStateOverlay();
    add(multiplayerOverlay);

    MultiplayerGameState.instance.startSong();

    MultiplayerInputManager.instance.onRemoteInput.add(handleRemoteInput);

    trace('[MULTIPLAYER] Multiplayer PlayState initialized');
  }

  override function update(elapsed:Float):Void
  {
    NetworkManager.instance.update(elapsed);
    ReplicationManager.instance.update(elapsed);

    MultiplayerInputManager.instance.captureLocalInput(controls);

    processRemoteInputs();

    super.update(elapsed);

    if (Conductor.instance.songPosition - lastSyncTime >= syncInterval)
    {
      syncMultiplayerState();
      lastSyncTime = Conductor.instance.songPosition;
    }
  }

  function processRemoteInputs():Void
  {
    var currentFrame = Conductor.instance.currentStep;
    var remoteInputs = MultiplayerInputManager.instance.getInputsForFrame(currentFrame, NetworkManager.instance.remotePlayerId);

    // Apply remote player inputs (could be used for co-op modes)
    for (input in remoteInputs)
    {
      handleRemoteInputAction(input);
    }
  }

  function handleRemoteInput(inputEvent:InputEvent):Void
  {
    // Store for processing on the correct frame
    // Deprecated: The input manager handles this automatically
  }

  function handleRemoteInputAction(action:InputAction):Void
  {
    // For versus mode, we might just want to track but not apply remote inputs
    // For co-op mode, we'd apply them to shared game state

    switch (action)
    {
      case NOTE_LEFT_PRESS:
        trace('[MULTIPLAYER] Remote player hit left note');
      case NOTE_DOWN_PRESS:
        trace('[MULTIPLAYER] Remote player hit down note');
      case NOTE_UP_PRESS:
        trace('[MULTIPLAYER] Remote player hit up note');
      case NOTE_RIGHT_PRESS:
        trace('[MULTIPLAYER] Remote player hit right note');
      default:
        // other shit
    }
  }

  function updateMultiplayerScore(tallies:funkin.Highscore.Tallies):Void
  {
    multiplayerOverlay.updateLocalScore(tallies);
  }

  function syncMultiplayerState():Void
  {
    NetworkManager.instance.sendMessage(
      {
        type: GAME_STATE,
        senderId: NetworkManager.instance.localPlayerId,
        timestamp: NetworkManager.instance.getNetworkTime(),
        data:
          {
            type: "sync",
            songPosition: Conductor.instance.songPosition,
            currentStep: Conductor.instance.currentStep,
            currentBeat: Conductor.instance.currentBeat
          }
      });
  }

  override function endSong(rightGoddamnNow:Bool = false):Void
  {
    super.endSong(rightGoddamnNow);

    MultiplayerGameState.instance.endSong();
  }

  function onMultiplayerCountdownStart():Void
  {
    if (NetworkManager.instance.isHost)
    {
      NetworkManager.instance.sendMessage(
        {
          type: GAME_STATE,
          senderId: NetworkManager.instance.localPlayerId,
          timestamp: NetworkManager.instance.getNetworkTime(),
          data:
            {
              type: "countdown_start"
            }
        });
    }
  }

  function onMultiplayerCountdownEnd():Void
  {
    if (NetworkManager.instance.isHost)
    {
      NetworkManager.instance.sendMessage(
        {
          type: GAME_STATE,
          senderId: NetworkManager.instance.localPlayerId,
          timestamp: NetworkManager.instance.getNetworkTime(),
          data:
            {
              type: "song_start",
              startTime: NetworkManager.instance.getNetworkTime() + 0.1
            }
        });
    }
  }

  public function handleNetworkMessage(message:NetworkMessage):Void
  {
    switch (message.data.type)
    {
      case "countdown_start":
        if (!NetworkManager.instance.isHost)
        {
          startCountdown();
        }

      case "song_start":
        if (!NetworkManager.instance.isHost)
        {
          var startTime = message.data.startTime;
          var currentTime = NetworkManager.instance.getNetworkTime();
          var delay = startTime - currentTime;

          if (delay > 0)
          {
            new flixel.util.FlxTimer().start(delay, function(_) {
              if (FlxG.sound.music != null) FlxG.sound.music.play();
            });
          }
          else
          {
            if (FlxG.sound.music != null) FlxG.sound.music.play();
          }
        }

      case "sync":
        handleRemoteSync(message.data);
    }
  }

  function handleRemoteSync(data:Dynamic):Void
  {
    var remoteSongPosition:Float = data.songPosition;
    var localSongPosition = Conductor.instance.songPosition;
    var timeDiff = Math.abs(remoteSongPosition - localSongPosition);

    // If we're significantly out of sync, adjust
    if (timeDiff > 100) // 100ms threshold
    {
      trace('[MULTIPLAYER] Sync correction needed: ${timeDiff}ms difference');

      if (FlxG.sound.music != null)
      {
        var targetTime = (remoteSongPosition + localSongPosition) / 2;
        FlxG.sound.music.time = targetTime;
        Conductor.instance.update(targetTime);
      }
    }
  }

  override function destroy():Void
  {
    MultiplayerInputManager.instance.onRemoteInput.remove(handleRemoteInput);
    MultiplayerGameState.instance.cleanup();

    super.destroy();
  }
}
