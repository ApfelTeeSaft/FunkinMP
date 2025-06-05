package funkin.multiplayer;

import flixel.util.FlxSignal;
import haxe.io.Bytes;
import haxe.Json;

/**
 * Core network manager handling P2P connections and message routing
 * Inspired by Unreal's NetworkManager but adapted for rhythm games
 */
class NetworkManager
{
  public static var instance(get, never):NetworkManager;
  static var _instance:Null<NetworkManager> = null;

  static function get_instance():NetworkManager
  {
    if (_instance == null) _instance = new NetworkManager();
    return _instance;
  }

  // Connection state
  public var isHost(default, null):Bool = false;
  public var isConnected(default, null):Bool = false;
  public var localPlayerId(default, null):String = "";
  public var remotePlayerId(default, null):String = "";

  var connectionAttemptTime:Float = 0.0;

  // Timing synchronization
  public var networkTime(default, null):Float = 0.0;
  public var clockOffset(default, null):Float = 0.0;
  public var roundTripTime(default, null):Float = 0.0;

  // Signals
  public var onConnected(default, null):FlxSignal = new FlxSignal();
  public var onDisconnected(default, null):FlxSignal = new FlxSignal();
  public var onMessageReceived(default, null):FlxTypedSignal<NetworkMessage->Void> = new FlxTypedSignal();

  // Replication
  var replicatedObjects:Map<String, INetworkReplicable> = new Map();
  var messageQueue:Array<NetworkMessage> = [];
  var timeSyncSamples:Array<Float> = [];

  #if cpp
  var socket:sys.net.Socket = null;
  var serverSocket:sys.net.Socket = null;
  #end

  public function new()
  {
    localPlayerId = generatePlayerId();
  }

  public function hostGame(port:Int = 7777):Bool
  {
    #if cpp
    try
    {
      serverSocket = new sys.net.Socket();
      serverSocket.bind(new sys.net.Host("0.0.0.0"), port);
      serverSocket.listen(1);
      isHost = true;

      trace('[NETWORK] Hosting game on port $port, waiting for connections...');

      sys.thread.Thread.create(function() {
        try
        {
          trace('[NETWORK] [THREAD] Waiting for client connection...');
          var client = serverSocket.accept();

          if (client != null)
          {
            trace('[NETWORK] [THREAD] Client connected!');
            socket = client;
            isConnected = true;

            haxe.MainLoop.add(function() {
              trace('[NETWORK] Connection established - entering lobby');
              onConnected.dispatch();
              return false;
            });
          }
        }
        catch (e:Dynamic)
        {
          trace('[NETWORK] [THREAD] Accept failed: $e');
          haxe.MainLoop.add(function() {
            onDisconnected.dispatch();
            return false;
          });
        }
      });

      return true;
    }
    catch (e:Dynamic)
    {
      trace('[NETWORK] Failed to host: $e');
      return false;
    }
    #else
    trace('[NETWORK] P2P hosting not supported on this platform');
    return false;
    #end
  }

  public function joinGame(host:String, port:Int = 7777):Bool
  {
    #if cpp
    try
    {
      trace('[NETWORK] Starting connection to $host:$port...');

      sys.thread.Thread.create(function() {
        try
        {
          trace('[NETWORK] [THREAD] Connecting to $host:$port...');
          var newSocket = new sys.net.Socket();
          newSocket.connect(new sys.net.Host(host), port);

          socket = newSocket;
          isHost = false;
          isConnected = true;

          trace('[NETWORK] [THREAD] Connected successfully!');

          haxe.MainLoop.add(function() {
            trace('[NETWORK] Connection established - sending handshake');
            sendHandshake();
            onConnected.dispatch();
            return false;
          });
        }
        catch (e:Dynamic)
        {
          trace('[NETWORK] [THREAD] Connection failed: $e');
          haxe.MainLoop.add(function() {
            onDisconnected.dispatch();
            return false;
          });
        }
      });

      return true;
    }
    catch (e:Dynamic)
    {
      trace('[NETWORK] Failed to start connection thread: $e');
      return false;
    }
    #else
    trace('[NETWORK] P2P connection not supported on this platform');
    return false;
    #end
  }

  public function update(elapsed:Float):Void
  {
    if (!isConnected) return;

    #if cpp
    updateSocket();
    #end

    processMessageQueue();
    updateTimeSync(elapsed);
    updateReplication(elapsed);
  }

  #if cpp
  function updateSocket():Void
  {
    if (socket != null && isConnected)
    {
      try
      {
        socket.setTimeout(0.001);
        var data = socket.input.readAll();

        if (data.length > 0)
        {
          parseIncomingData(data);
        }
      }
      catch (e:Dynamic)
      {
        var errorStr = Std.string(e);
        if (errorStr.indexOf("Timeout") == -1)
        {
          trace('[NETWORK] Read error: $e');
          disconnect();
        }
      }
    }
  }

  function parseIncomingData(data:Bytes):Void
  {
    try
    {
      var messageStr = data.toString();
      var messages = messageStr.split("\n");

      for (msgStr in messages)
      {
        if (msgStr.length > 0)
        {
          var message:NetworkMessage = Json.parse(msgStr);
          messageQueue.push(message);
        }
      }
    }
    catch (e:Dynamic)
    {
      trace('[NETWORK] Failed to parse message: $e');
    }
  }
  #end

