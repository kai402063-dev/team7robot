function value=BridgeSocket(operation,payload)
%BRIDGESOCKET Local-only transport for normal simulation, not generated code.
persistent server socket reader writer
value=[];
if strcmp(operation,'close')
 if ~isempty(socket),socket.close();end
 if ~isempty(server),server.close();end
 server=[];socket=[];reader=[];writer=[];return
end
if isempty(socket)
 port=str2double(getenv('TDP_BRIDGE_PORT'));if isnan(port),port=29741;end
 address=javaMethod('getByName','java.net.InetAddress','127.0.0.1');
 server=javaObject('java.net.ServerSocket',port,1,address);server.setSoTimeout(180000);
 fprintf('TDP_BRIDGE_LISTENING %d\n',port);socket=server.accept();socket.setSoTimeout(120000);
 reader=javaObject('java.io.BufferedReader',javaObject('java.io.InputStreamReader',socket.getInputStream()));
 writer=javaObject('java.io.PrintWriter',socket.getOutputStream(),true);
end
if strcmp(operation,'read')
 line=reader.readLine();assert(~isempty(line),'TDP:BridgeEOF','Transport closed');
 value=reshape(jsondecode(char(line)),1,[]);assert(numel(value)==20,'TDP:BridgeShape','Expected 20 doubles');
elseif strcmp(operation,'write')
 writer.println(jsonencode(payload));assert(~writer.checkError(),'TDP:BridgeWrite','Transport write failed');
else
 error('TDP:BridgeOperation','Unknown transport operation');
end
end
