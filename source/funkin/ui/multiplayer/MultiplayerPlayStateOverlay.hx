package funkin.ui.multiplayer;

import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import funkin.Highscore.Tallies;
import funkin.multiplayer.*;
import funkin.multiplayer.MultiplayerGameState.MultiplayerResult;

/**
 * Overlay for displaying multiplayer-specific UI during gameplay
 */
class MultiplayerPlayStateOverlay extends FlxGroup
{
  var remotePlayerScore:FlxText;
  var remotePlayerCombo:FlxText;
  var connectionStatus:FlxText;
  var winnerDisplay:FlxText;

  var localTallies:Tallies;
  var remoteTallies:Tallies;

  public function new()
  {
    super();

    // Remote player score display
    remotePlayerScore = new FlxText(FlxG.width - 300, 50, 250, "", 32);
    remotePlayerScore.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.YELLOW, RIGHT, OUTLINE, FlxColor.BLACK);
    add(remotePlayerScore);

    remotePlayerCombo = new FlxText(FlxG.width - 300, 90, 250, "", 24);
    remotePlayerCombo.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.YELLOW, RIGHT, OUTLINE, FlxColor.BLACK);
    add(remotePlayerCombo);

    // Connection status
    connectionStatus = new FlxText(10, FlxG.height - 40, 200, "", 16);
    connectionStatus.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.GREEN, LEFT, OUTLINE, FlxColor.BLACK);
    add(connectionStatus);

    // Winner display (hidden initially)
    winnerDisplay = new FlxText(0, FlxG.height / 2 - 50, FlxG.width, "", 64);
    winnerDisplay.setFormat(Paths.font("vcr.ttf"), 64, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
    winnerDisplay.visible = false;
    add(winnerDisplay);

    // Set up callbacks
    MultiplayerGameState.instance.onPlayerScoreUpdated.add(onPlayerScoreUpdated);
    MultiplayerGameState.instance.onGameEnded.add(onGameEnded);
    NetworkManager.instance.onDisconnected.add(onDisconnected);

    localTallies = new Tallies();
    remoteTallies = new Tallies();
  }

  public function updateLocalScore(tallies:Tallies):Void
  {
    localTallies = tallies;
    MultiplayerGameState.instance.updateLocalPlayerScore(tallies);
  }

  function onPlayerScoreUpdated(playerId:String, tallies:Tallies):Void
  {
    if (playerId != NetworkManager.instance.localPlayerId)
    {
      remoteTallies = tallies;
      updateRemoteDisplay();
    }
  }

  function updateRemoteDisplay():Void
  {
    remotePlayerScore.text = "Opponent: " + remoteTallies.score;
    remotePlayerCombo.text = "Combo: " + remoteTallies.combo;

    // Color code based on who's winning
    var color = localTallies.score > remoteTallies.score ? FlxColor.LIME : FlxColor.RED;
    remotePlayerScore.color = color;
    remotePlayerCombo.color = color;
  }

  function onGameEnded(result:MultiplayerResult):Void
  {
    var winnerText = "";
    var color = FlxColor.WHITE;

    switch (result.winner)
    {
      case winner if (winner == NetworkManager.instance.localPlayerId):
        winnerText = "YOU WIN!";
        color = FlxColor.LIME;

      case winner if (winner == NetworkManager.instance.remotePlayerId):
        winnerText = "YOU LOSE!";
        color = FlxColor.RED;

      case "tie":
        winnerText = "TIE GAME!";
        color = FlxColor.YELLOW;

      default:
        winnerText = "GAME OVER";
    }

    winnerDisplay.text = winnerText;
    winnerDisplay.color = color;
    winnerDisplay.visible = true;
  }

  function onDisconnected():Void
  {
    connectionStatus.text = "DISCONNECTED";
    connectionStatus.color = FlxColor.RED;
  }

  override function update(elapsed:Float):Void
  {
    super.update(elapsed);

    if (NetworkManager.instance.isConnected)
    {
      var ping = Std.int(NetworkManager.instance.roundTripTime * 1000);
      connectionStatus.text = 'Ping: ${ping}ms';
      connectionStatus.color = ping < 100 ? FlxColor.GREEN : ping < 200 ? FlxColor.YELLOW : FlxColor.RED;
    }
  }

  override function destroy():Void
  {
    MultiplayerGameState.instance.onPlayerScoreUpdated.remove(onPlayerScoreUpdated);
    MultiplayerGameState.instance.onGameEnded.remove(onGameEnded);
    NetworkManager.instance.onDisconnected.remove(onDisconnected);

    super.destroy();
  }
}
