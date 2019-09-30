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
import ballerina/lang.'int;
import ballerina/stringutils;
import ballerina/runtime;

listener http:Listener uiEP = new(9097);
//listener http:Listener blockChainInterfaceEP = new(9096);

map<string> sessionMap = {};
map<boolean> authenticatedMap = {};
//map<string> functionMap = {"miyurud@wso2.com": "0x246e4756", "isurup@wso2.com": "0xc3d68039", "nadheesh@wso2.com": "0xe2a65ca2"};
//6d4ce63c
map<string> functionMap = {"miyurud@wso2.com": "0x6d4ce63c", "isurup@wso2.com": "0xc3d68039", "nadheesh@wso2.com": "0xe2a65ca2"};
string chatBuffer = "";

ethereum:EthereumConfiguration ethereumConfig = {
jsonRpcEndpoint: "http://192.168.32.1:8083",
jsonRpcVersion: "2.0",
networkId: "2000"
};

ethereum:Client ethereumClient = new(ethereumConfig);

string ethereumAccount = "0x3dd551059b5ba2fd8fe48bf5699bd54eea46bd53"; 

string jsonRpcEndpoint = ethereumConfig.jsonRpcEndpoint;
//http:Client ethereumClient = new(jsonRpcEndpoint, config = ethereumConfig.clientConfig);
//ethereum:Client ethereumClient = new(ethereumConfig);
boolean verifiableCredentialsFlag = true;

