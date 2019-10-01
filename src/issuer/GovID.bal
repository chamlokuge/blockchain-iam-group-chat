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
import ballerina/math;
import ballerinax/java.jdbc;
import wso2/ethereum;
import wso2/utils;
import ballerina/runtime;
import ballerina/time;
import ballerina/stringutils;
import ballerina/jsonutils;

listener http:Listener uiGovIDLogin = new(9090);

jdbc:Client ssiDB = new({
        url: "jdbc:mysql://192.168.32.1:3306/ssidb",
        username: "test",
        password: "test",
        dbOptions: { useSSL: false }
    });

map<string> sessionMap = {};
map<boolean> authenticatedMap = {};
map<string> userMap = {"carol": "123", "dion" : "456"};
string chatBuffer = "";
string pk = "";
string randomKey = "";

ethereum:EthereumConfiguration ethereumConfig = {
    jsonRpcEndpoint: "http://192.168.32.1:8083",
    jsonRpcVersion: "2.0",
    networkId: "2000"
};

string ethereumAccount = "0x3dd551059b5ba2fd8fe48bf5699bd54eea46bd53";

string jsonRpcEndpoint = ethereumConfig.jsonRpcEndpoint;
http:Client ethereumClient = new ("http://192.168.32.1:8083");

@http:ServiceConfig { basePath:"/",
    cors: {
        allowOrigins: ["*"], 
        allowHeaders: ["Authorization, Lang"]
    } 
}
service uiServiceGovIDLogin on uiGovIDLogin {

   @http:ResourceConfig {
        methods:["GET"],
        path:"/",
        cors: {
            allowOrigins: ["*"],
            allowHeaders: ["Authorization, Lang"]
        }
    }
   resource function displayLoginPage(http:Caller caller, http:Request req) {
       string buffer = readFile("web/govid-login.html");
       
       http:Response res = new;

       if (caller.localAddress.host != "") {
           buffer= stringutils:replace(buffer,"localhost", caller.localAddress.host);
       }

       res.setPayload(<@untainted> buffer);
       res.setContentType("text/html; charset=utf-8");
       res.setHeader("Access-Control-Allow-Origin", "*");
       res.setHeader("Access-Control-Allow-Methods", "POST,GET,PUT,DELETE");
       res.setHeader("Access-Control-Allow-Headers", "Authorization, Lang");

       var result = caller->respond(res);
       if (result is error) {
            log:printError("Error sending response", err = result);
       }
   }

    @http:ResourceConfig {
        methods:["POST"],
        path:"/authenticate",
        cors: {
            allowOrigins: ["*"],
            allowHeaders: ["Authorization, Lang"]
        }
    }
   resource function processLogin(http:Caller caller, http:Request req) returns error?{
        var requestVariableMap = check req.getFormParams();
        string username = requestVariableMap["username"]  ?: "";
        string password = requestVariableMap["pwd"]  ?: "";
        var authenticated = false;

        foreach var x in userMap {
            if (stringutils:equalsIgnoreCase(username,x[0]) && stringutils:equalsIgnoreCase(password,x[1])) {
                io:println("Welcome " + username);
                authenticatedMap[username] = true;
                var result = caller->respond("success");
                if (result is error) {
                    log:printError("Error sending response", err = result);
                } else {
                    authenticated = true;
                }
                break;
            }
        }

        if (!authenticated) {
            var result = caller->respond("failed");
            if (result is error) {
                log:printError("Error sending response", err = result);
            }
        }

        return;
   }

    @http:ResourceConfig {
        methods:["GET"],
        path:"/home",
        cors: {
            allowOrigins: ["*"],
            allowHeaders: ["Authorization, Lang"]
        }
    }
   resource function displayLoginPage2(http:Caller caller, http:Request req) returns error? {
       string username = req.getQueryParamValue("username") ?: "";

       if ((!(stringutils:equalsIgnoreCase(username,""))) && authenticatedMap[username] == true) {
            string buffer = readFile("web/govid-request.html");
            
            http:Response res = new;

            if (caller.localAddress.host != "") {
                buffer= stringutils:replace(buffer,"localhost", caller.localAddress.host);
                buffer= stringutils:replace(buffer,"EMPTYUNAME", username);
            }

            res.setPayload(<@untainted> buffer);
            res.setContentType("text/html; charset=utf-8");
            res.setHeader("Access-Control-Allow-Origin", "*");
            res.setHeader("Access-Control-Allow-Methods", "POST,GET,PUT,DELETE");
            res.setHeader("Access-Control-Allow-Headers", "Authorization, Lang");

            var result = caller->respond(res);
            if (result is error) {
                    log:printError("Error sending response", err = result);
            }
        } else {
            io:println("Error login");

            string buffer = readFile("web/error.html");
            string hostname = "localhost";

            if (caller.localAddress.host != "") {
                hostname= caller.localAddress.host;
            }

            buffer = stringutils:replace(buffer,"MSG", "Re-try login via : <a href='http://" + caller.localAddress.host + ":9090'>Login Page</a>");

            http:Response res = new;
            res.setPayload(<@untainted> buffer);
            res.setContentType("text/html; charset=utf-8");
            res.setHeader("Access-Control-Allow-Origin", "*");
            res.setHeader("Access-Control-Allow-Methods", "POST,GET,PUT,DELETE");
            res.setHeader("Access-Control-Allow-Headers", "Authorization, Lang");

            var result = caller->respond(res);
            if (result is error) {
                    log:printError("Error sending response", err = result);
            }
        }
   }

    @http:ResourceConfig {
        methods:["GET"],
        path:"/govid-request.css",
        cors: {
            allowOrigins: ["*"],
            allowHeaders: ["Authorization, Lang"]
        }
    }
   resource function sendGOVIDRequest(http:Caller caller, http:Request req) {
       http:Response res = new;

       res.setFileAsPayload("web/govid-request.css", contentType = "text/css");
       res.setContentType("text/css; charset=utf-8");

       var result = caller->respond(res);
       if (result is error) {
            log:printError("Error sending response", err = result);
       }
   }

    @http:ResourceConfig {
        methods:["GET"],
        path:"/bundle.js",
        cors: {
            allowOrigins: ["*"],
            allowHeaders: ["Authorization, Lang"]
        }
    }
   resource function sendBundle(http:Caller caller, http:Request req) {
       http:Response res = new;

       res.setFileAsPayload("web/bundle.js", contentType = "text/javascript");
       res.setContentType("text/javascript; charset=utf-8");

       var result = caller->respond(res);
       if (result is error) {
            log:printError("Error sending response", err = result);
       }
   }

    @http:ResourceConfig {
        methods:["GET"],
        path:"/FileSaver.js",
        cors: {
            allowOrigins: ["*"],
            allowHeaders: ["Authorization, Lang"]
        }
    }
   resource function sendFileSaver(http:Caller caller, http:Request req) {
       http:Response res = new;

       res.setFileAsPayload("web/FileSaver.js", contentType = "text/javascript");
       res.setContentType("text/javascript; charset=utf-8");

       var result = caller->respond(res);
       if (result is error) {
            log:printError("Error sending response", err = result);
       }
   }

    @http:ResourceConfig {
        methods:["POST"],
        path:"/submit",
        cors: {
            allowOrigins: ["*"],
            allowHeaders: ["Authorization, Lang"]
        }
    }
   resource function processRegistration(http:Caller caller, http:Request req) returns error?{
        var requestVariableMap = check req.getFormParams();
        string firstName = requestVariableMap["firstName"]  ?: "";
        string lastName = requestVariableMap["lastName"]  ?: "";
        string streetAddress = requestVariableMap["streetAddress"]  ?: "";
        string city = requestVariableMap["city"]  ?: "";
        string state = requestVariableMap["state"]  ?: "";
        string postcode = requestVariableMap["postcode"]  ?: "";
        string country = requestVariableMap["country"]  ?: "";
        string date = requestVariableMap["date"]  ?: "";
        string did = requestVariableMap["did"]  ?: "";

        int index = did.indexOf("\"id\": \"did:ethr:") ?: 0 + 16;
        did = did.substring(index, index+64);

        io:println(("insert into ssidb.govid(firstname, lastname, streetaddress, city, state, country, postcode, dob ,did) " + "values ('"+ firstName +"', '" + lastName + "', '" + streetAddress + "', '"+ city +"', '"+ state +"', '" + postcode + "', '" + country + "', '" + date + "', '" + did + "');"));

        var ret = ssiDB->update(<@untainted> ("insert into ssidb.govid(firstname, lastname, streetaddress, city, state, postcode, country, dob, did) " + "values ('"+ firstName +"', '" + lastName + "', '" + streetAddress + "', '"+ city +"', '"+ state +"', '" + postcode + "', '" + country + "','" + date + "', '" + did + "');"));
        var result = caller->respond("done");

        if (result is error) {
            log:printError("Error sending response", err = result);
        }

        return;
   }

   @http:ResourceConfig {
        methods:["GET"],
        path:"/logout",
        cors: {
            allowOrigins: ["*"],
            allowHeaders: ["Authorization, Lang"]
        }
    }
   resource function logout(http:Caller caller, http:Request req) {
       var requestVariableMap = req.getQueryParams();
       string username = req.getQueryParamValue("username")  ?: "";

       if ((!(stringutils:equalsIgnoreCase(username,""))) && authenticatedMap[username] == true) {
           authenticatedMap[username] = false;
       }

       string buffer = readFile("web/govid-login.html");
       
       http:Response res = new;

       if (caller.localAddress.host != "") {
           buffer= stringutils:replace(buffer,"localhost", caller.localAddress.host);
       }

       res.setPayload(<@untainted> buffer);
       res.setContentType("text/html; charset=utf-8");
       res.setHeader("Access-Control-Allow-Origin", "*");
       res.setHeader("Access-Control-Allow-Methods", "POST,GET,PUT,DELETE");
       res.setHeader("Access-Control-Allow-Headers", "Authorization, Lang");

       var result = caller->redirect(res,  http:REDIRECT_TEMPORARY_REDIRECT_307,
            ["http://localhost:9090/"]);
       if (result is error) {
            log:printError("Error sending response", err = result);
       }
   }

    @http:ResourceConfig {
        methods:["POST"],
        path:"/api",
        cors: {
            allowOrigins: ["*"],
            allowHeaders: ["Authorization, Lang"]
        }
    }
   resource function api(http:Caller caller, http:Request req) returns error?{
        var requestVariableMap = check req.getFormParams();
       
       if (requestVariableMap["command"] == "cmd1") {
            if (requestVariableMap.hasKey("secureToken") && (!stringutils:equalsIgnoreCase(randomKey,requestVariableMap["secureToken"] ?: ""))) {
                io:println("incorrect sec token");
                var result = caller->respond("incorrect-token");

                if (result is error) {
                    log:printError("Error sending response", err = result);
                }
            } else {
                if (requestVariableMap.hasKey("did")) {
                    pk = <@untainted> requestVariableMap["did"]  ?: "";
                    var result = caller->respond("done");

                    if (result is error) {
                        log:printError("Error sending response", err = result);
                    }
                }
            }
        } else if (requestVariableMap["command"] == "requestvc") {
            var did = requestVariableMap["did"] ?: "";
            did = stringutils:replace(did,"%2C", ",");
            did = utils:binaryStringToString(did);

            int index2 = did.indexOf("\"id\": \"did:ethr:") ?: 0 + 16;
            string didmid = did.substring(index2, index2+64);

            index2 = did.indexOf("-----BEGIN PUBLIC KEY-----") ?: 0 + 26;

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
                    if (jsonResponse[0]["error"] == null) {
                        finalResult = jsonResponse[0].result.toString();
                        pkHash = jsonResponse[0].input.toString();
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
        } else if (requestVariableMap ["command"] == "encresponse") {
            var did = requestVariableMap["did"] ?: "";
            var encryptedval = requestVariableMap["encryptedval"] ?: "";

            did = stringutils:replace(did,"%2C", ",");
            did = utils:binaryStringToString(did);

            int index2 = did.indexOf("\"id\": \"did:ethr:") ?: 0 + 16;
            string didmid = did.substring(index2, index2+64);

            index2 = did.indexOf("-----BEGIN PUBLIC KEY-----")  ?: 0 + 26 ;

            int index3 = did.indexOf("-----END PUBLIC KEY-----") ?: 0;
            var publicKey = did.substring(index2, index3);
            var didmidOrg = didmid;
            didmid = "0x" + didmid;
            
            string randKey = sessionMap[didmid]?: "";

            if (encryptedval === randKey) {
                var verifiableCredentialsList = getVerifiableCredentials(didmidOrg);

                http:Response res = new;
                // A util method that can be used to set string payload.
                res.setPayload(<@untainted> verifiableCredentialsList);
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
        }
   }

   @http:ResourceConfig {
        methods:["POST"],
        path:"/secureTokenAPI",
        cors: {
            allowOrigins: ["*"],
            allowHeaders: ["Authorization, Lang"]
        }
    }
   resource function secTokenAPI(http:Caller caller, http:Request req) returns error?{
        var requestVariableMap = check req.getFormParams();
       
       if (requestVariableMap.hasKey("randomKey")) {
        randomKey = <@untainted> requestVariableMap["randomKey"]  ?: "";
       }

        var result = caller->respond("done");

        if (result is error) {
            log:printError("Error sending response", err = result);
        }
   }
}
string ping = "ping";
byte[] pingData = ping.toBytes();

@http:WebSocketServiceConfig {
    path: "/basic/ws",
    subProtocols: ["xml", "json"],
    idleTimeoutInSeconds: 120
}
service basic on new http:Listener(9095) {
    resource function onOpen(http:WebSocketCaller caller) {
        io:println("\nNew client connected");
        io:println("Connection ID: " + caller.getConnectionId());
        io:println("Negotiated Sub protocol: " + caller.getNegotiatedSubProtocol().toString());
        io:println("Is connection open: " + caller.isOpen().toString());
        io:println("Is connection secured: " + caller.isSecure().toString());

        while(true) {
            var err = caller->pushText(pk);
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
            error? result = caller->close(statusCode = 1001,
                            reason = "You asked me to close the connection",
                            timeoutInSeconds = 0);
            if (result is http:WebSocketError) {
                log:printError("Error occurred when closing connection", <error> result);
            }
        } else {
            var err = caller->pushText("You said: " + text);
            if (err is http:WebSocketError) {
                log:printError("Error occurred when sending text", <error> err);
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
        if (err is http:WebSocketError) {
            log:printError("Error occurred when closing the connection", <error> err);        
        }
    }

    resource function onPong(http:WebSocketCaller caller, byte[] data) {
        io:println("Pong received");
    }

    resource function onIdleTimeout(http:WebSocketCaller caller) {
        io:println("\nReached idle timeout");

        io:println("Closing connection " + caller.getConnectionId());
        var err = caller->close(statusCode = 1001, reason =
                                    "Connection timeout");
        if (err is http:WebSocketError) {
            log:printError("Error occurred when closing the connection", <error> err);
        }
    }

    resource function onError(http:WebSocketCaller caller, error err) {
        log:printError("Error occurred ", <error> err);
    }

    resource function onClose(http:WebSocketCaller caller, int statusCode,
                                string reason) {
        io:println(string `Client left with ${statusCode} because
                    ${reason}`);
    }
}


public function readFile(string filePath) returns string {
    string buffer = "";
    io:ReadableByteChannel | io:Error readableByteChannel = io:openReadableFile(filePath);
    if (readableByteChannel is io:ReadableByteChannel) {

        io:ReadableCharacterChannel | io:Error readableCharChannel = new io:ReadableCharacterChannel(readableByteChannel, "UTF-8");

        if (readableCharChannel is io:ReadableCharacterChannel) {
            var readableRecordsChannel = new io:ReadableTextRecordChannel(readableCharChannel, fs = ",", rs = "\n");
            while (readableRecordsChannel.hasNext()) {
                var result = readableRecordsChannel.getNext();
                if (result is string[]) {
                    string item = <@untainted>result[0].toString();
                    buffer += item;
                } else {
                    io:println("Error");
                }
            }
        }
    }

    return buffer;
}

public function generateRandomKey(int keyLen) returns (string){
    string buffer = "";
    int counter = 0;
    while (counter < keyLen) {
        int|error randVal = math:randomInRange(0, 26);
        int n = 0;
        if (randVal is int) {
            n = randVal;
        }

        buffer += utils:decToChar(65 + n);
        counter += 1;
    }

    return buffer;
}

public function getVerifiableCredentials(string didmid) returns (string) {
    time: Time currentTime = time:currentTime();
    string | error timeStr = time:format(currentTime,"dd-MM-yyyy");
    string customTimeString = "";
    if (timeStr is string) {
        customTimeString = timeStr;
    }

    string country = "";
    string firstname = "";
    var selectRet = ssiDB->select(<@untainted> "select country, firstname from ssidb.govid where (did LIKE '"+ <@untainted> didmid +"');", ());

    if (selectRet is table<record {}>) {
        io:println("\n the table into json");
        json jsonConversionRet = jsonutils:fromTable(selectRet);
        country = jsonConversionRet.country.toString();
        firstname = jsonConversionRet.firstname.toString();
    }

    string finalResult = sendTransactionAndgetHash(country);

    string countryCredential = "|||" + didmid + "," + finalResult + ",http://ip6-localhost:9090/api,CountryCredential" + "||| " + "{
  // set the context, which establishes the special terms we will be using
  // such as 'issuer' and 'alumniOf'.
  \"@context\": [
    \"https://www.w3.org/2018/credentials/v1\",
    \"https://www.w3.org/2018/credentials/examples/v1\"
  ],
  // specify the identifier for the credential
  \"id\": \"http://localhost:9090/credentials/1\",
  // the credential types, which declare what data to expect in the credential
  \"type\": [\"VerifiableCredential\", \"CountryCredential\"],
  // the entity that issued the credential
  \"issuer\": \"http://ip6-localhost:9090/api\",
  // when the credential was issued
  \"issuanceDate\": \"" + customTimeString + "\",
  // claims about the subjects of the credential
  \"credentialSubject\": {
    // identifier for the only subject of the credential
    \"id\": \"did:ethr:" + didmid + "\",
    // assertion about the only subject of the credential
    \"homeCountry\": {
      \"id\": \"did:ethr:" + finalResult + "\",
      \"name\": [{
        \"value\": \"home country\",
        \"lang\": \"en\"
      }, {
        \"value\": \"" + country + "\",
        \"lang\": \"en\"
      }]
    }
  },
  // digital proof that makes the credential tamper-evident
  // see the NOTE at end of this section for more detail
  \"proof\": {
    // the cryptographic signature suite that was used to generate the signature
    \"type\": \"RsaSignature2018\",
    // the date the signature was created
    \"created\": \"2017-06-18T21:19:10Z\",
    // purpose of this proof
    \"proofPurpose\": \"assertionMethod\",
    // the identifier of the public key that can verify the signature
    \"verificationMethod\": \"https://example.edu/issuers/keys/1\",
    // the digital signature value
    \"jws\": \"eyJhbGciOiJSUzI1NiIsImI2NCI6ZmFsc2UsImNyaXQiOlsiYjY0Il19..TCYt5X
      sITJX1CxPCT8yAV-TVkIEq_PbChOMqsLfRoPsnsgw5WEuts01mq-pQy7UJiN5mgRxD-WUc
      X16dUEMGlv50aqzpqh4Qktb3rk-BuQy72IFLOqV0G_zS245-kronKb78cPN25DGlcTwLtj
      PAYuNzVBAh4vGHSrQyHUdBBPM\"
  }
}";

