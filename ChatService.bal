// Copyright (c) 2019 Miyuru Dayarathna All Rights Reserved.
//
// Miyuru Dayarathna licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/http;
import ballerina/log;
import ballerina/io;
import ballerina/config;
import ballerina/math;
import wso2/ethereum;
import wso2/utils;

listener http:Listener uiEP = new(9097);
listener http:Listener blockChainInterfaceEP = new(9096);

map<string> sessionMap = {};
map<boolean> authenticatedMap = {};
string chatBuffer = "";

ethereum:EthereumConfiguration ethereumConfig = {
jsonRpcEndpoint: "http://192.168.32.1:8081",
jsonRpcVersion: "2.0",
networkId: "2000"
};

string ethereumAccount = "0xee0727d9e94dbb230233ea4bd362e4c081aabf38";

string jsonRpcEndpoint = ethereumConfig.jsonRpcEndpoint;
http:Client ethereumClient = new(jsonRpcEndpoint, config = ethereumConfig.clientConfig);
boolean verifiableCredentialsFlag = true;

@http:ServiceConfig { basePath:"/" }
service uiService on uiEP {

   @http:ResourceConfig {
        methods:["GET"],
        path:"/"
    }
   resource function sayHello(http:Caller caller, http:Request req, string name, string message) {
        io:ReadableByteChannel readableByteChannel = io:openReadableFile("web/login.html");
        var readableCharChannel = new io:ReadableCharacterChannel(readableByteChannel, "UTF-8");
        var readableRecordsChannel = new io:ReadableTextRecordChannel(readableCharChannel);

        string buffer = "";

        while (readableRecordsChannel.hasNext()) {
            var result = readableRecordsChannel.getNext();
            if (result is string[]) {
                string item = string.convert(result[0]);
                buffer += item;
            } else {
                 io:println("Error");
            }
        }
       
       http:Response res = new;

       if (caller.localAddress.host != "") {
           buffer= buffer.replace("localhost", caller.localAddress.host);
       }

       res.setPayload(untaint buffer);
       res.setContentType("text/html; charset=utf-8");

       var result = caller->respond(res);
       if (result is error) {
            log:printError("Error sending response", err = result);
       }
   }

   @http:ResourceConfig {
        methods:["GET"],
        path:"/logout",
        cors: {
            allowOrigins: ["*"],
            allowHeaders: ["Authorization, Lang"]
        }
    }
   resource function logout(http:Caller caller, http:Request req, string name, string message) {
       map<string> requestVariableMap = req. getQueryParams();
       var did = requestVariableMap["did"] ?: "";
       authenticatedMap[did] = false;
       string buffer = "http://localhost:9097";
       
       http:Response res = new;

       if (caller.localAddress.host != "") {
           buffer= buffer.replace("localhost", caller.localAddress.host);
       }

       res.setPayload(untaint buffer);
       res.setContentType("text/html; charset=utf-8");

       var result = caller->respond(res);
       if (result is error) {
            log:printError("Error sending response", err = result);
       }
   }

   @http:ResourceConfig {
        methods:["GET"],
        path:"/jsencrypt.js"
    }
   resource function sendJSEncrypt(http:Caller caller, http:Request req, string name, string message) {
       http:Response res = new;

       res.setFileAsPayload("web/jsencrypt.js", contentType = "text/javascript");
       res.setContentType("text/javascript; charset=utf-8");

       var result = caller->respond(res);
       if (result is error) {
            log:printError("Error sending response", err = result);
       }
   }

   @http:ResourceConfig {
        methods:["GET"],
        path:"/browser-aes.js"
    }
   resource function sendJSBrowser(http:Caller caller, http:Request req, string name, string message) {
       http:Response res = new;

       res.setFileAsPayload("web/browser-aes.js", contentType = "text/javascript");
       res.setContentType("text/javascript; charset=utf-8");

       var result = caller->respond(res);
       if (result is error) {
            log:printError("Error sending response", err = result);
       }
   }


   @http:ResourceConfig {
        methods:["GET"],
        path:"/bg.jpg"
    }
   resource function sendBGImage(http:Caller caller, http:Request req, string name, string message) {
       http:Response res = new;
       res.setFileAsPayload("web/images/bg.jpg", contentType = "image/jpeg");

       var result = caller->respond(res);
       if (result is error) {
            log:printError("Error sending response", err = result);
       }
   }

   @http:ResourceConfig {
        methods:["POST"],
        path:"/authentication",
        cors: {
            allowOrigins: ["*"],
            allowHeaders: ["Authorization, Lang"]
        }
    }
   resource function authenticationPage(http:Caller caller, http:Request req, string name, string message) returns error?{
        string buffer = "";
        map<string> requestVariableMap = check req.getFormParams();

    if (requestVariableMap["command"] == "authenticate") {
            var did = requestVariableMap["did"] ?: "";
            did = did.replace("%2C", ",");
            int index2 = did.indexOf("\"id\": \"did:ethr:") + 16;
            string didmid = did.substring(index2, index2+64);

            index2 = did.indexOf("-----BEGIN PUBLIC KEY-----")  + 26;

            int index3 = did.indexOf("-----END PUBLIC KEY-----");
            var publicKey = did.substring(index2, index3);

            didmid = "0x" + didmid;
            http:Request request = new;
            request.setHeader("Content-Type", "application/json");
            request.setJsonPayload({"jsonrpc":"2.0", "id":"2000", "method":"eth_getTransactionByHash", "params":[untaint didmid]});
            
            string finalResult = "";
            string pkHash = "";
            boolean errorFlag = false;
            var httpResponse = ethereumClient -> post("/", request);
            if (httpResponse is http:Response) {
                int statusCode = httpResponse.statusCode;
                var jsonResponse = httpResponse.getJsonPayload();
                if (jsonResponse is json) {
                    if (jsonResponse["error"] == null) {
                        finalResult = jsonResponse.result.toString();
                        pkHash = jsonResponse.result["input"].toString();
                    } else {
                            error err = error("(wso2/ethereum)EthereumError",
                            { message: "Error occurred while accessing the JSON payload of the response" });
                            finalResult = jsonResponse["error"].toString();
                            errorFlag = true;
                    }
                } else {
                    error err = error("(wso2/ethereum)EthereumError",
                    { message: "Error occurred while accessing the JSON payload of the response" });
                    finalResult = jsonResponse.reason();
                    errorFlag = true;
                }
            } else {
                error err = error("(wso2/ethereum)EthereumError", { message: "Error occurred while invoking the Ethererum API" });
                errorFlag = true;
            }

            string hexEncodedString = "0x" + utils:hashSHA256("-----BEGIN PUBLIC KEY-----" + publicKey + "-----END PUBLIC KEY-----");

            if (hexEncodedString == pkHash) {
                string randKey = generateRandomKey(16);
                sessionMap[didmid] = randKey;
                finalResult = utils:encryptRSAWithPublicKey(publicKey, randKey);
            } else {
                finalResult = "Failure in Key Verification";
            }

            http:Response res = new;
            // A util method that can be used to set string payload.
            res.setPayload(untaint finalResult);
            res.setContentType("text/html; charset=utf-8");
            res.setHeader("Access-Control-Allow-Origin", "*");
            res.setHeader("Access-Control-Allow-Methods", "POST,GET,PUT,DELETE");
            res.setHeader("Access-Control-Allow-Headers", "Authorization, Lang");
        
            // Sends the response back to the client.
            var result = caller->respond(res);
            if (result is error) {
                    log:printError("Error sending response", err = result);
            }
        } else if (requestVariableMap["command"] == "encresponse") {
            var did = requestVariableMap["did"] ?: "";
            var encryptedval = requestVariableMap["encryptedval"] ?: "";

            did = did.replace("%2C", ",");
            int index2 = did.indexOf("\"id\": \"did:ethr:") + 16;
            string didmid = did.substring(index2, index2+64);

            index2 = did.indexOf("-----BEGIN PUBLIC KEY-----")  + 26;

            int index3 = did.indexOf("-----END PUBLIC KEY-----");
            var publicKey = did.substring(index2, index3);
            var didmidOrg = didmid;
            didmid = "0x" + didmid;
            
            string randKey = sessionMap[didmid]?: "";

            if (encryptedval === randKey) {
                io:println("Challenge response authentication was successful.");
                var finalResult = "successful";

                if(verifiableCredentialsFlag) {
                    io:println("Require verifiable credentials.");
                    finalResult = "successful|CountryCredential"; //Here we assume that chat service requires CountryCredential only.
                }

                http:Response res = new;
                // A util method that can be used to set string payload.
                res.setPayload(untaint finalResult);
                res.setContentType("text/html; charset=utf-8");
                res.setHeader("Access-Control-Allow-Origin", "*");
                res.setHeader("Access-Control-Allow-Methods", "POST,GET,PUT,DELETE");
                res.setHeader("Access-Control-Allow-Headers", "Authorization, Lang");
        
                // Sends the response back to the client.
                var result = caller->respond(res);
                if (result is error) {
                    log:printError("Error sending response", err = result);
                }
            } else {
                io:println("Challenge response authentication failed.");
            }
        } else if (requestVariableMap["command"] == "vcsubmit") {
            var did = requestVariableMap["did"] ?: "";
            var vc = requestVariableMap["vc"] ?: "";
            int index2 = vc.indexOf("\"homeCountry\": {") + 41;
            string didmid = vc.substring(index2, index2 + 64);
            string hash = readHashFromBloackchain("0x"+didmid);

            index2 = hash.indexOf("\"input\":\"") + 9;
            hash = hash.substring(index2, index2 + 66);
            string hexEncodedString = "0x" + utils:hashSHA256("USA");
            string buffer2 = "";
            string hostname = "localhost";

            if (hash === hexEncodedString) {
                authenticatedMap[did] = true;
                buffer2 = "http://" + hostname + ":9097/home?did=" + did;
            } else {
                buffer2 = "http://" + hostname + ":9097";
            }

            http:Response res = new;
            res.setPayload(untaint buffer2);
            res.setContentType("text/html; charset=utf-8");

            var result = caller->respond(res);
            if (result is error) {
                log:printError("Error sending response", err = result);
            }
        }
   }

    @http:ResourceConfig {
        methods:["GET"],
        path:"/home"
   }
   resource function sendHomePage(http:Caller caller, http:Request req, string name, string message) {
        map<string> requestVariableMap = req. getQueryParams();
        io:ReadableByteChannel readableByteChannel = io:openReadableFile("web/home.html");
        var readableCharChannel = new io:ReadableCharacterChannel(readableByteChannel, "UTF-8");
        var readableRecordsChannel = new io:ReadableTextRecordChannel(readableCharChannel);

        string buffer = "";

        while (readableRecordsChannel.hasNext()) {
            var result = readableRecordsChannel.getNext();
            if (result is string[]) {
                string item = string.convert(result[0]);
                buffer += item;
            } else {
                 io:println("Error");
            }
        }

       http:Response res = new;
       buffer = buffer.replace("uname", requestVariableMap["did"] ?: "abc");

       if (caller.localAddress.host != "") {
           buffer= buffer.replace("localhost", caller.localAddress.host);
       }

       res.setPayload(untaint buffer);
       res.setContentType("text/html; charset=utf-8");

       var result = caller->respond(res);
       if (result is error) {
            log:printError("Error sending response", err = result);
       }
   }
}