  public function sendMessage(message:NetworkMessage):Void
  {
    if (!isConnected || socket == null) return;

    message.senderId = localPlayerId;
    message.timestamp = getNetworkTime();

    #if cpp
    try
    {
      var data = Json.stringify(message) + "\n";
      socket.output.writeString(data);
      socket.output.flush();
    }
    catch (e:Dynamic)
    {
      trace('[NETWORK] Failed to send message: $e');
      disconnect();
    }
    #end
  }

  function processMessageQueue():Void
  {
    for (message in messageQueue)
    {
      handleMessage(message);
    }
    messageQueue = [];
  }

  function handleMessage(message:NetworkMessage):Void
  {
    switch (message.type)
    {
      case HANDSHAKE:
        handleHandshake(message);
      case TIME_SYNC:
        handleTimeSync(message);
      case REPLICATION_UPDATE:
        handleReplicationUpdate(message);
      case INPUT_EVENT:
        handleInputEvent(message);
      case GAME_STATE:
        handleGameState(message);
    }

    onMessageReceived.dispatch(message);
  }

  function sendHandshake():Void
  {
    sendMessage(
      {
        type: HANDSHAKE,
        senderId: localPlayerId,
        timestamp: getNetworkTime(),
        data:
          {
            playerId: localPlayerId,
            version: Constants.VERSION
          }
      });
  }

  function handleHandshake(message:NetworkMessage):Void
  {
    remotePlayerId = message.data.playerId;

    if (isHost)
    {
      sendHandshake();
    }

    startTimeSync();
  }

  function startTimeSync():Void
  {
    var syncTimer = new flixel.util.FlxTimer();
    syncTimer.start(1.0, function(_) {
      sendMessage(
        {
          type: TIME_SYNC,
          senderId: localPlayerId,
          timestamp: getNetworkTime(),
          data:
            {
              clientTime: haxe.Timer.stamp(),
              isRequest: true
            }
        });
    }, 0);
  }

  function handleTimeSync(message:NetworkMessage):Void
  {
    if (message.data.isRequest)
    {
      sendMessage(
        {
          type: TIME_SYNC,
          senderId: localPlayerId,
          timestamp: getNetworkTime(),
          data:
            {
              clientTime: message.data.clientTime,
              serverTime: haxe.Timer.stamp(),
              isRequest: false
            }
        });
    }
    else
    {
      // Calculate RTT and clock offset
      var now = haxe.Timer.stamp();
      roundTripTime = now - message.data.clientTime;
      clockOffset = message.data.serverTime - now + (roundTripTime / 2);

      timeSyncSamples.push(clockOffset);
      if (timeSyncSamples.length > 10) timeSyncSamples.shift();

      // Use median for stability
      var sorted = timeSyncSamples.copy();
      sorted.sort((a, b) -> a < b ? -1 : a > b ? 1 : 0);
      clockOffset = sorted[Std.int(sorted.length / 2)];
    }
  }

  function updateTimeSync(elapsed:Float):Void
  {
    networkTime = haxe.Timer.stamp() + clockOffset;
  }

  public function getNetworkTime():Float
  {
    return networkTime;
  }

  public function registerReplicatedObject(id:String, obj:INetworkReplicable):Void
  {
    replicatedObjects.set(id, obj);
  }

  public function unregisterReplicatedObject(id:String):Void
  {
    replicatedObjects.remove(id);
  }

  function updateReplication(elapsed:Float):Void
  {
    for (id => obj in replicatedObjects)
    {
      var data = obj.serialize();
      if (data != null)
      {
        sendMessage(
          {
            type: REPLICATION_UPDATE,
            senderId: localPlayerId,
            timestamp: getNetworkTime(),
            data:
              {
                objectId: id,
                replicationData: data
              }
          });
      }
    }
  }

  function handleReplicationUpdate(message:NetworkMessage):Void
  {
    var objectId = message.data.objectId;
    var obj = replicatedObjects.get(objectId);

    if (obj != null)
    {
      obj.deserialize(message.data.replicationData, message.timestamp);
    }
  }

  function handleInputEvent(message:NetworkMessage):Void
  {
    MultiplayerInputManager.instance.handleRemoteInput(message);
  }

  function handleGameState(message:NetworkMessage):Void
  {
    MultiplayerGameState.instance.handleRemoteGameState(message);
  }

  public function disconnect():Void
  {
    isConnected = false;

    #if cpp
    if (socket != null)
    {
      socket.close();
      socket = null;
    }

    if (serverSocket != null)
    {
      serverSocket.close();
      serverSocket = null;
    }
    #end

    onDisconnected.dispatch();
    trace('[NETWORK] Disconnected');
  }

  function generatePlayerId():String
  {
    return 'player_' + Std.string(Math.random()).substr(2, 8);
  }
}

enum NetworkMessageType
{
  HANDSHAKE;
  TIME_SYNC;
  REPLICATION_UPDATE;
  INPUT_EVENT;
  GAME_STATE;
}

typedef NetworkMessage =
{
  type:NetworkMessageType,
  senderId:String,
  timestamp:Float,
  data:Dynamic
}

interface INetworkReplicable
{
  public function serialize():Dynamic;
  public function deserialize(data:Dynamic, timestamp:Float):Void;
  public function shouldReplicate():Bool;
}
