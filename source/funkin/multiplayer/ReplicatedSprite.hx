package funkin.multiplayer;

import flixel.FlxSprite;
import funkin.multiplayer.NetworkManager;

/**
 * Mockup of a sprite that automatically replicates its position over network, dunno wtf this could be used for but yeah
 */
class ReplicatedSprite extends FlxSprite implements INetworkReplicable
{
  var objectId:String;
  var lastReplicatedX:Float = 0;
  var lastReplicatedY:Float = 0;
  var replicationThreshold:Float = 2.0;

  public function new(objectId:String, x:Float = 0, y:Float = 0)
  {
    super(x, y);
    this.objectId = objectId;

    NetworkManager.instance.registerReplicatedObject(objectId, this);
  }

  public function serialize():Dynamic
  {
    if (!shouldReplicate()) return null;

    return {
      x: this.x,
      y: this.y,
      animation: this.animation.name
    };
  }

  public function deserialize(data:Dynamic, timestamp:Float):Void
  {
    if (NetworkManager.instance.isHost) return;

    this.x = data.x;
    this.y = data.y;

    if (data.animation != null && this.animation.name != data.animation)
    {
      this.animation.play(data.animation);
    }
  }

  public function shouldReplicate():Bool
  {
    var moved = Math.abs(this.x - lastReplicatedX) > replicationThreshold || Math.abs(this.y - lastReplicatedY) > replicationThreshold;

    if (moved)
    {
      lastReplicatedX = this.x;
      lastReplicatedY = this.y;
      return true;
    }

    return false;
  }

  override function destroy():Void
  {
    NetworkManager.instance.unregisterReplicatedObject(objectId);
    super.destroy();
  }
}
