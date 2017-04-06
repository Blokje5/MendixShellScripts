#!/bin/bash
#Mendix one click deploy

#Check flags and initialize parameters needed for REST calls
while getopts ":a:b:u:n:m:" opt; do
  case $opt in
    a)
      API_KEY=$OPTARG;;
    u) 
      USER=$OPTARG;;
    b)
      BRANCH=$OPTARG;;
    n)
      APP_ID=$OPTARG;;
    m)
      MODE=$OPTARG;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done
#Get latest revision. Call returns array, first element of array contains latest revision
RESPONSE=$(curl -s -X GET -H "Mendix-Username: $USER" -H "Mendix-ApiKey: $API_KEY" "https://deploy.mendix.com/api/1/apps/$APP_ID/branches/$BRANCH/revisions/")
NUMBER=$(echo $RESPONSE | jq ".[0] |  .Number ")
#Generate body for package request
generate_body_package()
{
    #Add flag for version
    cat <<EOF
    {
        "Revision":$NUMBER,
        "Version":"1.0.0", 
        "Description": "Automated Build" 
    }
EOF
}
#Build package
RESPONSE=$(curl -s -X POST -H "Mendix-Username: $USER" -H "Content-Type: application/json" -H "Mendix-ApiKey: $API_KEY" -d "$(generate_body_package)" https://deploy.mendix.com/api/1/apps/$APP_ID/packages/)
PACKAGEID=$(echo $RESPONSE | jq -r '.PackageId')
#check if status is Succeeded, else try again
check_package_status()
{
    local RESPONSE=$(curl -s -X GET -H "Mendix-Username: $USER" -H "Content-Type: application/json" -H "Mendix-ApiKey: $API_KEY" https://deploy.mendix.com/api/1/apps/$APP_ID/packages/$PACKAGEID/ )
    local STATUS=$(echo $RESPONSE | jq -r '.Status')
    local CODE="Succeeded"
    if [ "$STATUS" == "$CODE" ]
    then 
        echo "Package build finished"
        return 
    else
        sleep 10
        check_package_status
    fi
}
check_package_status
#Shut down environment
curl -s -X POST -H "Mendix-Username: $USER" -H "Mendix-ApiKey: $API_KEY" "https://deploy.mendix.com/api/1/apps/$APP_ID/environments/$MODE/stop/"
#Check environment
check_environment_status()
{
  local RESPONSE=$(curl -s -X GET -H "Mendix-Username: $USER" -H "Mendix-ApiKey: $API_KEY" "https://deploy.mendix.com/api/1/apps/$APP_ID/environments/$MODE/")
  local STATUS=$(echo $RESPONSE | jq -r '.Status')
  local CODE="Stopped"
  if [ "$STATUS" == "$CODE" ]
  then
    echo "Environment stopped"
    return
  else 
    sleep 10
    check_environment_status
  fi
}
check_environment_status
#Transport the deployment package
generate_body_check_package()
{
  cat <<EOF
  {
    "PackageId":"$PACKAGEID"
  }
EOF
}
curl -v -X POST -H "Mendix-Username: $USER" -H "Content-Type: application/json" -H "Mendix-ApiKey: $API_KEY"  -d "$(generate_body_check_package)" "https://deploy.mendix.com/api/1/apps/$APP_ID/environments/$MODE/transport/"
#Check if environment package = $PACKAGEID
check_packageid_on_environment()
{
  local RESPONSE=$(curl -s -X GET -H "Mendix-Username: $USER" -H "Mendix-ApiKey: $API_KEY" "https://deploy.mendix.com/api/1/apps/$APP_ID/environments/$MODE/package/")
  local STATUS=$(echo $RESPONSE | jq -r '.PackageId')
  if [ "$STATUS" == "$PACKAGEID" ]
  then
    echo "Package transported to environment"
    return
  else
    sleep 10
    check_packageid_on_environment
  fi
}
check_packageid_on_environment
#Start environment
generate_body_start()
{
  cat <<EOF
  {
    "AutoSyncDb" :  true
  }
EOF
}
RESPONSE=$(curl -s -X POST -H "Mendix-Username: $USER" -H "Content-Type: application/json" -H "Mendix-ApiKey: $API_KEY"  -d "$(generate_body_start)" "https://deploy.mendix.com/api/1/apps/$APP_ID/environments/$MODE/start/")
JOBID=$(echo $RESPONSE | jq -r '.JobId')
#check status Job
check_job()
{
  local RESPONSE=$(curl -s -X GET -H "Mendix-Username: $USER" -H "Mendix-ApiKey: $API_KEY" "https://deploy.mendix.com/api/1/apps/$APP_ID/environments/$MODE/start/$JOBID/")
  local STATUS=$(echo $RESPONSE | jq -r '.Status')
  local CODE="Started"
  if [ "$STATUS" == "$CODE" ]
  then
    echo "Environment started"
    return
  else
    sleep 10
    check_job
  fi
}
check_job
#./oneclickdeploy.sh -a 29bf3ac5-98cc-47aa-8c5b-f3ea9bceb34f -u lennard.eijsackers@finaps.nl -m Acceptance -b trunk -n quion