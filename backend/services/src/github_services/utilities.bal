import ballerina/http;
import ballerina/io;
import ballerina/lang.'int as ints;
import ballerina/stringutils;

# The `assignLabel` function will assign the labels to a given issue.
#
# + issueNumber - Issue number which the given labels should be assigned to.
# + labels      - Array of labels which should be assigned to the issue.
# + return      - Returns a **string[]** which includes the status code and the message.
public function assignLabel(string issueNumber, string[] labels) returns string[] {

    string url = "/repos/" + ORGANIZATION_NAME + "/" + REPOSITORY_NAME + "/issues/" + issueNumber + "/labels";

    http:Request request = new;
    request.addHeader("Authorization", ACCESS_TOKEN);
    request.setJsonPayload({"labels": labels});
    http:Response | error githubResponse = githubAPIEndpoint->post(url, request);

    if (githubResponse is http:Response) {
        io:println(githubResponse.getJsonPayload());
        return getStatus(githubResponse);
    } else {
        io:println(githubResponse.reason());
        return getNotFoundStatus();
    }
}

# The `checkLabel` function is used to check whether the given label is available or not.
# 
# + labelName - Name of the label.
# + return    - Returns a **string[]** which indicates the status.
public function checkLabel(string labelName) returns @untainted string[] {

    string url = "/repos/" + ORGANIZATION_NAME + "/" + REPOSITORY_NAME + "/labels/" + labelName;

    http:Request request = new;
    request.addHeader("Authorization", ACCESS_TOKEN);
    http:Response | error githubResponse = githubAPIEndpoint->get(url, request);

    if (githubResponse is http:Response) {
        return getStatus(githubResponse);
    } else {
        return getNotFoundStatus();
    }
}


public function checkLabels(string labelName) returns @untainted string[] {
    return [];
}

# The `toStringArray` function will convert a json array into string array.
# 
# + inputArray - Json array.
# + return     - Returns the converted json array as a string array.
public function toStringArray(json[] inputArray) returns string[] {

    string[] outputArray = [];
    foreach var item in inputArray {
        outputArray[outputArray.length()] = item.toString();
    }
    return outputArray;
}

# The `createLabel` function will create a label in a specified git repository.
# 
# + labelName        - Name of the label.
# + labelDescription - Description of the label.
# + return           - Returns a **json** which indicates the status.
public function createLabel(string labelName, string labelDescription) returns string[] {

    json requestPayLoad = {
        "name": labelName,
        "description": labelDescription,
        "color": "f29513"
    };
    string url = "/repos/" + ORGANIZATION_NAME + "/" + REPOSITORY_NAME + "/labels";

    http:Request request = new;
    request.addHeader("Authorization", ACCESS_TOKEN);
    request.setJsonPayload(requestPayLoad);

    http:Response | error response = githubAPIEndpoint->post(url, request);
    if (response is http:Response) {
        return getStatus(response);
    } else {
        return getNotFoundStatus();
    }
}

# The `createLabelIfNotExists` function creates a label if the relevant label is not yet available.
# 
# + labelName        - Name of the label.
# + labelDescription - Description of the label.
# + return           - Returns a **string[]** which indicates the status.
public function createLabelIfNotExists(string labelName, string labelDescription) returns string[] {

    string[] status = checkLabel(labelName);
    int | error statusCode = ints:fromString(status[0]);

    if (statusCode is int && statusCode == http:STATUS_OK) {
        return [status[0], "Already exists."];
    } else {
        return createLabel(labelName, labelDescription);
    }
}

# The `getNotFoundStatus` function returns the not found status and the code as a string[]
# 
# + return - Returns status and status code.
public function getNotFoundStatus() returns string[] {

    return ["404", "Not Found"];
}

# The `getStatus` function will return the status of the **http:Response**
# 
# + response - Http response.
# + return   - Returns a **string[]** which includes the status code and the message.
public function getStatus(http:Response response) returns string[] {

    string status = "";
    status = response.getHeader("Status");
    string[] statusDetails = stringutils:split(status, " ");
    status = "";
    foreach int value in 1 ..< statusDetails.length() {
        status = status + statusDetails[value] + " ";
    }
    return [statusDetails[0], status];
}