@http:ServiceConfig { basePath:"/",
    cors: {
        allowOrigins: ["*"], 
        allowHeaders: ["Authorization, Lang"]
    }
}
service chainPage on blockChainInterfaceEP {

public function constructRequest (string jsonRPCVersion, int networkId, string method, json params) returns http:Request {
    http:Request request = new;
    request.setHeader("Content-Type", "application/json");
    request.setJsonPayload({"jsonrpc":jsonRPCVersion, "id":networkId, "method":method, "params":params});
    return request;
}

public function resultToString(json jsonPayload) returns string {
    string result = jsonPayload["result"] != null ? jsonPayload["result"].toString() : "";
    return result;
}

public function setResponseError(json jsonResponse) returns error {
    map<string> details = { message: jsonResponse["error"].message.toString() };
    error err = error("(wso2/ethereum)EthereumError", details);
    return err;
}

   @http:ResourceConfig {
        methods:["POST"],
        path:"/",
        cors: {
            allowOrigins: ["*"]
        }
    }
    resource function respond(http:Caller caller, http:Request req, string name, string message) returns error? {
        var requestVariableMap = check req.getFormParams();
        string encryptedval = requestVariableMap["encryptedval"]  ?: "";
        string username = requestVariableMap["username"]  ?: "";
        var randKey = sessionMap[username] ?: "";
        string decryptedval = utils:decryptAes(encryptedval, randKey);

        if (decryptedval ==  "ack") {
           io:println("Welcome " + username);
           authenticatedMap[username] = true;
        } else{
           authenticatedMap[username] = false;
        }

        return;
    }


   @http:ResourceConfig {
        methods:["GET"],
        path:"/",
        cors: {
            allowOrigins: ["*"]
        }
    }
   resource function sayHello(http:Caller caller, http:Request req, string name, string message) {
        string resultBuffer = "";

        map<string> requestVariableMap = req. getQueryParams();
        var logoutFlag = requestVariableMap["logout"]  ?: "false";
        boolean flg = boolean.convert(logoutFlag);
        string uname = requestVariableMap["username"]  ?: "";
        
        string hostname = "localhost";

        if (caller.localAddress.host != "") {
        hostname= caller.localAddress.host;
        }

        string buffer = "http://" + hostname + ":9093";
    
        if (flg) {
            
            authenticatedMap[uname] = false;
            sessionMap[uname] = "";
            io:println(uname + " logged out.");

        http:Response res = new;
        res.setPayload(untaint buffer);
        res.setContentType("text/html; charset=utf-8");

        var result = caller->respond(res);
        if (result is error) {
                log:printError("Error sending response", err = result);
        }

            return;
        }

        string functionToCall = functionMap[uname] ?: "";
        http:Request request = new;
        request.setHeader("Content-Type", "application/json");
        request.setJsonPayload({"jsonrpc":"2.0", "id":"2000", "method":"eth_call", "params":[{"from": "0x88c9a72c84636bd5f39fe63cf4440214be31c061", "to":"0xbd7bc5b627cce81bf916b9f621ad79b96a4d7df1", "data": functionToCall}, "latest"]});
        
        string finalResult = "";
        boolean errorFlag = false;
        var httpResponse = ethereumClient -> post("/", request);
        if (httpResponse is http:Response) {
            int statusCode = httpResponse.statusCode;
            var jsonResponse = httpResponse.getJsonPayload();
            if (jsonResponse is json) {
                if (jsonResponse["error"] == null) {
                    string inputString = jsonResponse.result.toString();
                    finalResult = convertHexStringToString(inputString);
                } else {
                        error err = error("(wso2/ethereum)EthereumError",
                        { message: "Error occurred while accessing the JSON payload of the response" });
                        finalResult = jsonResponse["error"].toString();
                        errorFlag = true;
                }
            } else {
                error err = error("(wso2/ethereum)EthereumError",
                { message: "Error occurred while accessing the JSON payload of the response" });
                finalResult = jsonResponse.reason();
                errorFlag = true;
            }
        } else {
            error err = error("(wso2/ethereum)EthereumError", { message: "Error occurred while invoking the Ethererum API" });
            errorFlag = true;
        }

        if (!errorFlag) {
            string hashKey = untaint finalResult;
            io:ReadableCharacterChannel sourceChannel = new (io:openReadableFile("key-db/" + untaint uname + "/" + hashKey), "UTF-8");
            var readableRecordsChannel = new io:ReadableTextRecordChannel(sourceChannel, fs = ",", rs = "\n");
            while (readableRecordsChannel.hasNext()) {
                var result = readableRecordsChannel.getNext();
                if (result is string[]) {
                    string randKey = generateRandomKey(16);
                    sessionMap[uname] = randKey;
                    finalResult = utils:encryptRSAWithPublicKey(result[0], randKey);
                } else {
                    //return result; // An IO error occurred when reading the records.
                }
            }
        } else {
            io:println("An error has ocurred.");
        }

        http:Response res = new;
        // A util method that can be used to set string payload.
        res.setPayload(untaint finalResult);
        res.setContentType("text/html; charset=utf-8");
        res.setHeader("Access-Control-Allow-Origin", "*");
        res.setHeader("Access-Control-Allow-Methods", "POST,GET,PUT,DELETE");
        res.setHeader("Access-Control-Allow-Headers", "Authorization, Lang");
  
        // Sends the response back to the client.
        var result = caller->respond(res);
        if (result is error) {
            log:printError("Error sending response", err = result);
        }
   }
}

