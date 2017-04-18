#!/bin/bash
#Mendix run unittests

#Example how to run
#./unittest.sh -p 1 -h http://windowshost:8080


#Check flags and initialize parameters needed for REST calls
while getopts ":p:h:" opt; do
  case $opt in
    p)
      PASSWORD=$OPTARG;;
    h) 
      HOST=$OPTARG;;
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

#Generate JSON for unittest API
generate_body_unittests()
{
  cat <<EOF
  {
    "password":"$PASSWORD"
  }
EOF
}
#Start server and verify status code. Exit with error if status code != 204
RESPONSE=$(curl -s --write-out %{http_code} --output /dev/null -X POST -H "Content-Type: application/json" -d "$(generate_body_unittests)" "$HOST/unittests/start")
if [ "$RESPONSE" != "204" ]
then 
    echo "failed to start unittests, status code $RESPONSE"
    exit 1
fi
#Check status of unittests recursively until finshed (completed == true), then return errors if they are there
check_failed_unittests()
{
    #function depends on passed response, passed as $1
    local FAILURE=$(echo $1 | jq -r ".failures")
    if [ "$FAILURE" = "1" ]
    then
        echo $1 | jq -r ".failed_tests"
        exit 1
    else
       echo "unittest completed succesfully"
       return
    fi
}
check_completed_status()
{
    local RESPONSE=$(curl -s -X POST -H "Content-Type: application/json" -d "$(generate_body_unittests)" "$HOST/unittests/status")
    local COMPLETED=$(echo $RESPONSE | jq -r ".completed")
    if [ "$COMPLETED" == "false" ]
    then
        check_completed_status
    else
        echo "unittests completed"
        check_failed_unittests "$RESPONSE"
        return
    fi
}
check_completed_status
