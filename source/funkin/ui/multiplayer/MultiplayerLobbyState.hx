package funkin.ui.multiplayer;

import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import funkin.ui.MusicBeatState;
import funkin.audio.FunkinSound;
import funkin.multiplayer.*;
import funkin.multiplayer.MultiplayerGameState.MultiplayerGamePhase;

/**
 * Lobby state where players can chat and select songs before starting
 */
class MultiplayerLobbyState extends MusicBeatState
{
  var bg:FlxSprite;
  var titleText:FlxText;
  var playerListText:FlxText;
  var statusText:FlxText;
  var readyButton:FlxSprite;

  var isReady:Bool = false;
  var remotePlayerReady:Bool = false;

  override function create():Void
  {
    super.create();

    bg = new FlxSprite(Paths.image('menuBG'));
    bg.scrollFactor.set();
    bg.setGraphicSize(Std.int(bg.width * 1.2));
    bg.updateHitbox();
    bg.screenCenter();
    bg.color = FlxColor.fromRGB(80, 120, 80);
    add(bg);

    // Title
    titleText = new FlxText(0, 50, FlxG.width, "MULTIPLAYER LOBBY", 48);
    titleText.setFormat(Paths.font("vcr.ttf"), 48, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
    add(titleText);

    // Player list
    playerListText = new FlxText(50, 150, FlxG.width - 100, "", 24);
    playerListText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
    add(playerListText);

    // Status
    statusText = new FlxText(0, FlxG.height - 150, FlxG.width, "", 24);
    statusText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
    add(statusText);

    // Ready button
    readyButton = new FlxSprite(FlxG.width / 2 - 100, FlxG.height - 100);
    readyButton.makeGraphic(200, 50, FlxColor.RED);
    add(readyButton);

    MultiplayerGameState.instance.onGameStateChanged.add(onGameStateChanged);

    updateDisplay();
    updateStatusText("Press SPACE to ready up, ENTER to start (host only)");
  }

  function updateDisplay():Void
  {
    var localId = NetworkManager.instance.localPlayerId;
    var remoteId = NetworkManager.instance.remotePlayerId;

    var playerList = "Players:\n";
    playerList += '${localId} (You) - ${isReady ? "READY" : "Not Ready"}\n';

    if (remoteId != "")
    {
      playerList += '${remoteId} - ${remotePlayerReady ? "READY" : "Not Ready"}\n';
    }
    else
    {
      playerList += "Waiting for player...\n";
    }

    playerListText.text = playerList;

    readyButton.color = isReady ? FlxColor.GREEN : FlxColor.RED;
  }

  function toggleReady():Void
  {
    isReady = !isReady;
    updateDisplay();

    NetworkManager.instance.sendMessage(
      {
        type: GAME_STATE,
        senderId: NetworkManager.instance.localPlayerId,
        timestamp: NetworkManager.instance.getNetworkTime(),
        data:
          {
            type: "ready_state",
            isReady: isReady
          }
      });

    FunkinSound.playOnce(Paths.sound('confirmMenu'));
  }

  function startGame():Void
  {
    if (!NetworkManager.instance.isHost) return;
    if (!isReady || !remotePlayerReady) return;

    MultiplayerGameState.instance.startMultiplayerSession(VERSUS);

    // hardcode default tutorial song for testing on normal mode, TODO: make host be able to select song and difficulty in lobby
    FlxG.switchState(() -> new funkin.play.PlayState(
      {
        targetSong: funkin.data.song.SongRegistry.instance.fetchEntry("tutorial"),
        targetDifficulty: "normal"
      }));
  }

  function onGameStateChanged(newPhase:MultiplayerGamePhase):Void
  {
    switch (newPhase)
    {
      case SONG_LOADING:
        updateStatusText("Loading song...");
      case COUNTDOWN:
        updateStatusText("Get ready!");
      default:
        // idk
    }
  }

  function updateStatusText(text:String):Void
  {
    statusText.text = text;
    statusText.screenCenter(X);
  }

  override function update(elapsed:Float):Void
  {
    super.update(elapsed);

    NetworkManager.instance.update(elapsed);
    ReplicationManager.instance.update(elapsed);

    if (controls.ACCEPT) // SPACE
    {
      toggleReady();
    }

    if (FlxG.keys.justPressed.ENTER && NetworkManager.instance.isHost)
    {
      startGame();
    }

    if (controls.BACK)
    {
      NetworkManager.instance.disconnect();
      FlxG.switchState(() -> new MultiplayerMenuState());
    }
  }

  override function destroy():Void
  {
    MultiplayerGameState.instance.onGameStateChanged.remove(onGameStateChanged);
    super.destroy();
  }
}
