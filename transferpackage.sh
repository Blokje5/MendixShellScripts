#!/bin/bash
#Mendix one click deploy

#Check flags and initialize parameters needed for REST calls
while getopts ":a:b:u:n:m:o:" opt; do
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
    o)
      APP_ID_TRANSFER=$OPTARG;;  
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
#test
check_for_error()
{
  #If it is not an array, we need to check if we have an error message
  if [ "$RESPONSE" = "" ]
  then
    return
  fi
  ISARRAY=$(echo $RESPONSE | jq 'if type=="array" then 1 else 0 end')
  if (( $ISARRAY < 1 ))
  then
    if echo $RESPONSE | jq -e 'has("errorMessage")' > /dev/null
    then
      ERROR=$(echo $RESPONSE | jq -r ".errorMessage")
      echo "Error response from server:"
      echo "$ERROR"
      exit 1
    fi
  fi
}
check_for_error
NUMBER=$(echo $RESPONSE | jq ".[0] |  .Number ")
#Generate body for package request
generate_body_package()
{
    #Add flag for version
    cat <<EOF
    {
        "Revision":$NUMBER,
        "Version":"1.0.0", 
        "Description": "Automated Build", 
        "Branch": $BRANCH
    }
EOF
}
#Build package
RESPONSE=$(curl -s -X POST -H "Mendix-Username: $USER" -H "Content-Type: application/json" -H "Mendix-ApiKey: $API_KEY" -d "$(generate_body_package)" https://deploy.mendix.com/api/1/apps/$APP_ID/packages/)
check_for_error
PACKAGEID=$(echo $RESPONSE | jq -r '.PackageId')
#check if status is Succeeded, else try again
check_package_status()
{
    local RESPONSE=$(curl -s -X GET -H "Mendix-Username: $USER" -H "Content-Type: application/json" -H "Mendix-ApiKey: $API_KEY" https://deploy.mendix.com/api/1/apps/$APP_ID/packages/$PACKAGEID/ )
    check_for_error
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
#Download package and store as .mda
RESPONSE=$(curl -s --output $PACKAGEID.mda -X GET -H "Mendix-Username: $USER" -H "Mendix-ApiKey: $API_KEY" "https://deploy.mendix.com/api/1/apps/$APP_ID/packages/$PACKAGEID/download")
check_for_error
echo "Package downloaded"
#Upload package to environment
RESPONSE=$(curl -v --data-binary "@$PACKAGEID.mda" -X POST -H "Mendix-Username: $USER" -H "Mendix-ApiKey: $API_KEY" "https://deploy.mendix.com/api/1/apps/$APP_ID_TRANSFER/packages/upload")
echo $RESPONSE
check_for_error
echo "Package uploaded"
#Shut down environment
RESPONSE=$(curl -s -X POST -H "Mendix-Username: $USER" -H "Mendix-ApiKey: $API_KEY" "https://deploy.mendix.com/api/1/apps/$APP_ID_TRANSFER/environments/$MODE/stop/")
check_for_error
echo "environment stop initiated"
#Check environment
check_environment_status()
{
  local RESPONSE=$(curl -s -X GET -H "Mendix-Username: $USER" -H "Mendix-ApiKey: $API_KEY" "https://deploy.mendix.com/api/1/apps/$APP_ID_TRANSFER/environments/$MODE/")
  check_for_error
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
RESPONSE=$(curl -s -X POST -H "Mendix-Username: $USER" -H "Content-Type: application/json" -H "Mendix-ApiKey: $API_KEY"  -d "$(generate_body_check_package)" "https://deploy.mendix.com/api/1/apps/$APP_ID_TRANSFER/environments/$MODE/transport/")
check_for_error
#Check if environment package = $PACKAGEID
check_packageid_on_environment()
{
  local RESPONSE=$(curl -s -X GET -H "Mendix-Username: $USER" -H "Mendix-ApiKey: $API_KEY" "https://deploy.mendix.com/api/1/apps/$APP_ID_TRANSFER/environments/$MODE/package/")
  check_for_error
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
RESPONSE=$(curl -s -X POST -H "Mendix-Username: $USER" -H "Content-Type: application/json" -H "Mendix-ApiKey: $API_KEY"  -d "$(generate_body_start)" "https://deploy.mendix.com/api/1/apps/$APP_ID_TRANSFER/environments/$MODE/start/")
JOBID=$(echo $RESPONSE | jq -r '.JobId')
#check status Job
check_job()
{
  local RESPONSE=$(curl -s -X GET -H "Mendix-Username: $USER" -H "Mendix-ApiKey: $API_KEY" "https://deploy.mendix.com/api/1/apps/$APP_ID_TRANSFER/environments/$MODE/start/$JOBID/")
  check_for_error
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
#be50f280-5951-468a-9d3c-522f2b2192fc