# The `createAFormattedJsonOfAnIssue` function rebuilds a formatted issue using the retrieved 
# json issue.
#
# + issue  - Issue retrieved from the github API service. 
# + return - Returns a formatted **json** of an issue, **error** if a formatted json issue 
#            cannot be rebuilt or the issue with the issue number doesn't exist.
public function createAFormattedJsonOfAnIssue(json issue) returns json | error {

    json formattedIssue = {};
    json[] | error labels = trap <json[]>issue.labels;

    if (labels is json[]) {
        json | error labelDetails = createAFormattedJsonOfLabels(labels);
        if (labelDetails is json) {
            formattedIssue = {
                "issueId":check issue.id,
                "issueNumber":check issue.number,
                "labels": labelDetails,
                "issueTitle":check issue.title,
                "issueBody":check issue.body
            };
        } else {
            return error("Error while creating a formatted set of labels using the extracted issue labels.");
        }
    } else {
        return error("Issue with the given issue number cannot be found.");
    }

    return formattedIssue;
}

# The `extractIssuesRelatedToUser` function extracts all the issues related to a specific user.
#
# + listOfIssues - All the issues related to a specific repsitory. 
# + userName     - Username of the user. 
# + return       - Returns a formatted **json[]** of issues related to the user, **error** 
#                  if a formatted json array of issues cannot be rebuilt or the length of
#                  the json array length is zero.
public function extractIssuesRelatedToUser(json[] listOfIssues, string userName) returns json | error {

    json[] issues = [];
    foreach json issue in listOfIssues {
        map<json> issueRecord = <map<json>>issue;
        json labelDetails = check createAFormattedJsonOfLabels(<json[]>issueRecord.labels);

        if (userNameExists(<json[]>labelDetails, userName)) {
            json issueInfo = {
                "issueId":check issueRecord.id,
                "issueNumber":check issueRecord.number,
                "labels": labelDetails,
                "issueTitle":check issueRecord.title,
                "issueBody":check issueRecord.body
            };
            issues[issues.length()] = issueInfo;
        }
    }

    if (issues.length() > 0) {
        return issues;
    } else {
        return error("Issues for the specified user cannot be found.");
    }

}

# The `userNameExists` function checks if the username exists inside the labels of the issue.
#
# + labels   - Labels of the issue.
# + userName - Name of the user.
# + return   - Returns a **boolean** which indicates whether the user exists or not.
function userNameExists(json[] labels, string userName) returns boolean {

    foreach json label in labels {
        if (userName == (label.labelName.toString())) {
            return true;
        }
    }
    return false;
}

# The `createAFormattedJsonOfLabels` function rebuilds a formatted json array of labels out 
# of the original json array of labels.
# 
# + labels - Original json array of labels.  
# + return - Returns a formatted **json[]** of labels, **error** if a formatted json array 
#            of labels cannot be rebuilt.
function createAFormattedJsonOfLabels(json[] labels) returns json | error {

    json[] labelDetails = [];
    foreach json label in labels {
        map<json> labelRecord = <map<json>>label;
        labelDetails[labelDetails.length()] = {
            "labelName":check labelRecord.name,
            "labelDescription":check labelRecord.description
        };
    }
    return labelDetails;
}

# The `createAFormattedJsonOfCollaborators` function rebuilds a formatted json array of 
# collaborators out of the original json array of collaborators.
# 
# + collaborators - Original json array of collaborators.  
# + return        - Returns a formatted **json[]** of collaborators, **error** if a formatted 
#                   json array of collaborators cannot be rebuilt.
function createAFormattedJsonOfCollaborators(json[] collaborators) returns json | error {

    json[] formattedCollaborators = [];
    foreach json collaborator in collaborators {
        map<json> collaboratorRecord = <map<json>>collaborator;
        formattedCollaborators[formattedCollaborators.length()] = {
            "id":check collaboratorRecord.id,
            "name":check collaboratorRecord.login,
            "url":check collaboratorRecord.url
        };
    }
    return formattedCollaborators;
}

# The `getAllLabels` function retrieves all the labels of the repository using the github 
# API services.
#
# + return - Returns a **json** consisting all the labels, **error** if the labels cannot 
#            be extracted properly.
public function getAllLabels() returns json | error {

    string url = "/repos/" + ORGANIZATION_NAME + "/" + REPOSITORY_NAME + "/labels";

    http:Request request = new;
    request.addHeader("Authorization", ACCESS_TOKEN);
    http:Response | error githubResponse = githubAPIEndpoint->get(url, request);

    if (githubResponse is http:Response) {
        var jsonPayload = githubResponse.getJsonPayload();
        if (jsonPayload is json) {
            return <@untainted>jsonPayload;
        } else {
            return error("Error while extracting the jsonPayload from the github response.");
        }
    } else {
        return error("The github response is not in the expected form: http:Response.");
    }
}

