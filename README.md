# MendixShellScripts
A repository for mendix  shell scripts which can be used in setting up a CI environment

## Configuration
To be able to use the scripts, you need to have bash and jq installed. 
The shell scripts are written in bash. jq is used as a JSON parser.
- [How to install bash on windows](http://www.windowscentral.com/how-install-bash-shell-command-line-windows-10)
- [How to install jq](https://stedolan.github.io/jq/)

To get the api key needed to call the oneclickdeploy script, check [this documentation](https://docs.mendix.com/apidocs-mxsdk/apidocs/authentication)

To enable the unittesting webservice, change the UnitTesting.RemoteApiEnabled constant on the server.

## Features
The oneclickdeploy.sh script finds the latest commit on the team server, builds a package for it and deploys it to the specified environment
The transferpackage.sh script finds the latest commit on the team server, builds a package for it and transfers it to another node.
The transportpackage.sh script gets the current package on environment x and transports it to environment y,
the most common use is to transport a package from test to acceptance
the unittest.sh script calls the unittest webservice (from the [Mendix UnitTesting module](https://github.com/mendix/UnitTesting)) and checks if all test run succesfully

## Usage
### oneclickdeploy.sh
Example:
./oneclickdeploy.sh -a API-Key -u lennard.eijsackers@finaps.nl -m Acceptance -b trunk -n AppName

* -a:
Api Key flag, check [this documentation](https://docs.mendix.com/apidocs-mxsdk/apidocs/authentication) to find your Api Key
* -u:
Mendix username
* -m:
Mode. Test for the test environment, Acceptance for the acceptance environment
* -b:
Branch name, trunk for main line and urlencoded "branches/BRANCH_NAME_HERE" for other branches
* -n:
App name, the name of the app.
If you do not know which apps to call, you can make a HTTP GET request to the following url https://deploy.mendix.com/api/1/apps/
with the Mendix-Username and Mendix-ApiKey headers set

### unittest.sh
Example:
./unittest.sh -p 1 -h http://localhost:8080

* -p:
Password, set in the UnitTesting.RemoteApiPassword constant
* -h:
Hostname, for example http://localhost:8080

### transferpackage.sh
Example:
./transferpackage.sh -a API-Key -u lennard.eijsackers@finaps.nl -m Acceptance -b trunk -n AppName -o AppNameTwo

* -a:
Api Key flag, check [this documentation](https://docs.mendix.com/apidocs-mxsdk/apidocs/authentication) to find your Api Key
* -u:
Mendix username
* -m:
Mode. Test for the test environment, Acceptance for the acceptance environment
* -b:
Branch name, trunk for main line and urlencoded "branches/BRANCH_NAME_HERE" for other branches
* -n:
App name, the name of the app where to build the package from.
* -p:
Node name, the name of the app where to transfer the package to.

### transportpackage.sh
Example:
./transportpackage.sh -a API-Key -u lennard.eijsackers@finaps.nl -m Acceptance -b trunk -n AppName -p Test

* -a:
Api Key flag, check [this documentation](https://docs.mendix.com/apidocs-mxsdk/apidocs/authentication) to find your Api Key
* -u:
Mendix username
* -m:
Mode to transport to. Test for the test environment, Acceptance for the acceptance environment
* -b:
Branch name, trunk for main line and urlencoded "branches/BRANCH_NAME_HERE" for other branches
* -n:
App name, the name of the app where to build the package from.
* -p:
Mode to transport from. Test for the test environment, Acceptance for the acceptance environment

