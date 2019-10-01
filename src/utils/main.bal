import ballerina/io;
import ballerinax/java;


public function hexToChar(string a) returns string = @java:Method {
    name:"execute",
    class:"org/wso2/ballerina/utils/HexToChar"
} external;

public function decToChar(int v) returns string = @java:Method {
    name:"execute",
    class:"org/wso2/ballerina/utils/DecToChar"
} external;

public function encryptRSAWithPublicKey(string publicKey, string data) returns string = @java:Method {
    name:"execute",
    class:"org/wso2/ballerina/utils/EncryptRSAWithPublicKey"
} external;

public function encryptRSAWithPublicKeyPlainText(string publicKey, string data) returns string = @java:Method {
    name:"execute",
    class:"org/wso2/ballerina/utils/EncryptRSAWithPublicKeyPlainText"
} external;

public function encryptAes(string key, string value) returns string = @java:Method {
    name:"encrypt",
    class:"org/wso2/ballerina/utils/EncryptAES"
} external;

public function decryptAes(string key, string encrypted) returns string = @java:Method {
    name:"decrypt",
    class:"org/wso2/ballerina/utils/DecryptAES"
} external;

public function writeBlockchainRecord(string key, string value, string blockChainAPIURL, string account,
string password, string workDirectory) returns string = @java:Method {
    name:"writeBlockchainRecord",
    class:"org/wso2/ballerina/utils/BlockChainInterface"
} external;


public function hashSHA256(string inputString) returns string = @java:Method {
    name:"execute",
    class:"org/wso2/ballerina/utils/HashSHA256"
} external;

public function fileExists(string path) returns string = @java:Method {
    name:"execute",
    class:"org/wso2/ballerina/utils/FileExists"
} external;

public function stringToBinaryString(string v) returns string = @java:Method {
    name:"execute",
    class:"org/wso2/ballerina/utils/StringToBinaryString"
} external;

public function binaryStringToString(string v) returns string = @java:Method {
    name:"execute",
    class:"org/wso2/ballerina/utils/BinaryStringToString"
} external;

public function main() {
    io:println("======>" + hexToChar("41"));
}
