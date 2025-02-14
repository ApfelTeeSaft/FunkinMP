package network;

import haxe.Json;

class ReplicationManager
{
  public static var replicatedObjects:Map<String, NetObject> = new Map();

  public static function registerObject(obj:NetObject)
  {
    replicatedObjects.set(obj.id, obj);
  }

  public static function replicateObject(obj:NetObject)
  {
    var data = {id: obj.id, owner: obj.owner, data: obj};
    if (Server != null)
    {
      Server.broadcastReplication(data);
    }
    else
    {
      Client.sendEncrypted(data);
    }
  }

  public static function handleIncomingData(data:String)
  {
    var objData = Json.parse(data);
    var obj = replicatedObjects.get(objData.id);
    if (obj != null)
    {
      obj.onReplicated(objData.data);
    }
  }

  public static var Server:NetworkManagerServer;
  public static var Client:NetworkManagerClient;
}
