package funkin.multiplayer;

import funkin.Conductor;

/**
 * Extended Conductor with multiplayer synchronization
 * Handles network-synchronized timing for rhythm games
 */
class MultiplayerConductor extends Conductor
{
  var lastNetworkSync:Float = 0.0;
  var syncFrequency:Float = 2.0;
  var allowedDrift:Float = 50.0;

  override function update(?songPos:Float, applyOffsets:Bool = true, forceDispatch:Bool = false):Void
  {
    if (NetworkManager.instance.isConnected)
    {
      handleNetworkSync();
    }

    super.update(songPos, applyOffsets, forceDispatch);
  }

  function handleNetworkSync():Void
  {
    var currentTime = NetworkManager.instance.getNetworkTime();

    if (currentTime - lastNetworkSync >= syncFrequency)
    {
      requestTimeSync();
      lastNetworkSync = currentTime;
    }
  }

  function requestTimeSync():Void
  {
    if (!NetworkManager.instance.isHost) return;

    NetworkManager.instance.sendMessage(
      {
        type: GAME_STATE,
        senderId: NetworkManager.instance.localPlayerId,
        timestamp: NetworkManager.instance.getNetworkTime(),
        data:
          {
            type: "conductor_sync",
            songPosition: this.songPosition,
            currentStep: this.currentStep,
            currentBeat: this.currentBeat,
            bpm: this.bpm
          }
      });
  }

  public function handleRemoteSync(data:Dynamic):Void
  {
    if (NetworkManager.instance.isHost) return;

    var remoteSongPosition:Float = data.songPosition;
    var drift = Math.abs(this.songPosition - remoteSongPosition);

    if (drift > allowedDrift)
    {
      trace('[MULTIPLAYER] Conductor sync correction: ${drift}ms drift');

      // Gradually adjust to avoid jarring jumps
      var correction = (remoteSongPosition - this.songPosition) * 0.1; // 10% correction per sync

      if (FlxG.sound.music != null)
      {
        FlxG.sound.music.time += correction;
      }
    }
  }
}
