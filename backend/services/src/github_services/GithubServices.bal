import ballerina/http;
import ballerina/io;

http:Client githubAPIEndpoint = new (GITHUB_API_URL);

listener http:Listener endPoint = new (PORT);

@http:ServiceConfig {
    basePath: BASEPATH
}
service githubConnector on endPoint {

}

public function main() {
    io:println(checkLabel("bugii", "yashodgayashan", "ballerina-github-connector"));
    io:println(createLabel("yashodgayashan", "ballerina-github-connector", "bugiii", "test"));
}