@http:WebSocketServiceConfig {
    path: "/basic/ws",
    subProtocols: ["xml", "json"],
    idleTimeoutInSeconds: 120
}
service basic on new http:WebSocketListener(9098) {

    string ping = "ping";
    byte[] pingData = ping.toByteArray("UTF-8");

    resource function onOpen(http:WebSocketCaller caller) {
        var err = caller->pushText(chatBuffer);
        if (err is error) {
            log:printError("Error occurred when sending text", err = err);
        }
    }

    resource function onText(http:WebSocketCaller caller, string text,
                                boolean finalFrame) {
        if (text == "ping") {
            var err = caller->ping(self.pingData);
            if (err is error) {
                log:printError("Error sending ping", err = err);
            }
        } else if (text == "closeMe") {
            _ = caller->close(statusCode = 1001,
                            reason = "You asked me to close the connection",
                            timeoutInSecs = 0);
        } else {
            chatBuffer += untaint text + "\r\n";
            var err = caller->pushText(chatBuffer);
            if (err is error) {
                log:printError("Error occurred when sending text", err = err);
            }

            io:println("Pinging...");
            var err2 = caller->ping(self.pingData);
            if (err2 is error) {
                log:printError("Error sending ping", err = err);
            }
        }
    }

    resource function onBinary(http:WebSocketCaller caller, byte[] b) {
        io:println("\nNew binary message received");
        io:print("UTF-8 decoded binary message: ");
        io:println(b);
        var err = caller->pushBinary(b);
        if (err is error) {
            log:printError("Error occurred when sending binary", err = err);
        }
    }

    resource function onPing(http:WebSocketCaller caller, byte[] data) {
        var err = caller->pong(data);
        if (err is error) {
            log:printError("Error occurred when closing the connection",
                            err = err);
        }
    }

    resource function onPong(http:WebSocketCaller caller, byte[] data) {
        io:println("Pong received");
    }

    resource function onIdleTimeout(http:WebSocketCaller caller) {
        io:println("\nReached idle timeout");
        io:println("Closing connection " + caller.id);
        var err = caller->close(statusCode = 1001, reason =
                                    "Connection timeout");
        if (err is error) {
            log:printError("Error occured when closing the connection",
                                err = err);
        }
    }

    resource function onError(http:WebSocketCaller caller, error err) {
        log:printError("Error occurred ", err = err);
    }

    resource function onClose(http:WebSocketCaller caller, int statusCode,
                                string reason) {
        io:println(string `Client left with {{statusCode}} because
                    {{reason}}`);
    }
}


