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
import ballerina/runtime;
//import ballerina/crypto;
//import ballerina/encoding;

import wso2/ethereum;
import wso2/utils;

listener http:Listener uiHolderLogin = new(9091);

map<string> sessionMap = {};
map<boolean> authenticatedMap = {};
map<string> userMap = {"alice": "123"};
string chatBuffer = "";
string pk = "";
string verifiableCredentialsRepositoryURL = "https://localhost:9091/vc/";
string ethereumAccount = "0xee0727d9e94dbb230233ea4bd362e4c081aabf38";

ethereum:EthereumConfiguration ethereumConfig = {
    jsonRpcEndpoint: "http://192.168.32.1:8081",
    jsonRpcVersion: "2.0",
    networkId: "2000"
};

mysql:Client ssiDB = new({
        host: "192.168.32.1",
        port: 3306,
        name: "ssidb",
        username: "test",
        password: "test",
        dbOptions: { useSSL: false }
    });

string holderRepo = "/var/tmp/iam/holder/alice";

string jsonRpcEndpoint = ethereumConfig.jsonRpcEndpoint;
http:Client ethereumClient = new(jsonRpcEndpoint, config = ethereumConfig.clientConfig);

@http:ServiceConfig { basePath:"/",
    cors: {
        allowOrigins: ["*"], 
        allowHeaders: ["Authorization, Lang"]
    } 
}
service uiServiceHolderLogin on uiHolderLogin {

   @http:ResourceConfig {
        methods:["GET"],
        path:"/",
        cors: {
            allowOrigins: ["*"],
            allowHeaders: ["Authorization, Lang"]
        }
    }
   resource function displayLoginPage(http:Caller caller, http:Request req, string name, string message) {
       string buffer = readFile("web/holder-login.html");
       
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
        path:"/home/did",
        cors: {
            allowOrigins: ["*"],
            allowHeaders: ["Authorization, Lang"]
        }
    }
   resource function displayLoginPage2(http:Caller caller, http:Request req, string name, string message) returns error? {
       var requestVariableMap = req.getQueryParams();
       string username = requestVariableMap["username"]  ?: "";

           if(utils:fileExists(holderRepo + "/did.json") == "-1") {
            if ((!(username.equalsIgnoreCase(""))) && authenticatedMap[username] == true) {
                    var buffer = readFile("web/holder-homepage-no-did.html");

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
                    buffer = buffer.replace("MSG", "Re-try login via : <a href='http://" + caller.localAddress.host + ":9091'>Login Page</a>");

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
           } else {
                    if ((!(username.equalsIgnoreCase(""))) && authenticatedMap[username] == true) {
                    var buffer = readFile("web/holder-homepage-with-did.html");
                    var didTxt = readFile(holderRepo + "/did.json");
                    http:Response res = new;

                    int index = didTxt.indexOf("\"id\": \"did:ethr:") + 16;
                    string didmid = didTxt.substring(index, index+64);

                    if (caller.localAddress.host != "") {
                        buffer= buffer.replace("localhost", caller.localAddress.host);
                        buffer= buffer.replace("DIDTEXT", didTxt);
                        buffer= buffer.replace("EMPTYUNAME", username);
                        buffer = buffer.replace("DIDMID", didmid);
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
                    buffer = buffer.replace("MSG", "Re-try login via : <a href='http://" + caller.localAddress.host + ":9091'>Login Page</a>");

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
   }

    @http:ResourceConfig {
        methods:["GET"],
        path:"/home/vc",
        cors: {
            allowOrigins: ["*"],
            allowHeaders: ["Authorization, Lang"]
        }
    }
   resource function displayLoginPage3(http:Caller caller, http:Request req, string name, string message) returns error? {
        var requestVariableMap = req.getQueryParams();
        string username = requestVariableMap["username"]  ?: "";
        string did = requestVariableMap["did"]  ?: "";

        var selectRet = ssiDB->select(untaint "select id, issuer, name from ssidb.vclist where (did LIKE '"+ untaint did +"');", ());
        string tbl = "<table><tr><td>No Verifiable credentials associated with your account yet.";

        if (selectRet is table<record {}>) {
            var jsonConversionRet = json.convert(selectRet);
            if (jsonConversionRet is json) {
                int l = jsonConversionRet.length();
                int i = 0;
                if (l == 0) {
                    tbl = "<table border=\"1px\" cellspacing=\"0\" cellpadding=\"3\"><tr><td>No Verifiable Credentials found for this DID</td></tr></table>";
                } else {
                    tbl = "<table border=\"1px\" cellspacing=\"0\" cellpadding=\"3\"><tr><th>Verifiable Cerdential's DID</th><th>Name</th><th>Issuer</th></tr>";
                    while (i < l) {
                        tbl = tbl + "<tr><td><a href=\"#\" onclick=\"showVC('" + jsonConversionRet[i]["id"].toString() + "');\">";
                        tbl = tbl + jsonConversionRet[i]["id"].toString();
                        //io:println(jsonConversionRet[i]["id"]);
                        tbl = tbl + "</a></td><td>";
                        tbl = tbl + jsonConversionRet[i]["name"].toString();
                         tbl = tbl + "</td><td>";
                        tbl = tbl + jsonConversionRet[i]["issuer"].toString();
                        //io:println(jsonConversionRet[i]["issuer"]);
                        i = i + 1;
                    }
                    tbl += "</td></tr></table>";
                }
            } else {
                io:println("Error in table to json conversion");
            }
        } else {
            io:println("Select data from vclist table failed");
        }

        if ((!(username.equalsIgnoreCase(""))) && authenticatedMap[username] == true) {
            var buffer = readFile("web/holder-homepage-vc.html");
            var didTxt = "";
            if(utils:fileExists(holderRepo + "/did.json") == "-1") {
        	    io:println("Cannot find the DID file.");
	        } else {
                didTxt = readFile(holderRepo + "/did.json");
            }

            http:Response res = new;

            if (caller.localAddress.host != "") {
                buffer = buffer.replace("localhost", caller.localAddress.host);
                buffer = buffer.replace("EMPTYUNAME", username);
                io:println("tbl:" + tbl);
                buffer = buffer.replace("VCTABLE", tbl);
                buffer = buffer.replace("DIDMID", did);
                
                didTxt = utils:stringToBinaryString(didTxt);
                buffer = buffer.replace("DIDTXTVAL", didTxt);
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
            buffer = buffer.replace("MSG", "Re-try login via : <a href='http://" + caller.localAddress.host + ":9091'>Login Page</a>");

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
        methods:["POST"],
        path:"/vc",
        cors: {
            allowOrigins: ["*"],
            allowHeaders: ["Authorization, Lang"]
        }
    }
   resource function listVC(http:Caller caller, http:Request req, string name, string message) returns error? {
        //var requestVariableMap = req.getQueryParams();
        map<string> requestVariableMap = check req.getFormParams();
        //string username = requestVariableMap["username"]  ?: "";
        string did = requestVariableMap["did"]  ?: "";
        io:println("did:" + did);
        var selectRet = ssiDB->select(untaint "select id, issuer, name from ssidb.vclist where (did LIKE '"+ untaint did +"');", ());
        string tbl = "<table><tr><td>No Verifiable credentials associated with your account yet.";

        if (selectRet is table<record {}>) {
            var jsonConversionRet = json.convert(selectRet);
            if (jsonConversionRet is json) {
                int l = jsonConversionRet.length();
                int i = 0;
                if (l == 0) {
                    tbl = "<table border=\"1px\" cellspacing=\"0\" cellpadding=\"3\"><tr><td>No Verifiable Credentials found for this DID</td></tr></table>";
                } else {
                    tbl = "<table border=\"1px\" cellspacing=\"0\" cellpadding=\"3\"><tr><th>Verifiable Cerdential's DID</th><th>Name</th><th>Issuer</th><th>&nbsp;</th></tr>";
                    while (i < l) {
                        tbl = tbl + "<tr><td><a href=\"#\" onclick=\"showVC('" + jsonConversionRet[i]["id"].toString() + "');\">";
                        tbl = tbl + jsonConversionRet[i]["id"].toString();
                        //io:println(jsonConversionRet[i]["id"]);
                        tbl = tbl + "</a></td><td>";
                        tbl = tbl + jsonConversionRet[i]["name"].toString();
                         tbl = tbl + "</td><td>";
                        tbl = tbl + jsonConversionRet[i]["issuer"].toString();
                        tbl = tbl + "</td><td><input type=\"checkbox\" id=\"" + jsonConversionRet[i]["id"].toString()  + "\" name=\"vcselect\"\\>";
                        //io:println(jsonConversionRet[i]["issuer"]);
                        i = i + 1;
                    }
                    tbl += "</td></tr></table><br/><input id=\"vc-btn\" type=\"button\" value=\"Submit VC\" onclick=\"submitVC()\">";
                }
            } else {
                io:println("Error in table to json conversion");
            }
        } else {
            io:println("Select data from vclist table failed");
        }

        // if ((!(username.equalsIgnoreCase(""))) && authenticatedMap[username] == true) {
        //     var buffer = readFile("web/holder-homepage-vc.html");
        //     var didTxt = "";
        //     if(utils:fileExists(holderRepo + "/did.json") == "-1") {
        // 	    io:println("Cannot find the DID file.");
	    //     } else {
        //         didTxt = readFile(holderRepo + "/did.json");
        //     }

        http:Response res = new;
        var buffer = tbl;

        //     if (caller.localAddress.host != "") {
        //         buffer = buffer.replace("localhost", caller.localAddress.host);
        //         buffer = buffer.replace("EMPTYUNAME", username);
        //         io:println("tbl:" + tbl);
        //         buffer = buffer.replace("VCTABLE", tbl);
        //         buffer = buffer.replace("DIDMID", did);
                
        //         didTxt = utils:stringToBinaryString(didTxt);
        //         buffer = buffer.replace("DIDTXTVAL", didTxt);
        //     }

            res.setPayload(untaint buffer);
            res.setContentType("text/html; charset=utf-8");
            res.setHeader("Access-Control-Allow-Origin", "*");
            res.setHeader("Access-Control-Allow-Methods", "POST,GET,PUT,DELETE");
            res.setHeader("Access-Control-Allow-Headers", "Authorization, Lang");

            var result = caller->respond(res);
            if (result is error) {
                log:printError("Error sending response", err = result);
            }
        // } else {
        //     io:println("Error login");

        //     string buffer = readFile("web/error.html");
        //     string hostname = "localhost";

        //     if (caller.localAddress.host != "") {
        //         hostname= caller.localAddress.host;
        //     }
        //     buffer = buffer.replace("MSG", "Re-try login via : <a href='http://" + caller.localAddress.host + ":9091'>Login Page</a>");

        //     http:Response res = new;
        //     res.setPayload(untaint buffer);
        //     res.setContentType("text/html; charset=utf-8");
        //     res.setHeader("Access-Control-Allow-Origin", "*");
        //     res.setHeader("Access-Control-Allow-Methods", "POST,GET,PUT,DELETE");
        //     res.setHeader("Access-Control-Allow-Headers", "Authorization, Lang");

        //     var result = caller->respond(res);
        //     if (result is error) {
        //             log:printError("Error sending response", err = result);
        //     }
        // }
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
        
        string publicKey = requestVariableMap["publickey"]  ?: "";
        publicKey = publicKey.replace("+", " ");
        publicKey = publicKey.replace("%2B", "+");
        publicKey = publicKey.replace("%2F", "/");
        publicKey = publicKey.replace("%3D", "=");
               
        if (requestVariableMap["command"] == "cmd1") {
            string finalResult = sendTransactionAndgetHash(publicKey);

            if (finalResult == "-1") {
                //If its error
                io:println("its is null--->"+finalResult);
                http:Response res = new;
                res.setPayload(untaint "null");
                res.setContentType("text/html; charset=utf-8");
                res.setHeader("Access-Control-Allow-Origin", "*");
                res.setHeader("Access-Control-Allow-Methods", "POST,GET,PUT,DELETE");
                res.setHeader("Access-Control-Allow-Headers", "Authorization, Lang");

                var result = caller->respond(res);
                if (result is error) {
                        log:printError("Error sending response", err = result);
                }
            } else {

            finalResult = finalResult.substring(2, 66);

            var templateDID = "{" +
                    "\"@context\": \"https://w3id.org/did/v1\"," +
                    "\"id\": \"did:ethr:"+ finalResult +"\"," +
                    "\"authentication\": [{" +
                    // used to authenticate as did:...fghi
                    "\"id\": \"did:ethr:" + finalResult + "#keys-1\"," +
                    "\"type\": \"RsaVerificationKey2018\"," +
                    "\"controller\": \"did:ethr:" + finalResult + "\"," +
                    "\"publicKeyPem\": \"" + publicKey + "\"" +
                    "}]," +
                    "\"service\": [{" +
                    // used to retrieve Verifiable Credentials associated with the DID
                    "\"type\": \"VerifiableCredentialService\"," +
                    "\"serviceEndpoint\": \"" + verifiableCredentialsRepositoryURL + "\"" +
                    "}]" +
                    "}";

                io:println(templateDID);

                string path = holderRepo + "/did.json";
                var result2 = writeFile(path, templateDID);


                http:Response res = new;
                res.setPayload(untaint templateDID);
                res.setContentType("text/html; charset=utf-8");
                res.setHeader("Access-Control-Allow-Origin", "*");
                res.setHeader("Access-Control-Allow-Methods", "POST,GET,PUT,DELETE");
                res.setHeader("Access-Control-Allow-Headers", "Authorization, Lang");

                var result = caller->respond(res);
                if (result is error) {
                        log:printError("Error sending response", err = result);
                }
            }
        } else if (requestVariableMap["command"] == "cmd2") {
            string did = requestVariableMap["did"]  ?: "";
            string didVC = requestVariableMap["didVC"]  ?: "";
            string issuerVC = requestVariableMap["issuerVC"]  ?: "";
            string nameVC = requestVariableMap["nameVC"]  ?: "";
            string vcTxt = requestVariableMap["vcTxt"]  ?: "";
            var selectRet = ssiDB->select(untaint "select name from ssidb.vclist where (did LIKE '"+ untaint did +"');", ());

            string name2 = "";

            if (selectRet is table<record {}>) {
                if (selectRet.hasNext()) {
                    var jsonConversionRet = json.convert(selectRet);
                    
                    if (jsonConversionRet is json) {
                        name2 = jsonConversionRet[0]["name"].toString();

                        if (nameVC === name2) {
                            http:Response res = new;
                            res.setPayload(untaint "vc-already-exist");
                            res.setContentType("text/html; charset=utf-8");
                            res.setHeader("Access-Control-Allow-Origin", "*");
                            res.setHeader("Access-Control-Allow-Methods", "POST,GET,PUT,DELETE");
                            res.setHeader("Access-Control-Allow-Headers", "Authorization, Lang");

                            var result = caller->respond(res);
                            if (result is error) {
                                    log:printError("Error sending response", err = result);
                            }

                            return;
                        }
                    }
                } else {
                    //The result is empty
                }
            }

            vcTxt = vcTxt.replace("'","''");
            var ret = ssiDB->update(untaint ("insert into ssidb.vclist(did, id, issuer, name, vctext) " + "values ('"+ did +"', '" + didVC.substring(2, didVC.length()) + "', '" + issuerVC + "', '"+ nameVC +"', '" + vcTxt + "');"));
     
            var selectRet2 = ssiDB->select(untaint "select id, issuer, name from ssidb.vclist where (did LIKE '"+ untaint did +"');", ());
                string tbl = "<table><tr><td>No Verifiable credentials associated with your account yet.";

                if (selectRet2 is table<record {}>) {
                    var jsonConversionRet = json.convert(selectRet2);
                    if (jsonConversionRet is json) {
                        // io:print("JSON: ");
                        io:println(io:sprintf("%s", jsonConversionRet));

                        int l = jsonConversionRet.length();
                        io:print("len l: " + l);
                        int i = 0;
                        if (l == 0) {
                            tbl = "<table border=\"1px\" cellspacing=\"0\" cellpadding=\"3\"><tr><td>No Verifiable Credentials found for this DID</td></tr></table>";
                        } else {
                            tbl = "<table border=\"1px\" cellspacing=\"0\" cellpadding=\"3\"><tr><th>Verifiable Cerdential's DID</th><th>Name</th><th>Issuer</th></tr>";
                            while (i < l) {
                                tbl = tbl + "<tr><td>";
                                tbl = tbl + jsonConversionRet[i]["id"].toString();
                                tbl = tbl + "</td><td>";
                                tbl = tbl + jsonConversionRet[i]["name"].toString();
                                tbl = tbl + "</td><td>";
                                tbl = tbl + jsonConversionRet[i]["issuer"].toString();
                                //io:println(jsonConversionRet[i]["issuer"]);
                                i = i + 1;
                            }
                            tbl += "</td></tr></table>";
                        }
                    } else {
                        io:println("Error in table to json conversion");
                    }
                } else {
                    io:println("Select data from vclist table failed");
                }



            http:Response res = new;
            res.setPayload(untaint tbl);
            res.setContentType("text/html; charset=utf-8");
            res.setHeader("Access-Control-Allow-Origin", "*");
            res.setHeader("Access-Control-Allow-Methods", "POST,GET,PUT,DELETE");
            res.setHeader("Access-Control-Allow-Headers", "Authorization, Lang");

            var result = caller->respond(res);
            if (result is error) {
                    log:printError("Error sending response", err = result);
            }
        } else if (requestVariableMap["command"] == "cmd3") {
            string id = requestVariableMap["id"]  ?: "";
            var selectRet = ssiDB->select(untaint "select vctext from ssidb.vclist where (id LIKE '"+ untaint id +"');", ());
            
            string vcText = "no-vc-for-this-did";

            if (selectRet is table<record {}>) {
                if (selectRet.hasNext()) {
                    var jsonConversionRet = json.convert(selectRet);
                    
                    if (jsonConversionRet is json) {
                        vcText = jsonConversionRet[0]["vctext"].toString();
                    }
                } else {
                    //The result is empty
                }
            }

            http:Response res = new;
            res.setPayload(untaint vcText);
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
   resource function sendGOVIDCSS(http:Caller caller, http:Request req, string name, string message) {
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
        path:"/home/bundle.js",
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
        methods:["GET"],
        path:"/jsencrypt.js",
        cors: {
            allowOrigins: ["*"],
            allowHeaders: ["Authorization, Lang"]
        }
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
   resource function sendBrowserAES(http:Caller caller, http:Request req, string name, string message) {
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

       string buffer = readFile("web/holder-login.html");
       
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
            ["http://localhost:9091/"]);
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
service basic on new http:WebSocketListener(9093) {

    string ping = "ping";
    byte[] pingData = ping.toByteArray("UTF-8");

    resource function onOpen(http:WebSocketCaller caller) {
        io:println("\nNew client connected");
        io:println("Connection ID: " + caller.id);
        io:println("Negotiated Sub protocol: " + caller.negotiatedSubProtocol);
        io:println("Is connection open: " + caller.isOpen);
        io:println("Is connection secured: " + caller.isSecure);

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
                                                        + finalFrame);

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
        // io:println("Closing connection " + caller.id);
        // var err = caller->close(statusCode = 1001, reason =
        //                             "Connection timeout");
        // if (err is error) {
        //     log:printError("Error occured when closing the connection",
        //                         err = err);
        // }
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

public function writeFile(string filePath, string content) returns error? {
    io:WritableCharacterChannel destinationChannel = new(io:openWritableFile(holderRepo + "/did.json"), "UTF-8");
    var writeCharResult = check destinationChannel.write(content, 0);

    var cr = destinationChannel.close();
    if (cr is error) {
        log:printError("Error occured while closing the channel: ", err = cr);
    }
    return;
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
                        //finalResult = convertHexStringToString(inputString);
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

            //byte[] output = crypto:hashSha256(publicKey.toByteArray("UTF-8"));
            //string hexEncodedString = "0xe1db84093f660c49846c87cf626ade2bc54135f2420d835cfae6ba01d5d903e2";//encoding:encodeHex(output);
            string hexEncodedString = "0x" + utils:hashSHA256(data);//encoding:encodeHex(output);
            //io:println("Hex encoded hash with SHA256: " + hexEncodedString);
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