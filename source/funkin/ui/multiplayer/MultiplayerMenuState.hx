package funkin.ui.multiplayer;

import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import funkin.graphics.FunkinSprite;
import funkin.ui.MusicBeatState;
import funkin.audio.FunkinSound;
import funkin.multiplayer.*;
import funkin.multiplayer.MatchmakerClient.MatchInfo;
import funkin.multiplayer.MatchmakerClient.MatchPreferences;

class SimpleMenuItem extends FlxSprite
{
  public var callback:Void->Void;
  public var isSelected:Bool = false;

  public function new(x:Float, y:Float, text:String, callback:Void->Void)
  {
    super(x, y);
    this.callback = callback;

    makeGraphic(300, 60, FlxColor.GRAY);

    // use a simple sprite since i am too retarded for TextItem or whatevs
  }

  public function select():Void
  {
    isSelected = true;
    color = FlxColor.WHITE;
  }

  public function deselect():Void
  {
    isSelected = false;
    color = FlxColor.GRAY;
  }

  public function execute():Void
  {
    if (callback != null) callback();
  }
}

/**
 * Main multiplayer menu where players can choose to host or join games
 */
class MultiplayerMenuState extends MusicBeatState
{
  var menuItems:FlxTypedGroup<SimpleMenuItem>;
  var menuLabels:FlxTypedGroup<FlxText>;
  var bg:FlxSprite;
  var titleText:FlxText;
  var statusText:FlxText;

  var currentSelection:Int = 0;
  var isConnecting:Bool = false;

