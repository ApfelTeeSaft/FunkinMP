package funkin.multiplayer;

import flixel.util.FlxSignal;
import funkin.multiplayer.NetworkManager;

/**
 * Manages automatic replication of game objects across network
 * Similar to Unreal's replication system but optimized for rhythm games
 */
class ReplicationManager
{
  public static var instance(get, never):ReplicationManager;
  static var _instance:Null<ReplicationManager> = null;

  static function get_instance():ReplicationManager
  {
    if (_instance == null) _instance = new ReplicationManager();
    return _instance;
  }

  var replicatedProperties:Map<String, ReplicatedProperty> = new Map();
  var replicationFrequency:Float = 1.0 / 60.0; // 60Hz replication
  var lastReplicationTime:Float = 0.0;

  public function new() {}

  public function registerProperty(objectId:String, propertyName:String, getter:Void->Dynamic, setter:Dynamic->Void, config:ReplicationConfig):Void
  {
    var key = '${objectId}.${propertyName}';
    replicatedProperties.set(key,
      {
        objectId: objectId,
        propertyName: propertyName,
        getter: getter,
        setter: setter,
        config: config,
        lastValue: null,
        lastSentTime: 0.0,
        interpolationData: new InterpolationData()
      });
  }

  public function update(elapsed:Float):Void
  {
    var currentTime = NetworkManager.instance.getNetworkTime();

    if (currentTime - lastReplicationTime >= replicationFrequency)
    {
      processReplication(currentTime);
      lastReplicationTime = currentTime;
    }

    interpolateProperties(elapsed);
  }

  function processReplication(currentTime:Float):Void
  {
    for (key => prop in replicatedProperties)
    {
      if (shouldReplicateProperty(prop, currentTime))
      {
        var currentValue = prop.getter();

        if (hasValueChanged(prop.lastValue, currentValue))
        {
          sendPropertyUpdate(prop, currentValue, currentTime);
          prop.lastValue = currentValue;
          prop.lastSentTime = currentTime;
        }
      }
    }
  }

  function shouldReplicateProperty(prop:ReplicatedProperty, currentTime:Float):Bool
  {
    // Only replicate if we own this object (host for authority, client for input)
    if (prop.config.authority == AUTHORITY_HOST && !NetworkManager.instance.isHost) return false;
    if (prop.config.authority == AUTHORITY_CLIENT && NetworkManager.instance.isHost) return false;

    if (currentTime - prop.lastSentTime < (1.0 / prop.config.frequency)) return false;

    return true;
  }

  function hasValueChanged(oldValue:Dynamic, newValue:Dynamic):Bool
  {
    if (oldValue == null) return true;

    if (Std.isOfType(newValue, Float))
    {
      var threshold = 0.001;
      return Math.abs(cast(newValue, Float) - cast(oldValue, Float)) > threshold;
    }

    return oldValue != newValue;
  }

  function sendPropertyUpdate(prop:ReplicatedProperty, value:Dynamic, timestamp:Float):Void
  {
    NetworkManager.instance.sendMessage(
      {
        type: REPLICATION_UPDATE,
        senderId: NetworkManager.instance.localPlayerId,
        timestamp: timestamp,
        data:
          {
            objectId: prop.objectId,
            propertyName: prop.propertyName,
            value: value,
            interpolate: prop.config.interpolate
          }
      });
  }

  public function handlePropertyUpdate(message:NetworkMessage):Void
  {
    var objectId = message.data.objectId;
    var propertyName = message.data.propertyName;
    var value = message.data.value;
    var key = '${objectId}.${propertyName}';

    var prop = replicatedProperties.get(key);
    if (prop == null) return;

    if (prop.config.interpolate)
    {
      setupInterpolation(prop, value, message.timestamp);
    }
    else
    {
      prop.setter(value);
    }
  }

  function setupInterpolation(prop:ReplicatedProperty, targetValue:Dynamic, timestamp:Float):Void
  {
    var currentTime = NetworkManager.instance.getNetworkTime();
    var latency = currentTime - timestamp;

    prop.interpolationData.startValue = prop.getter();
    prop.interpolationData.targetValue = targetValue;
    prop.interpolationData.startTime = currentTime;
    prop.interpolationData.duration = Math.max(0.1, latency * 2);
    prop.interpolationData.isActive = true;
  }

  function interpolateProperties(elapsed:Float):Void
  {
    var currentTime = NetworkManager.instance.getNetworkTime();

    for (prop in replicatedProperties)
    {
      if (!prop.interpolationData.isActive) continue;

      var progress = (currentTime - prop.interpolationData.startTime) / prop.interpolationData.duration;
      progress = Math.min(1.0, Math.max(0.0, progress));

      if (progress >= 1.0)
      {
        prop.setter(prop.interpolationData.targetValue);
        prop.interpolationData.isActive = false;
      }
      else
      {
        var interpolatedValue = interpolateValue(prop.interpolationData.startValue, prop.interpolationData.targetValue, progress);
        prop.setter(interpolatedValue);
      }
    }
  }

  function interpolateValue(start:Dynamic, target:Dynamic, t:Float):Dynamic
  {
    if (Std.isOfType(start, Float) && Std.isOfType(target, Float))
    {
      return funkin.util.MathUtil.lerp(cast start, cast target, t);
    }

    // For non-interpolatable types, just return target when t > 0.5
    return t > 0.5 ? target : start;
  }
}

typedef ReplicationConfig =
{
  authority:ReplicationAuthority,
  frequency:Float, // Hz
  interpolate:Bool,
  reliable:Bool
}

enum ReplicationAuthority
{
  AUTHORITY_HOST;
  AUTHORITY_CLIENT;
  AUTHORITY_SHARED;
}

typedef ReplicatedProperty =
{
  objectId:String,
  propertyName:String,
  getter:Void->Dynamic,
  setter:Dynamic->Void,
  config:ReplicationConfig,
  lastValue:Dynamic,
  lastSentTime:Float,
  interpolationData:InterpolationData
}

class InterpolationData
{
  public var startValue:Dynamic = null;
  public var targetValue:Dynamic = null;
  public var startTime:Float = 0.0;
  public var duration:Float = 0.0;
  public var isActive:Bool = false;

  public function new() {}
}
