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
import ballerina/mysql;
import ballerina/sql;
import wso2/ethereum;
import wso2/utils;
import ballerina/runtime;
import ballerina/time;

listener http:Listener uiGovIDLogin = new(9090);

mysql:Client ssiDB = new({
        host: "192.168.32.1",
        port: 3306,
        name: "ssidb",
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
jsonRpcEndpoint: "http://192.168.32.1:8081",
jsonRpcVersion: "2.0",
networkId: "2000"
};

string ethereumAccount = "0xee0727d9e94dbb230233ea4bd362e4c081aabf38";

string jsonRpcEndpoint = ethereumConfig.jsonRpcEndpoint;
http:Client ethereumClient = new(jsonRpcEndpoint, config = ethereumConfig.clientConfig);

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
   resource function displayLoginPage(http:Caller caller, http:Request req, string name, string message) {
       string buffer = readFile("web/govid-login.html");
       
       http:Response res = new;

       if (caller.localAddress.host != "") {
           buffer= buffer.replace("localhost", caller.localAddress.host);
       }

       res.setPayload(untaint buffer);
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
   resource function processLogin(http:Caller caller, http:Request req, string name, string message) returns error?{
        var requestVariableMap = check req.getFormParams();
        string username = requestVariableMap["username"]  ?: "";
        string password = requestVariableMap["pwd"]  ?: "";
        var authenticated = false;

        foreach var x in userMap {
            if (username.equalsIgnoreCase(x[0]) && password.equalsIgnoreCase(x[1])) {
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
   resource function displayLoginPage2(http:Caller caller, http:Request req, string name, string message) returns error? {
       var requestVariableMap = req.getQueryParams();
       string username = requestVariableMap["username"]  ?: "";

       if ((!(username.equalsIgnoreCase(""))) && authenticatedMap[username] == true) {
            string buffer = readFile("web/govid-request.html");
            
            http:Response res = new;

            if (caller.localAddress.host != "") {
                buffer= buffer.replace("localhost", caller.localAddress.host);
                buffer= buffer.replace("EMPTYUNAME", username);
            }

            res.setPayload(untaint buffer);
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
            buffer = buffer.replace("MSG", "Re-try login via : <a href='http://" + caller.localAddress.host + ":9090'>Login Page</a>");

            http:Response res = new;
            res.setPayload(untaint buffer);
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
   resource function sendGOVIDRequest(http:Caller caller, http:Request req, string name, string message) {
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
   resource function sendBundle(http:Caller caller, http:Request req, string name, string message) {
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
   resource function sendFileSaver(http:Caller caller, http:Request req, string name, string message) {
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
   resource function processRegistration(http:Caller caller, http:Request req, string name, string message) returns error?{
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

        int index = did.indexOf("\"id\": \"did:ethr:") + 16;
        did = did.substring(index, index+64);

        io:println(("insert into ssidb.govid(firstname, lastname, streetaddress, city, state, country, postcode, dob ,did) " + "values ('"+ firstName +"', '" + lastName + "', '" + streetAddress + "', '"+ city +"', '"+ state +"', '" + postcode + "', '" + country + "', '" + date + "', '" + did + "');"));

        var ret = ssiDB->update(untaint ("insert into ssidb.govid(firstname, lastname, streetaddress, city, state, postcode, country, dob, did) " + "values ('"+ firstName +"', '" + lastName + "', '" + streetAddress + "', '"+ city +"', '"+ state +"', '" + postcode + "', '" + country + "','" + date + "', '" + did + "');"));

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
   resource function logout(http:Caller caller, http:Request req, string name, string message) {
       var requestVariableMap = req.getQueryParams();
       string username = requestVariableMap["username"]  ?: "";

       if ((!(username.equalsIgnoreCase(""))) && authenticatedMap[username] == true) {
           authenticatedMap[username] = false;
       }

       string buffer = readFile("web/govid-login.html");
       
       http:Response res = new;

       if (caller.localAddress.host != "") {
           buffer= buffer.replace("localhost", caller.localAddress.host);
       }

       res.setPayload(untaint buffer);
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
   resource function api(http:Caller caller, http:Request req, string name, string message) returns error?{
        var requestVariableMap = check req.getFormParams();
       
       if (requestVariableMap["command"] == "cmd1") {
            if (requestVariableMap.hasKey("secureToken") && (!randomKey.equalsIgnoreCase(requestVariableMap["secureToken"] ?: ""))) {
                io:println("incorrect sec token");
                var result = caller->respond("incorrect-token");

                if (result is error) {
                    log:printError("Error sending response", err = result);
                }
            } else {
                if (requestVariableMap.hasKey("did")) {
                    pk = untaint requestVariableMap["did"]  ?: "";
                    var result = caller->respond("done");

                    if (result is error) {
                        log:printError("Error sending response", err = result);
                    }
                }
            }
        } else if (requestVariableMap["command"] == "requestvc") {
            var did = requestVariableMap["did"] ?: "";

            did = did.replace("%2C", ",");
            did = utils:binaryStringToString(did);
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
            //var publicKey = requestVariableMap["publicKey"] ?: "";

            did = did.replace("%2C", ",");
            did = utils:binaryStringToString(did);
            int index2 = did.indexOf("\"id\": \"did:ethr:") + 16;
            string didmid = did.substring(index2, index2+64);

            index2 = did.indexOf("-----BEGIN PUBLIC KEY-----")  + 26;

            int index3 = did.indexOf("-----END PUBLIC KEY-----");
            var publicKey = did.substring(index2, index3);
            var didmidOrg = didmid;
            didmid = "0x" + didmid;
            
            string randKey = sessionMap[didmid]?: "";

            if (encryptedval === randKey) {
                var verifiableCredentialsList = getVerifiableCredentials(didmidOrg);

                http:Response res = new;
                // A util method that can be used to set string payload.
                res.setPayload(untaint verifiableCredentialsList);
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
   resource function secTokenAPI(http:Caller caller, http:Request req, string name, string message) returns error?{
        var requestVariableMap = check req.getFormParams();
       
       if (requestVariableMap.hasKey("randomKey")) {
        randomKey = untaint requestVariableMap["randomKey"]  ?: "";
       }

        var result = caller->respond("done");

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
service basic on new http:WebSocketListener(9095) {

    string ping = "ping";
    byte[] pingData = ping.toByteArray("UTF-8");

    resource function onOpen(http:WebSocketCaller caller) {
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
        if (text == "ping") {
            io:println("Pinging...");
            var err = caller->ping(self.pingData);
            if (err is error) {
                log:printError("Error sending ping", err = err);
            }
        } else if (text == "closeMe") {
            var err = caller->close(statusCode = 1001,
                            reason = "You asked me to close the connection",
                            timeoutInSecs = 0);
        } else {
            chatBuffer = untaint text + "\r\n";
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


public function readFile (string filePath) returns (string) {
        io:ReadableByteChannel readableByteChannel = io:openReadableFile(filePath);
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

public function getVerifiableCredentials(string didmid) returns (string) {
    time: Time currentTime = time:currentTime();
    string customTimeString = currentTime.format("dd-MM-yyyy");
    string country = "";
    string firstname = "";
    var selectRet = ssiDB->select(untaint "select country, firstname from ssidb.govid where (did LIKE '"+ untaint didmid +"');", ());

    if (selectRet is table<record {}>) {
        io:println("\nConvert the table into json");
        var jsonConversionRet = json.convert(selectRet);
        
        if (jsonConversionRet is json) {
            if (jsonConversionRet.length() > 0) {
                country = jsonConversionRet[0]["country"].toString();
                firstname = jsonConversionRet[0]["firstname"].toString();
            } else {
                return "none";
            }
        }
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
        if (jsonResponse is json) {
            if (jsonResponse["error"] == null) {
                finalResult2 = jsonResponse.result.toString();
            } else {
                    error err = error("(wso2/ethereum)EthereumError",
                    { message: "Error occurred while accessing the JSON payload of the response" });
                    finalResult2 = jsonResponse["error"].toString();
                    errorFlag2 = true;
            }
        } else {
            error err = error("(wso2/ethereum)EthereumError",
            { message: "Error occurred while accessing the JSON payload of the response" });
            finalResult2 = jsonResponse.reason();
            errorFlag2 = true;
        }
    } else {
        error err = error("(wso2/ethereum)EthereumError", { message: "Error occurred while invoking the Ethererum API" });
        errorFlag2 = true;
    }

    string hexEncodedString = "0x" + utils:hashSHA256(data);

    http:Request request = new;
    request.setHeader("Content-Type", "application/json");
    request.setJsonPayload({"jsonrpc":"2.0", "id":"2000", "method":"eth_sendTransaction", "params":[{"from": ethereumAccount, "to":"0x6814412628addef8989ee696a67b0fad5d62735e", "data": hexEncodedString}]});

    string finalResult = "";
    boolean errorFlag = false;
    var httpResponse = ethereumClient -> post("/", request);
    if (httpResponse is http:Response) {
        int statusCode = httpResponse.statusCode;
        var jsonResponse = httpResponse.getJsonPayload();
        if (jsonResponse is json) {
            if (jsonResponse["error"] == null) {
                finalResult = jsonResponse.result.toString();
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