package network;

class NetObject
{
  public var id:String;
  public var owner:String;
  public var needsReplication:Bool = true;

  public function new(id:String, owner:String)
  {
    this.id = id;
    this.owner = owner;
  }

  public function replicate():Void
  {
    if (needsReplication)
    {
      ReplicationManager.replicateObject(this);
    }
  }

  public function onReplicated(data:Dynamic):Void
  {
    trace("Object " + id + " updated: " + data);
  }
}
