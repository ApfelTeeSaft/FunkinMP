package;

import flixel.FlxGame;
import flixel.FlxState;
import funkin.Preferences;
import funkin.util.logging.CrashHandler;
import funkin.ui.debug.MemoryCounter;
import funkin.save.Save;
import haxe.ui.Toolkit;
import openfl.display.FPS;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.Lib;
import openfl.media.Video;
import openfl.net.NetStream;
import funkin.util.WindowUtil;

#if cpp
@:cppFileCode('
#include <windows.h>
')
#end

/**
 * The main class which initializes HaxeFlixel and starts the game in its initial state.
 */
class Main extends Sprite
{
  var gameWidth:Int = 1280;
  var gameHeight:Int = 720;
  var initialState:Class<FlxState> = funkin.InitState;
  var zoom:Float = -1;
  var skipSplash:Bool = true;
  var startFullscreen:Bool = false;

  public static function main():Void
  {
    CrashHandler.initialize();
    CrashHandler.queryStatus();
    Lib.current.addChild(new Main());
  }

  public function new()
  {
    super();

    haxe.Log.trace = funkin.util.logging.AnsiTrace.trace;
    funkin.util.logging.AnsiTrace.traceBF();

    funkin.modding.PolymodHandler.loadAllMods();

    if (stage != null)
    {
      init();
    }
    else
    {
      addEventListener(Event.ADDED_TO_STAGE, init);
    }
  }

  function init(?event:Event):Void
  {
    if (hasEventListener(Event.ADDED_TO_STAGE))
    {
      removeEventListener(Event.ADDED_TO_STAGE, init);
    }

    setupGame();
  }

  var video:Video;
  var netStream:NetStream;
  var overlay:Sprite;

  public static var fpsCounter:FPS;
  public static var memoryCounter:MemoryCounter;

  function setupGame():Void
  {
    initHaxeUI();

    fpsCounter = new FPS(10, 3, 0xFFFFFF);

    #if !html5
    memoryCounter = new MemoryCounter(10, 13, 0xFFFFFF);
    #end

    Save.load();

    #if web
    funkin.Preferences.lockedFramerateFunction = untyped js.Syntax.code("window.requestAnimationFrame");
    #end

    WindowUtil.setVSyncMode(funkin.Preferences.vsyncMode);

    var game:FlxGame = new FlxGame(gameWidth, gameHeight, initialState, Preferences.framerate, Preferences.framerate, skipSplash, startFullscreen);

    @:privateAccess
    game._customSoundTray = funkin.ui.options.FunkinSoundTray;

    addChild(game);

    #if FEATURE_DEBUG_FUNCTIONS
    game.debugger.interaction.addTool(new funkin.util.TrackerToolButtonUtil());
    #end

    #if hxcpp_debug_server
    trace('hxcpp_debug_server is enabled! You can now connect to the game with a debugger.');
    #else
    trace('hxcpp_debug_server is disabled! This build does not support debugging.');
    #end
  }

  function initHaxeUI():Void
  {
    Toolkit.init();
    Toolkit.theme = 'dark';
    Toolkit.autoScale = false;
    haxe.ui.focus.FocusManager.instance.autoFocus = false;
    funkin.input.Cursor.registerHaxeUICursors();
    haxe.ui.tooltips.ToolTipManager.defaultDelay = 200;
  }
}