return countryCredential;
}

public function sendTransactionAndgetHash(string data) returns (string) {
                http:Request request2 = new;
            request2.setHeader("Content-Type", "application/json");
            request2.setJsonPayload({"jsonrpc":"2.0", "id":"2000", "method":"personal_unlockAccount", "params": [ethereumAccount,"1234",null]});

            string finalResult2 = "";
            boolean errorFlag2 = false;
            var httpResponse2 = ethereumClient -> post("/", request2);

            if (httpResponse2 is http:Response) {
                int statusCode = httpResponse2.statusCode;
                var jsonResponse = httpResponse2.getJsonPayload();
                if (jsonResponse is map<json>[]) {
                    if (jsonResponse[0]["error"] == null) {
                        finalResult2 = jsonResponse[0].result.toString();
                    } else {
                            error err = error("(wso2/ethereum)EthereumError", message="Error occurred while accessing the JSON payload of the response");
                            finalResult2 = jsonResponse[0]["error"].toString();
                            errorFlag2 = true;
                    }
                } else {
                    error err = error("(wso2/ethereum)EthereumError", message="Error occurred while accessing the JSON payload of the response");
                    finalResult2 = "Error occurred while accessing the JSON payload of the response";
                    errorFlag2 = true;
                }
            } else {
                error err = error("(wso2/ethereum)EthereumError", message="Error occurred while invoking the Ethererum API");
                errorFlag2 = true;
            }

            string hexEncodedString = "0x" + utils:hashSHA256(data);

            //Next we will write the blockchain record
            http:Request request = new;
            request.setHeader("Content-Type", "application/json");
            request.setJsonPayload({"jsonrpc":"2.0", "id":"2000", "method":"eth_sendTransaction", "params":[{"from": ethereumAccount, "to":"0x6814412628addef8989ee696a67b0fad5d62735e", "data": hexEncodedString}]});

            string finalResult = "";
            boolean errorFlag = false;
            var httpResponse = ethereumClient -> post("/", request);
            if (httpResponse is http:Response) {
                int statusCode = httpResponse.statusCode;
                var jsonResponse = httpResponse.getJsonPayload();
                if (jsonResponse is map<json>[]) {
                    if (jsonResponse[0]["error"] == null) {
                        finalResult = jsonResponse[0].result.toString();
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