  override function create():Void
  {
    super.create();

    bg = new FlxSprite();
    bg.loadGraphic(Paths.image('menuBG'));
    bg.scrollFactor.set(0, 0.17);
    bg.setGraphicSize(Std.int(bg.width * 1.2));
    bg.updateHitbox();
    bg.screenCenter();
    bg.color = FlxColor.fromRGB(100, 100, 150);
    add(bg);

    // Title
    titleText = new FlxText(0, 100, FlxG.width, "MULTIPLAYER", 64);
    titleText.setFormat(Paths.font("vcr.ttf"), 64, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
    titleText.screenCenter(X);
    add(titleText);

    // Status text
    statusText = new FlxText(0, FlxG.height - 100, FlxG.width, "", 24);
    statusText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
    statusText.screenCenter(X);
    add(statusText);

    // Menu items
    menuItems = new FlxTypedGroup<SimpleMenuItem>();
    add(menuItems);

    // Menu labels (text)
    menuLabels = new FlxTypedGroup<FlxText>();
    add(menuLabels);

    createMenuItem('Host Game', hostGame);
    createMenuItem('Find Match', findMatch);
    createMenuItem('Direct Connect', directConnect);
    createMenuItem('Back', goBack);

    var spacing = 100;
    var startY = 250;

    for (i in 0...menuItems.length)
    {
      var item = menuItems.members[i];
      item.x = (FlxG.width - item.width) / 2;
      item.y = startY + spacing * i;
      item.scrollFactor.set();
    }

    selectItem(0);

    NetworkManager.instance.onConnected.add(onConnectionEstablished);
    NetworkManager.instance.onDisconnected.add(onConnectionLost);
    MatchmakerClient.instance.onMatchFound.add(onMatchFound);
    MatchmakerClient.instance.onMatchmakingFailed.add(onMatchmakingFailed);

    updateStatusText("Select an option");
  }

  function createMenuItem(text:String, callback:Void->Void):Void
  {
    var item = new SimpleMenuItem(0, 0, text, callback);
    menuItems.add(item);

    var label = new FlxText(0, 0, item.width, text, 24);
    label.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
    menuLabels.add(label);
  }

  function selectItem(index:Int):Void
  {
    for (i in 0...menuItems.length)
    {
      menuItems.members[i].deselect();
    }

    currentSelection = index;
    if (currentSelection >= 0 && currentSelection < menuItems.length)
    {
      menuItems.members[currentSelection].select();

      for (i in 0...menuLabels.length)
      {
        var item = menuItems.members[i];
        var label = menuLabels.members[i];
        label.x = item.x;
        label.y = item.y + (item.height - label.height) / 2;
      }
    }
  }

  function hostGame():Void
  {
    if (isConnecting) return;

    isConnecting = true;
    updateStatusText("Starting host...");

    if (NetworkManager.instance.hostGame())
    {
      updateStatusText("Waiting for player to join...");
      FunkinSound.playOnce(Paths.sound('confirmMenu'));
    }
    else
    {
      updateStatusText("Failed to start host");
      isConnecting = false;
    }
  }

  function findMatch():Void
  {
    if (isConnecting) return;

    isConnecting = true;
    updateStatusText("Searching for match...");

    var preferences:MatchPreferences =
      {
        region: "us-east",
        skillLevel: "intermediate",
        songDifficulty: "normal",
        gameMode: "versus"
      };

    MatchmakerClient.instance.findMatch(preferences);
    FunkinSound.playOnce(Paths.sound('confirmMenu'));
  }

  function directConnect():Void
  {
    if (isConnecting) return;

    // hardcoded to local for debugging
    // TODO: add textbox for entering remote ip / or use matchmaker to resolve "match codes"
    isConnecting = true;
    updateStatusText("Connecting to host...");

    if (NetworkManager.instance.joinGame("127.0.0.1"))
    {
      FunkinSound.playOnce(Paths.sound('confirmMenu'));
    }
    else
    {
      updateStatusText("Failed to connect");
      isConnecting = false;
    }
  }

  function goBack():Void
  {
    if (isConnecting)
    {
      NetworkManager.instance.disconnect();
      MatchmakerClient.instance.cancelSearch();
    }

    FunkinSound.playOnce(Paths.sound('cancelMenu'));
    FlxG.switchState(() -> new funkin.ui.mainmenu.MainMenuState());
  }

  function onConnectionEstablished():Void
  {
    updateStatusText("Connected! Entering lobby...");

    new flixel.util.FlxTimer().start(1.0, function(_) {
      FlxG.switchState(() -> new MultiplayerLobbyState());
    });
  }

  function onConnectionLost():Void
  {
    updateStatusText("Connection lost");
    isConnecting = false;
  }

  function onMatchFound(matchInfo:MatchInfo):Void
  {
    updateStatusText("Match found! Connecting...");

    var hostInfo = matchInfo.hostInfo;
    if (!NetworkManager.instance.joinGame(hostInfo.ip, hostInfo.port))
    {
      updateStatusText("Failed to connect to match");
      isConnecting = false;
    }
  }

  function onMatchmakingFailed(error:String):Void
  {
    updateStatusText("Matchmaking failed: " + error);
    isConnecting = false;
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

    if (!isConnecting)
    {
      if (controls.UI_UP_P)
      {
        currentSelection--;
        if (currentSelection < 0) currentSelection = menuItems.length - 1;
        selectItem(currentSelection);
        FunkinSound.playOnce(Paths.sound('scrollMenu'));
      }
      else if (controls.UI_DOWN_P)
      {
        currentSelection++;
        if (currentSelection >= menuItems.length) currentSelection = 0;
        selectItem(currentSelection);
        FunkinSound.playOnce(Paths.sound('scrollMenu'));
      }
      else if (controls.ACCEPT)
      {
        if (currentSelection >= 0 && currentSelection < menuItems.length)
        {
          menuItems.members[currentSelection].execute();
        }
      }
      else if (controls.BACK)
      {
        goBack();
      }
    }
  }

  override function destroy():Void
  {
    if (NetworkManager.instance != null)
    {
      NetworkManager.instance.onConnected.remove(onConnectionEstablished);
      NetworkManager.instance.onDisconnected.remove(onConnectionLost);
    }

    if (MatchmakerClient.instance != null)
    {
      MatchmakerClient.instance.onMatchFound.remove(onMatchFound);
      MatchmakerClient.instance.onMatchmakingFailed.remove(onMatchmakingFailed);
    }

    super.destroy();
  }
}
