package network;

import sys.net.Socket;
import sys.net.Host;
import sys.net.Socket;
import haxe.crypto.Aes;
import haxe.io.Bytes;
import haxe.Json;

class NetworkManagerServer
{
  private var serverSocket:Socket;
  private var clients:Array<Socket> = [];
  private var encryptionKey:Bytes;

  public function new(port:Int, key:String)
  {
    this.encryptionKey = Bytes.ofString(key);
    serverSocket = new Socket();
    serverSocket.bind(new Host("0.0.0.0"), port);
    serverSocket.listen(10);
    trace("Server started on port " + port);
  }

  public function acceptClients()
  {
    while (true)
    {
      var client = serverSocket.accept();
      clients.push(client);
      trace("Client connected: " + client.peer());
    }
  }

  public function sendEncrypted(data:Dynamic)
  {
    var aes = new Aes(encryptionKey);
    var jsonData = Json.stringify(data);
    var encrypted = aes.encrypt(Bytes.ofString(jsonData));

    for (client in clients)
    {
      client.output.write(encrypted);
    }
  }

  public function receiveEncrypted(client:Socket):Dynamic
  {
    var aes = new Aes(encryptionKey);
    var received = client.input.readAll();
    var decrypted = aes.decrypt(received);
    return Json.parse(decrypted.toString());
  }

  public function broadcastReplication(data:Dynamic)
  {
    sendEncrypted(data);
  }
}
