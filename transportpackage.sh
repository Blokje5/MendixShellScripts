#!/bin/bash
#Mendix transport package to accp

#Check flags and initialize parameters needed for REST calls
while getopts ":a:u:n:m:p:" opt; do
  case $opt in
    a)
      API_KEY=$OPTARG;;
    u) 
      USER=$OPTARG;;
    n)
      APP_ID=$OPTARG;;
    m)
      MODE=$OPTARG;;
    p)
      MODE_FROM=$OPTARG;;
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
RESPONSE=$(curl -s -X GET -H "Mendix-Username: $USER" -H "Mendix-ApiKey: $API_KEY" "https://deploy.mendix.com/api/1/apps/$APP_ID/environments/$MODE_FROM/package")
PACKAGEID=$(echo $RESPONSE | jq -r ".PackageId")

#Check for error function
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

RESPONSE=$(curl -s -X POST -H "Mendix-Username: $USER" -H "Mendix-ApiKey: $API_KEY" "https://deploy.mendix.com/api/1/apps/$APP_ID/environments/$MODE/stop/")
check_for_error
#Check environment
check_environment_status()
{
  local RESPONSE=$(curl -s -X GET -H "Mendix-Username: $USER" -H "Mendix-ApiKey: $API_KEY" "https://deploy.mendix.com/api/1/apps/$APP_ID/environments/$MODE/")
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

RESPONSE=$(curl -s -X POST -H "Mendix-Username: $USER" -H "Content-Type: application/json" -H "Mendix-ApiKey: $API_KEY"  -d "$(generate_body_check_package)" "https://deploy.mendix.com/api/1/apps/$APP_ID/environments/$MODE/transport/")
check_for_error
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


