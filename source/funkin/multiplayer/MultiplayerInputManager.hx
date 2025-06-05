package funkin.multiplayer;

import flixel.util.FlxSignal;
import funkin.input.Controls;
import funkin.multiplayer.NetworkManager;

typedef InputEvent =
{
  playerId:String,
  action:InputAction,
  timestamp:Float,
  frame:Int,
  processed:Bool
}

enum InputAction
{
  NOTE_LEFT_PRESS;
  NOTE_DOWN_PRESS;
  NOTE_UP_PRESS;
  NOTE_RIGHT_PRESS;
  NOTE_LEFT_RELEASE;
  NOTE_DOWN_RELEASE;
  NOTE_UP_RELEASE;
  NOTE_RIGHT_RELEASE;
}

/**
 * Handles input synchronization between players
 * Provides lag compensation and input prediction
 */
class MultiplayerInputManager
{
  public static var instance(get, never):MultiplayerInputManager;
  static var _instance:Null<MultiplayerInputManager> = null;

  static function get_instance():MultiplayerInputManager
  {
    if (_instance == null) _instance = new MultiplayerInputManager();
    return _instance;
  }

  public var onRemoteInput(default, null):FlxTypedSignal<InputEvent->Void> = new FlxTypedSignal();

  var localInputHistory:Array<InputEvent> = [];
  var remoteInputHistory:Array<InputEvent> = [];
  var inputBuffer:Array<InputEvent> = [];

  // Lag compensation
  var inputDelay:Float = 0.0; // Frames of input delay for fairness
  var lagCompensationFrames:Int = 3;

  public function new() {}

  public function captureLocalInput(controls:Controls):Void
  {
    var currentTime = NetworkManager.instance.getNetworkTime();
    var inputs:Array<InputAction> = [];

    if (controls.NOTE_LEFT_P) inputs.push(NOTE_LEFT_PRESS);
    if (controls.NOTE_DOWN_P) inputs.push(NOTE_DOWN_PRESS);
    if (controls.NOTE_UP_P) inputs.push(NOTE_UP_PRESS);
    if (controls.NOTE_RIGHT_P) inputs.push(NOTE_RIGHT_PRESS);

    if (controls.NOTE_LEFT_R) inputs.push(NOTE_LEFT_RELEASE);
    if (controls.NOTE_DOWN_R) inputs.push(NOTE_DOWN_RELEASE);
    if (controls.NOTE_UP_R) inputs.push(NOTE_UP_RELEASE);
    if (controls.NOTE_RIGHT_R) inputs.push(NOTE_RIGHT_RELEASE);

    for (action in inputs)
    {
      var inputEvent:InputEvent =
        {
          playerId: NetworkManager.instance.localPlayerId,
          action: action,
          timestamp: currentTime,
          frame: Conductor.instance.currentStep,
          processed: false
        };

      localInputHistory.push(inputEvent);
      sendInputEvent(inputEvent);
    }

    cleanupInputHistory();
  }

  function sendInputEvent(inputEvent:InputEvent):Void
  {
    NetworkManager.instance.sendMessage(
      {
        type: INPUT_EVENT,
        senderId: NetworkManager.instance.localPlayerId,
        timestamp: inputEvent.timestamp,
        data:
          {
            action: inputEvent.action,
            frame: inputEvent.frame
          }
      });
  }

  public function handleRemoteInput(message:NetworkMessage):Void
  {
    var inputEvent:InputEvent =
      {
        playerId: message.senderId,
        action: message.data.action,
        timestamp: message.timestamp,
        frame: message.data.frame,
        processed: false
      };

    remoteInputHistory.push(inputEvent);
    onRemoteInput.dispatch(inputEvent);
  }

  public function getInputsForFrame(frame:Int, playerId:String):Array<InputAction>
  {
    var inputs:Array<InputAction> = [];
    var history = playerId == NetworkManager.instance.localPlayerId ? localInputHistory : remoteInputHistory;

    for (inputEvent in history)
    {
      if (inputEvent.frame == frame && !inputEvent.processed)
      {
        inputs.push(inputEvent.action);
        inputEvent.processed = true;
      }
    }

    return inputs;
  }

  function cleanupInputHistory():Void
  {
    var cutoffTime = NetworkManager.instance.getNetworkTime() - 5.0;

    localInputHistory = localInputHistory.filter(input -> input.timestamp > cutoffTime);
    remoteInputHistory = remoteInputHistory.filter(input -> input.timestamp > cutoffTime);
  }
}