public function convertHexStringToString(string inputString) returns (string) {
    int len = inputString.length();
    int counter = 0;
    string buffer = "";
    while (counter < len) {
        string s3 = inputString.substring(counter, counter+2);

        if (s3.equalsIgnoreCase("0x")) {
            counter += 2;
            continue;
        }

        var res1 = utils:hexToChar(s3);
        if (res1.length() != 0) {
            buffer += res1;
        }

        counter += 2;
    }

    return buffer;
}

public function generateRandomKey(int keyLen) returns (string){
    string buffer = "";
    int counter = 0;
    while (counter < keyLen) {
        buffer += utils:decToChar(65 + math:randomInRange(0, 26));
        counter += 1;
    }

    return buffer;
}

public function readHashFromBloackchain(string didmid) returns (string) {
            http:Request request = new;
            request.setHeader("Content-Type", "application/json");
            request.setJsonPayload({"jsonrpc":"2.0", "id":"2000", "method":"eth_getTransactionByHash", "params":[untaint didmid]});
            
            string finalResult = "";
            string pkHash = "";
            boolean errorFlag = false;
            var httpResponse = ethereumClient -> post("/", request);
            if (httpResponse is http:Response) {
                int statusCode = httpResponse.statusCode;
                var jsonResponse = httpResponse.getJsonPayload();
                if (jsonResponse is json) {
                    if (jsonResponse["error"] == null) {
                        finalResult = jsonResponse.result.toString();
                        pkHash = jsonResponse.result["input"].toString();
                    } else {
                            error err = error("(wso2/ethereum)EthereumError",
                            { message: "Error occurred while accessing the JSON payload of the response" });
                            finalResult = jsonResponse["error"].toString();
                            errorFlag = true;
                    }
                } else {
                    error err = error("(wso2/ethereum)EthereumError",
                    { message: "Error occurred while accessing the JSON payload of the response" });
                    finalResult = jsonResponse.reason();
                    errorFlag = true;
                }
            } else {
                error err = error("(wso2/ethereum)EthereumError", { message: "Error occurred while invoking the Ethererum API" });
                errorFlag = true;
            }

            return finalResult;
}