package network;

import sys.net.Socket;
import sys.net.Host;
import haxe.crypto.Aes;
import haxe.io.Bytes;
import haxe.Json;

class NetworkManagerClient
{
  private var clientSocket:Socket;
  private var encryptionKey:Bytes;

  public function new(host:String, port:Int, key:String)
  {
    this.encryptionKey = Bytes.ofString(key);
    clientSocket = new Socket();
    clientSocket.connect(new Host(host), port);
    trace("Connected to server");
  }

  public function sendEncrypted(data:Dynamic)
  {
    var aes = new Aes(encryptionKey);
    var jsonData = Json.stringify(data);
    var encrypted = aes.encrypt(Bytes.ofString(jsonData));
    clientSocket.output.write(encrypted);
  }

  public function receiveEncrypted():Dynamic
  {
    var aes = new Aes(encryptionKey);
    var received = clientSocket.input.readAll();
    var decrypted = aes.decrypt(received);
    return Json.parse(decrypted.toString());
  }
}
