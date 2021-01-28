import ballerina/config;
import ballerina/http;
import ballerina/log;
import ballerina/mime;
import ballerina/observe;


string nettyServiceUrl = config:getAsString("NETTY_SERVICE_URL");


service on new http:Listener(9090) {
    resource function post passthrough(http:Caller caller, http:Request clientRequest) {
        http:Client nettyEP = new (nettyServiceUrl);
        var response = <@untainted> nettyEP->forward("/service/EchoService", clientRequest);

        if (response is http:Response) {
            if (response.hasHeader("content-type")) {
                string baseType = getBaseType(response.getContentType());
                if (mime:APPLICATION_JSON == baseType) {
                    var jsonValue = response.getJsonPayload();
                    if (jsonValue is json) {
                         var result = caller->respond(<@untainted>jsonValue);
                    } else {
                        var result = caller->respond(<@untainted>response);
                    }
                }
            } else {
                log:printError("Entity body is not available");
                http:Response res = new;
                res.statusCode = 500;
                res.setPayload("Entity body is not available");
                var result = caller->respond(res);
            }
        } else if (response is anydata) {
            json|error payload = response.cloneWithType(json);
            if (payload is json) {
                var result = caller->respond(<@untainted>payload);
            } else {
                log:printError("Error at h1c_h1c_passthrough", err = payload);
                http:Response res = new;
                res.statusCode = 500;
                res.setPayload(<@untainted>payload.message());
                var result = caller->respond(res);
            }
        } else {
            log:printError("Error at h1c_h1c_passthrough", err = response);
            http:Response res = new;
            res.statusCode = 500;
            res.setPayload(<@untainted>response.message());
            var result = caller->respond(res);
        }
    }
}

@observe:Observable
function getBaseType(string contentType) returns string {
    var result = mime:getMediaType(contentType);
    if (result is mime:MediaType) {
        return result.getBaseType();
    } else {
        panic result;
    }
}