# The `extractLabelNames` function extract the names of the labels from a json .
#
# + labels - Intial set of labels containing varous attributes. 
# + return - Returns a **string[]** consisting an array of label names, returns an **error** if
#            an array of label names cannot be created. 
public function extractLabelNames(json | error labels) returns string[] | error {

    string[] labelNames = [];
    json[] | error labelArray = trap <json[]>labels;

    if (labelArray is json[]) {
        foreach json item in labelArray {
            map<json> | error labelInfo = trap <map<json>>item;
            if (labelInfo is map<json>) {
                string labelName = labelInfo.name.toString();
                labelNames[labelNames.length()] = labelName;
            } else {
                return labelInfo;
            }
        }
        return labelNames;
    } else {
        return labelArray;
    }
}


# The `isValidCollaborator` function checks whether a user is a collaborator or not.
#
# + collaboratorName - Username of the collaborator. 
# + return           - Returns a **boolean** which indicates whether the collaborator exists or not
#                      , returns an **error** if the github response is not in the expected form.
public function isValidCollaborator(string collaboratorName) returns boolean | error {

    string url = "/repos/" + ORGANIZATION_NAME + "/" + REPOSITORY_NAME + "/collaborators/" + collaboratorName;

    http:Request request = new;
    request.addHeader("Authorization", ACCESS_TOKEN);
    http:Response | error githubResponse = githubAPIEndpoint->get(url, request);

    if (githubResponse is http:Response) {
        return githubResponse.statusCode == 204 ? true : false;
    } else {
        return error("The github response is not in the expected form: http:Response.");
    }
}

# The `createAFormattedJsonOfAssignees` function rebuilds a formatted json array of 
# assignees out of the original json array of assignees.
#
# + assignees - Original json array of assignees.  
# + return    - Returns a formatted **json[]** of assignees, **error** if a formatted 
#               json array of assignees cannot be rebuilt.
function createAFormattedJsonOfAssignees(json[] assignees) returns json | error {

    json[] assigneeDetails = [];
    foreach json assignee in assignees {
        map<json> assigneeRecord = <map<json>>assignee;
        assigneeDetails[assigneeDetails.length()] = {
            "id":check assigneeRecord.id,
            "userName":check assigneeRecord.login,
            "url":check assigneeRecord.url
        };
    }
    return assigneeDetails;
}

# The `areValidAssignees` function checks if the assignees already exists.
#
# + userNames - Usernames corresponding to the assignees. 
# + return    - Returns a **boolean** which indicates whether all the assignees exists or not
#               , returns an **error** if the github response is not in the expected form.
function areValidAssignees(json[] userNames) returns boolean | error {

    foreach json userName in userNames {
        string url = "/repos/" + ORGANIZATION_NAME + "/" + REPOSITORY_NAME + "/assignees/" + userName.toString();

        http:Request request = new;
        request.addHeader("Authorization", ACCESS_TOKEN);
        http:Response | error githubResponse = githubAPIEndpoint->get(url, request);

        if (githubResponse is http:Response) {
            if (githubResponse.statusCode != 204) {
                return false;
            }
        } else {
            return error("The github response is not in the expected form: http:Response.");
        }
    }

    return true;
}

# The `isValidIssue` function checks whether an issue with the provided issue number exists.
#
# + issueNumber - Issue number related to the issue. 
# + return      - Returns a **boolean** which indicates whether the issue exists or not, 
#                 returns an **error** if the github response is not in the expected form.
function isValidIssue(string issueNumber) returns boolean | error {

    string url = "/repos/" + ORGANIZATION_NAME + "/" + REPOSITORY_NAME + "/issues/" + issueNumber;

    http:Request request = new;
    request.addHeader("Authorization", ACCESS_TOKEN);
    http:Response | error githubResponse = githubAPIEndpoint->get(url, request);

    if (githubResponse is http:Response) {
        return githubResponse.statusCode == 200 ? true : false;
    } else {
        return error("The github response is not in the expected form: http:Response.");
    }
}
