package funkin.multiplayer;

import flixel.FlxBasic;

/**
 * Plugin to handle multiplayer system updates globally
 * Ensures network systems run even when switching states
 */
class MultiplayerPlugin extends FlxBasic
{
  public function new()
  {
    super();
  }

  public static function initialize():Void
  {
    FlxG.plugins.addPlugin(new MultiplayerPlugin());
  }

  public override function update(elapsed:Float):Void
  {
    super.update(elapsed);

    if (NetworkManager.instance.isConnected)
    {
      NetworkManager.instance.update(elapsed);
      ReplicationManager.instance.update(elapsed);
    }
  }

  public override function destroy():Void
  {
    super.destroy();
  }
}