@http:ServiceConfig { basePath:"/" }
service uiService on uiEP {

   @http:ResourceConfig {
        methods:["GET"],
        path:"/"
    }
   resource function sayHello(http:Caller caller, http:Request req, string name, string message) {
        // io:ReadableByteChannel readableByteChannel = io:openReadableFile("web/login.html");
        io:ReadableByteChannel | io:Error readableByteChannel = io:openReadableFile("web/login.html");
        if (readableByteChannel is io:ReadableByteChannel){
        var readableCharChannel = new io:ReadableCharacterChannel(readableByteChannel, "UTF-8");
        var readableRecordsChannel = new io:ReadableTextRecordChannel(readableCharChannel);

        string buffer = "";

        while (readableRecordsChannel.hasNext()) {
            var result = readableRecordsChannel.getNext();
            if (result is string[]) {
                // string item = string.convert(result[0]);
                string item = (result[0]).toString();
                buffer += item;
            } else {
                 io:println("Error");
            }
        }
       
       http:Response res = new;

       if (caller.localAddress.host != "") {
        //    buffer= buffer.replace("localhost", caller.localAddress.host);
            buffer= stringutils:replace(buffer,"localhost", caller.localAddress.host);
       }

       res.setPayload(<@untainted> buffer);
       res.setContentType("text/html; charset=utf-8");

       var result = caller->respond(res);
       if (result is error) {
            log:printError("Error sending response", err = result);
            }
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
    //    map<string> requestVariableMap = req. getQueryParams();
        string did = req.getQueryParamValue("did") ?: "";
       //var did = requestVariableMap["did"] ?: "";
       authenticatedMap[did] = false;
       string buffer = "http://localhost:9097";
       
       http:Response res = new;

       if (caller.localAddress.host != "") {
           buffer= stringutils:replace(buffer,"localhost", caller.localAddress.host);
       }

       res.setPayload(<@untainted> buffer);
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
        io:println("Got request---->");
        map<string> requestVariableMap = check req.getFormParams();

    if (requestVariableMap["command"] == "authenticate") {
            var did = requestVariableMap["did"] ?: "";
            io:println("++++++++++++++++++++++++++++++>" + did);
            // did = did.replace("%2C", ",");
            did = stringutils:replace(did,"%2C", ",");
            int index2 = did.indexOf("\"id\": \"did:ethr:") ?: 0 + 16;
            string didmid = did.substring(index2, index2+64);

            index2 = did.indexOf("-----BEGIN PUBLIC KEY-----") ?: 0  + 26;

            int index3 = did.indexOf("-----END PUBLIC KEY-----") ?: 0;
            var publicKey = did.substring(index2, index3);

            didmid = "0x" + didmid;
            http:Request request = new;
            request.setHeader("Content-Type", "application/json");
            request.setJsonPayload({"jsonrpc":"2.0", "id":"2000", "method":"eth_getTransactionByHash", "params":[<@untainted> didmid]});
            
            string finalResult = "";
            string pkHash = "";
            boolean errorFlag = false;
            var httpResponse = ethereumClient -> post("/", request);
            if (httpResponse is http:Response) {
                int statusCode = httpResponse.statusCode;
                var jsonResponse = httpResponse.getJsonPayload();
                if (jsonResponse is map<json>[]) {
                    // if (jsonResponse is json) {
                    if (jsonResponse[0]["error"] == null) {
                        finalResult = jsonResponse[0].result.toString();
                        //finalResult = jsonResponse[0].result.toJsonString();
                        // pkHash = jsonResponse.result["input"].toString();
                        pkHash = jsonResponse[0].result["input"].toString();
                    } else {
                            error err = error("(wso2/ethereum)EthereumError", message="Error occurred while accessing the JSON payload of the response");
                            finalResult = jsonResponse[0]["error"].toString();
                            errorFlag = true;
                    }
                } else {
                    error err = error("(wso2/ethereum)EthereumError", message="Error occurred while accessing the JSON payload of the response");
                    finalResult = "Error occurred while accessing the JSON payload of the response";
                    errorFlag = true;
                }
            } else {
                error err = error("(wso2/ethereum)EthereumError", message="Error occurred while invoking the Ethererum API");
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
            res.setPayload(<@untainted> finalResult);
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

            io:println("=====+++======>DID:" + did);

            // did = did.replace("%2C", ",");
            did = stringutils:replace(did,"%2C", ",");
            //did = utils:binaryStringToString(did);
            // int index2 = did.indexOf("\"id\": \"did:ethr:") + 16;
            int index2 = did.indexOf("\"id\": \"did:ethr:") ?: 0 + 16;
            if(index2 is int){
            string didmid = did.substring(index2, index2+64);

            index2 = did.indexOf("-----BEGIN PUBLIC KEY-----") ?: 0 + 26;

            int index3 = did.indexOf("-----END PUBLIC KEY-----") ?: 0;
            var publicKey = did.substring(index2, index3);
            var didmidOrg = didmid;
            didmid = "0x" + didmid;
            
            string randKey = sessionMap[didmid] ?: "";

            if (encryptedval === randKey) {
                // var verifiableCredentialsList = getVerifiableCredentials(didmidOrg);

                io:println("Challenge response authentication was successful.");
                var finalResult = "successful";

                if(verifiableCredentialsFlag) {
                    io:println("Require verifiable credentials.");
                    finalResult = "successful|CountryCredential"; //Here we assume that chat service requires CountryCredential only.
                }

                http:Response res = new;
                // A util method that can be used to set string payload.
                res.setPayload(<@untainted> finalResult);
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
            }}
        } else if (requestVariableMap["command"] == "vcsubmit") {
            var did = requestVariableMap["did"] ?: "";
            //var publicKey = requestVariableMap["publicKey"] ?: "";
            io:println("------------>>>>>>>>>" + did);

            var vc = requestVariableMap["vc"] ?: "";
            //var publicKey = requestVariableMap["publicKey"] ?: "";
            io:println("------++++------>>>>>>>>>" + vc);
            int index2 = vc.indexOf("\"homeCountry\": {") ?: 0 + 41;
            string didmid = vc.substring(index2, index2 + 64);
            io:println("==?>" + didmid);
            string hash = readHashFromBloackchain("0x" + didmid);
            io:println("==+>" + hash);

            index2 = hash.indexOf("\"input\":\"") ?: 0 + 9;
            hash = hash.substring(index2, index2 + 66);
            io:println("==+++>" + hash);
            string hexEncodedString = "0x" + utils:hashSHA256("USA");
            string buffer2 = "";
            string hostname = "localhost";

            if (hash === hexEncodedString) {
                authenticatedMap[did] = true;
                buffer2 = "http://" + hostname + ":9097/home?did=" + did;
            } else {
                buffer2 = "http://" + hostname + ":9097";
            }

            io:println(buffer2);

            http:Response res = new;
            res.setPayload(<@untainted> buffer2);
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
        //map<string> requestVariableMap = req.getQueryParams();
        io:ReadableByteChannel | io:Error readableByteChannel = io:openReadableFile("web/home.html");
        if(readableByteChannel is io:ReadableByteChannel){
        var readableCharChannel = new io:ReadableCharacterChannel(readableByteChannel, "UTF-8");
        var readableRecordsChannel = new io:ReadableTextRecordChannel(readableCharChannel);

        string buffer = "";

        while (readableRecordsChannel.hasNext()) {
            var result = readableRecordsChannel.getNext();
            if (result is string[]) {
                // string item = string.convert(result[0]);
                string item = result[0].toString();
                buffer += item;
            } else {
                 io:println("Error");
            }
        }

       http:Response res = new;
    //    buffer = buffer.replace("uname", requestVariableMap["did"] ?: "abc");
            buffer = stringutils:replace(buffer,"uname", req.getQueryParamValue("did") ?: "abc");

       if (caller.localAddress.host != "") {
        //    buffer= buffer.replace("localhost", caller.localAddress.host);
             buffer= stringutils:replace(buffer,"localhost", caller.localAddress.host);
       }

       res.setPayload(<@untainted> buffer);
       res.setContentType("text/html; charset=utf-8");

       var result = caller->respond(res);
       if (result is error) {
            log:printError("Error sending response", err = result);
            }
   
        }
    }
}

// @http:ServiceConfig { basePath:"/",
//     cors: {
//         allowOrigins: ["*"], 
//         allowHeaders: ["Authorization, Lang"]
//     }
// }
// service chainPage on blockChainInterfaceEP {

// resource function constructRequest (string jsonRPCVersion, int networkId, string method, json params) returns http:Request {
//     //resource function constructRequest (string jsonRPCVersion, int networkId, string method, json params) returns http:Request {
//     http:Request request = new;
//     request.setHeader("Content-Type", "application/json");
//     request.setJsonPayload({"jsonrpc":jsonRPCVersion, "id":networkId, "method":method, "params":params});
//     return request;
// }

// resource function resultToString(json jsonPayload) returns string {
//     //resource function resultToString(json jsonPayload) returns string {
//     // string result = jsonPayload["result"] != null ? jsonPayload["result"].toString() : "";
//     string result = jsonPayload["result"] != null ? jsonPayload["result"].toJsonString() : "";
//     return result;
// }

// resource function setResponseError(json jsonResponse) returns error? {
//     map<string> details = { message: jsonResponse["error"].message.toString() };
//     error err = error("(wso2/ethereum)EthereumError", details);
//     return err;
// }

//    @http:ResourceConfig {
//         methods:["POST"],
//         path:"/",
//         cors: {
//             allowOrigins: ["*"]
//         }
//     }
//     resource function respond(http:Caller caller, http:Request req, string name, string message) returns error? {
//         var requestVariableMap = check req.getFormParams();
//         string encryptedval = requestVariableMap["encryptedval"]  ?: "";
//         string username = requestVariableMap["username"]  ?: "";
//         var randKey = sessionMap[username] ?: "";
//         string decryptedval = utils:decryptAes(encryptedval, randKey);

//         if (decryptedval ==  "ack") {
//            io:println("Welcome " + username);
//            authenticatedMap[username] = true;
//         } else{
//            authenticatedMap[username] = false;
//         }

//         return;
//     }


//    @http:ResourceConfig {
//         methods:["GET"],
//         path:"/",
//         cors: {
//             allowOrigins: ["*"]
//         }
//     }
//    resource function sayHello(http:Caller caller, http:Request req, string name, string message) {
//     string resultBuffer = "";

//     // map<string> requestVariableMap = req. getQueryParams();
//     // var logoutFlag = requestVariableMap["logout"]  ?: "false";
    
//     string logoutFlag = req.getQueryParamValue["logout"]  ?: "false";
//     boolean flg = boolean.convert(logoutFlag);
//     string uname = requestVariableMap["username"]  ?: "";
    
//     string hostname = "localhost";

//     if (caller.localAddress.host != "") {
//        hostname= caller.localAddress.host;
//     }

    

//     string buffer = "http://" + hostname + ":9093";
    
//     if (flg) {
        
//         authenticatedMap[uname] = false;
//         sessionMap[uname] = "";
//         io:println(uname + " logged out.");

//        http:Response res = new;
//        res.setPayload(<@untainted> buffer);
//        res.setContentType("text/html; charset=utf-8");

//        var result = caller->respond(res);
//        if (result is error) {
//             log:printError("Error sending response", err = result);
//        }

//         return;
//     }

    
//     string functionToCall = functionMap[uname] ?: "";
//     io:println("++++> hostname: " + functionToCall);
//     http:Request request = new;
//     request.setHeader("Content-Type", "application/json");
//     request.setJsonPayload({"jsonrpc":"2.0", "id":"2000", "method":"eth_call", "params":[{"from": "0x88c9a72c84636bd5f39fe63cf4440214be31c061", "to":"0xbd7bc5b627cce81bf916b9f621ad79b96a4d7df1", "data": functionToCall}, "latest"]});
    
//     string finalResult = "";
//     boolean errorFlag = false;
//     var httpResponse = ethereumClient -> post("/", request);
//     if (httpResponse is http:Response) {
//         int statusCode = httpResponse.statusCode;
//         var jsonResponse = httpResponse.getJsonPayload();
//         // if (jsonResponse is json) {
//         if (jsonResponse is map<json>[]) {
//             if (jsonResponse["error"] == null) {
//                 string inputString = jsonResponse.result.toString();
//                 finalResult = convertHexStringToString(inputString);
//             } else {
//                     error err = error("(wso2/ethereum)EthereumError",
//                     { message: "Error occurred while accessing the JSON payload of the response" });
//                     finalResult = jsonResponse["error"].toString();
//                     errorFlag = true;
//             }
//         } else {
//             error err = error("(wso2/ethereum)EthereumError",
//             { message: "Error occurred while accessing the JSON payload of the response" });
//             finalResult = jsonResponse.reason();
//             errorFlag = true;
//         }
//     } else {
//         error err = error("(wso2/ethereum)EthereumError", { message: "Error occurred while invoking the Ethererum API" });
//         errorFlag = true;
//     }

//     if (!errorFlag) {
//         string hashKey = <@untainted> finalResult;
//         io:ReadableCharacterChannel sourceChannel = new (io:openReadableFile("key-db/" + <@untainted> uname + "/" + hashKey), "UTF-8");
//         //io:ReadableCharacterChannel | io:Error  sourceChannel = new (io:openReadableFile("key-db/" + <@untainted> uname + "/" + hashKey), "UTF-8");
//         //if(sourceChannel is io:ReadableCharacterChannel){
//         var readableRecordsChannel = new io:ReadableTextRecordChannel(sourceChannel, fs = ",", rs = "\n");
//         while (readableRecordsChannel.hasNext()) {
//             var result = readableRecordsChannel.getNext();
//             if (result is string[]) {
//                 string randKey = generateRandomKey(16);
//                 sessionMap[uname] = randKey;
//                 finalResult = utils:encryptRSAWithPublicKey(result[0], randKey);
//             } else {
//                 //return result; // An IO error occurred when reading the records.
//             }
//         }
//     } else {
//         io:println("An error has ocurred.");
//     }

//        http:Response res = new;
//        // A util method that can be used to set string payload.
//        res.setPayload(<@untainted> finalResult);
//        res.setContentType("text/html; charset=utf-8");
//        res.setHeader("Access-Control-Allow-Origin", "*");
//        res.setHeader("Access-Control-Allow-Methods", "POST,GET,PUT,DELETE");
//        res.setHeader("Access-Control-Allow-Headers", "Authorization, Lang");
  
//        // Sends the response back to the client.
//        var result = caller->respond(res);
//        if (result is error) {
//             log:printError("Error sending response", err = result);
//        }
//    }
// }


// @http:WebSocketServiceConfig {
//     path: "/basic/ws",
//     subProtocols: ["xml", "json"],
//     idleTimeoutInSeconds: 120
// }
// service basic on new http:WebSocketListener(9098) {

//     string ping = "ping";
//     byte[] pingData = ping.toByteArray("UTF-8");

//     resource function onOpen(http:WebSocketCaller caller) {
//         io:println("\nNew client connected");
//         io:println("Connection ID: " + caller.id);
//         io:println("Negotiated Sub protocol: " + caller.negotiatedSubProtocol);
//         io:println("Is connection open: " + caller.isOpen);
//         io:println("Is connection secured: " + caller.isSecure);

//         var err = caller->pushText(chatBuffer);
//         if (err is error) {
//             log:printError("Error occurred when sending text", err = err);
//         }
//     }

//     resource function onText(http:WebSocketCaller caller, string text,
//                                 boolean finalFrame) {
//         io:println("\ntext message: " + text + " & final fragment: "
//                                                         + finalFrame);

//         if (text == "ping") {
//             io:println("Pinging...");
//             var err = caller->ping(self.pingData);
//             if (err is error) {
//                 log:printError("Error sending ping", err = err);
//             }
//         } else if (text == "closeMe") {
//             _ = caller->close(statusCode = 1001,
//                             reason = "You asked me to close the connection",
//                             timeoutInSecs = 0);
//         } else {
//             chatBuffer += <@untainted> text + "\r\n";
//             var err = caller->pushText(chatBuffer);
//             if (err is error) {
//                 log:printError("Error occurred when sending text", err = err);
//             }

//             io:println("Pinging...");
//             var err2 = caller->ping(self.pingData);
//             if (err2 is error) {
//                 log:printError("Error sending ping", err = err);
//             }
//         }
//     }

//     resource function onBinary(http:WebSocketCaller caller, byte[] b) {
//         io:println("\nNew binary message received");
//         io:print("UTF-8 decoded binary message: ");
//         io:println(b);
//         var err = caller->pushBinary(b);
//         if (err is error) {
//             log:printError("Error occurred when sending binary", err = err);
//         }
//     }

//     resource function onPing(http:WebSocketCaller caller, byte[] data) {
//         var err = caller->pong(data);
//         if (err is error) {
//             log:printError("Error occurred when closing the connection",
//                             err = err);
//         }
//     }

//     resource function onPong(http:WebSocketCaller caller, byte[] data) {
//         io:println("Pong received");
//     }

//     resource function onIdleTimeout(http:WebSocketCaller caller) {
//         io:println("\nReached idle timeout");
//         io:println("Closing connection " + caller.id);
//         var err = caller->close(statusCode = 1001, reason =
//                                     "Connection timeout");
//         if (err is error) {
//             log:printError("Error occured when closing the connection",
//                                 err = err);
//         }
//     }

//     resource function onError(http:WebSocketCaller caller, error err) {
//         log:printError("Error occurred ", err = err);
//     }

//     resource function onClose(http:WebSocketCaller caller, int statusCode,
//                                 string reason) {
//         io:println(string `Client left with {{statusCode}} because
//                     {{reason}}`);
//     }
// }

string ping = "ping";
byte[] pingData = ping.toBytes();

@http:WebSocketServiceConfig {
    path: "/basic/ws",
    subProtocols: ["xml", "json"],
    idleTimeoutInSeconds: 120
}
service basic on new http:Listener(9098) {

    // string ping = "ping";
    // //byte[] pingData = ping.toByteArray("UTF-8");
    // byte[] pingData = ping.toBytes();

    resource function onOpen(http:WebSocketCaller caller) {
        io:println("\nNew client connected");
        io:println("Connection ID: " + caller.getConnectionId());
        io:println("Negotiated Sub protocol: " + caller.getNegotiatedSubProtocol().toString());
        io:println("Is connection open: " + caller.isOpen().toString());
        io:println("Is connection secured: " + caller.isSecure().toString());

        while(true) {
            var err = caller->pushText(chatBuffer);
            if (err is error) {
                log:printError("Error occurred when sending text", err = err);
            }
            runtime:sleep(1000);
        }
    }

    resource function onText(http:WebSocketCaller caller, string text,
                                boolean finalFrame) {
        io:println("\ntext message: " + text + " & final fragment: "
                                                        + finalFrame.toString());

        if (text == "ping") {
            io:println("Pinging...");
            var err = caller->ping(pingData);
            if (err is http:WebSocketError) {
                log:printError("Error sending ping", <error> err);
            }
        } else if (text == "closeMe") {
            // var err = caller->close(statusCode = 1001,
            //                 reason = "You asked me to close the connection",
            //                 timeoutInSecs = 0);
            error? result = caller->close(statusCode = 1001,
                            reason = "You asked me to close the connection",
                            timeoutInSeconds = 0);
            if (result is http:WebSocketError) {
                log:printError("Error occurred when closing connection", <error> result);
            }
        } else {
            // chatBuffer = <@untainted> text + "\r\n";
            // var err = caller->pushText(chatBuffer);
            // if (err is error) {
            //     log:printError("Error occurred when sending text", err = err);
            // }

            // io:println("Pinging...");
            // var err2 = caller->ping(self.pingData);
            // if (err2 is error) {
            //     log:printError("Error sending ping", err = err);
            chatBuffer += text + "\r\n";
            var err = caller->pushText(chatBuffer);
            if (err is error) {
                log:printError("Error occurred when sending text", err = err);
            }
        }
    }

    resource function onBinary(http:WebSocketCaller caller, byte[] b) {
        io:println("\nNew binary message received");
        io:print("UTF-8 decoded binary message: ");
        io:println(b);
        var err = caller->pushBinary(b);
        if (err is http:WebSocketError) {
            log:printError("Error occurred when sending binary", <error>  err);
        }
    }

    resource function onPing(http:WebSocketCaller caller, byte[] data) {
        var err = caller->pong(data);
        //if (err is error) {
        if (err is http:WebSocketError) {
            // log:printError("Error occurred when closing the connection", err = err);
            log:printError("Error occurred when closing the connection", <error> err);
        
        }
    }

    resource function onPong(http:WebSocketCaller caller, byte[] data) {
        io:println("Pong received");
    }

    resource function onIdleTimeout(http:WebSocketCaller caller) {
        io:println("\nReached idle timeout");
        // io:println("Closing connection " + caller.id);
        // var err = caller->close(statusCode = 1001, reason =
        //                             "Connection timeout");
        // if (err is error) {
        //     log:printError("Error occured when closing the connection",
        //                         err = err);
        // }
        io:println("Closing connection " + caller.getConnectionId());
        var err = caller->close(statusCode = 1001, reason =
                                    "Connection timeout");
        if (err is http:WebSocketError) {
            log:printError("Error occurred when closing the connection", <error> err);
        }
    }

    resource function onError(http:WebSocketCaller caller, error err) {
        // log:printError("Error occurred ", err = err);
        log:printError("Error occurred ", <error> err);
    }

    resource function onClose(http:WebSocketCaller caller, int statusCode,
                                string reason) {
        // io:println(string `Client left with {{statusCode}} because
        //             {{reason}}`);
        io:println(string `Client left with ${statusCode} because
                    ${reason}`);
    }
}



public function convertHexStringToString(string inputString) returns (string) {
    // int len = inputString.length();
    int len = inputString.toString().length();
    int counter = 0;
    string buffer = "";
    while (counter < len) {
        string s3 = inputString.substring(counter, counter+2);

        // if (s3.equalsIgnoreCase("0x")) {
            if (stringutils:equalsIgnoreCase(s3,"0x")) {
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
        int | error randVal = math:randomInRange(0, 26);
        int newVal = 0;
        if (randVal is int) {
            newVal = randVal;
        }

        buffer += utils:decToChar(65 + newVal);
        counter += 1;
    }

    return buffer;
}

public function readHashFromBloackchain(string didmid) returns (string) {
            http:Request request = new;
            request.setHeader("Content-Type", "application/json");
            request.setJsonPayload({"jsonrpc":"2.0", "id":"2000", "method":"eth_getTransactionByHash", "params":[<@untainted> didmid]});
            
            string finalResult = "";
            string pkHash = "";
            boolean errorFlag = false;
            var httpResponse = ethereumClient -> post("/", request);
            if (httpResponse is http:Response) {
                int statusCode = httpResponse.statusCode;
                var jsonResponse = httpResponse.getJsonPayload();
                // if (jsonResponse is json) {
                    if (jsonResponse is map<json>[]) {
                    if (jsonResponse[0]["error"] == null) {
                        finalResult = jsonResponse[0].result.toString();
                        //pkHash = jsonResponse[0].result["input"].toString();
                        pkHash = jsonResponse[0].result.toString();
                    } else {
                            error err = error("(wso2/ethereum)EthereumError", message="Error occurred while accessing the JSON payload of the response");
                            finalResult = jsonResponse[0]["error"].toString();
                            errorFlag = true;
                    }
                } else {
                    error err = error("(wso2/ethereum)EthereumError", message="Error occurred while accessing the JSON payload of the response");
                    finalResult = "Error occurred while accessing the JSON payload of the response";
                    errorFlag = true;
                }
            } else {
                error err = error("(wso2/ethereum)EthereumError", message="Error occurred while invoking the Ethererum API");
                errorFlag = true;
            }

            return finalResult;
}