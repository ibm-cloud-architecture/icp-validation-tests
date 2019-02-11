#!/usr/bin/env bash

# Wrapper script to run bats tests for various drivers.
# Usage: DRIVER=[driver] ./run-bats.sh [subtest]

# The test namespace
NAMESPACE=${NAMESPACE:-ivt}

# KUBECTL localtion
KUBECTL=$(which kubectl)

# The router_https_port, support for Openshift
ROUTER_HTTPS_PORT=${ROUTER_HTTPS_PORT:-8443}

# Set cluster name
CLUSTERNAME=${CLUSTERNAME:-mycluster}

# The username and password used to login the cluster
USERNAME=${USERNAME:-admin}
PASSWD=${PASSWORD:-admin}

# The API security port
KUBE_APISERVER_PORT=${KUBE_APISERVER_PORT:-8001}

source helpers.bash

function config_kubeclient() {
    get_credentials
    if [[ x$username == 'x' ]]; then
        echo "The kubectl did not configured, will use the environment variable USERNAME and PASSWORD to config the client"
        token=$(curl -s -k -H "Content-Type: application/x-www-form-urlencoded;charset=UTF-8" -d "grant_type=password&username=$USERNAME&password=$PASSWD&scope=openid" https://$ACCESS_IP:$ROUTER_HTTPS_PORT/idprovider/v1/auth/identitytoken --insecure | jq .id_token | awk  -F '"' '{print $2}')
        $KUBECTL config set-cluster ${CLUSTERNAME} --server=https://$ACCESS_IP:$KUBE_APISERVER_PORT --insecure-skip-tls-verify=true
        $KUBECTL config set-context ${CLUSTERNAME}-icp-context --cluster=$CLUSTERNAME
        $KUBECTL config set-credentials $USERNAME --token=$token
        $KUBECTL config set-context ${CLUSTERNAME}-icp-context --user=$USERNAME --namespace=default
        $KUBECTL config use-context ${CLUSTERNAME}-icp-context
    else
       echo "The kubeclient already configure."
    fi
}

function verify_bats() {
    $(which bats) 2>/dev/null
    if [[ $? -ne 0 ]]; then
        echo "can not find bats in the PATH, please first install the bats and then re-try"
        exit 1
    fi
}

function help() {
    echo "Accepted cli arguments are:"
    echo -e "\t[--help|-h ]. prints this help"
    echo -e "\t[--groups|-g <groups> ], the case groups should be like --groups='group1,group2'."
    echo -e "\t[--groups|-g -l ], list the current supported groups."
    echo -e "\t[--ignore_groups|-ng <groups> ], skip the cases groups,like -ng group1,group2"
    echo -e "\t[--cases|-c <cases>], the cases should be like --cases='case1,case2'."
    echo -e "\t[--cases|-c -l], list the current supported cases."
    echo -e "\t[--ignore_cases|-nc <cases> ], skip the cases groups,like -nc case1,case2"
    echo -e "\t[--uicases|-ui <cases> ], run the current supported ui cases."
    echo -e "\t[--uicases|-ui -l ], list the current supported ui cases."
}

function pre-run() {
  update_insecure_registries
  config_kubeclient
  # Populeate the Kubernetes server and client versions
  set_versions
  clean_up
  create_privileged_namespace $NAMESPACE
  create_imagepolicy $NAMESPACE
}

run_bats() {
    minor=$($KUBECTL version --client -o yaml | grep minor | awk -F ':' '{print $2}')
    if [[ $minor == "7" ]]; then
        ignor_version=1.8
    else
        ignor_version=1.7
    fi
    if [[ $# -eq 0 ]]; then
        # All case will be run
        pre-run
        for bats_suite in $(ls $(pwd)/suites/ |grep -v $ignor_version); do
            echo "=> $bats_suite"
            if [ X$OUTPUT_FORMAT == 'Xjunit' ]; then
                bats -u $(pwd)/suites/$bats_suite
            elif [ X$OUTPUT_FORMAT == 'Xtap' ]; then
                bats -t $(pwd)/suites/$bats_suite
            else
                bats $(pwd)/suites/$bats_suite
            fi
            if [[ $? -ne 0 ]]; then
                EXIT_STATUS=1
            fi
        done
    fi
    if [[ $# -eq 2 && $1 == 'groups' ]]; then
        if [[ $2 == '-l' ]]; then
            echo "The supported groups were: "
            ls -1 ./suites | grep -v $ignor_version
        else
            pre-run
            data=$2
            oldIFS=$IFS
            IFS=","
            for bats_suite in $data
                do
                   if [ X$OUTPUT_FORMAT == 'Xjunit' ]; then
                       bats -u $(pwd)/suites/$bats_suite
                   elif [ X$OUTPUT_FORMAT == 'Xtap' ]; then
                       bats -t $(pwd)/suites/$bats_suite
                   else
                       bats $(pwd)/suites/$bats_suite
                   fi
                done
            IFS=$oldIFS
        fi
     fi
     if [[ $# -eq 2 && $1 == 'ignore_groups' ]]; then
        pre-run
        data=$2
        tamp_data=`echo ${data//,/|}`
	echo "Ignore the groups: $data"
        for bats_suite in $(ls $(pwd)/suites/ | egrep -v "$tamp_data" | grep -v $ignor_version); do
            if [ X$OUTPUT_FORMAT == 'Xjunit' ]; then
                       bats -u $(pwd)/suites/$bats_suite
                   elif [ X$OUTPUT_FORMAT == 'Xtap' ]; then
                       bats -t $(pwd)/suites/$bats_suite
                   else
                       bats $(pwd)/suites/$bats_suite
                   fi

         done
     fi
     if [[ $# -eq 2 && $1 == 'ignore_cases' ]]; then
        pre-run
        data=$2
        tamp_data=`echo ${data//,/|}`
        echo "Ignore the cases: $data"
        for bats_suite in $(find . -name *.bats | egrep -v "$tamp_data" | grep -v $ignor_version); do
              if [ -e $(pwd)/$bats_file ]; then
                  if [ X$OUTPUT_FORMAT == 'Xjunit' ]; then
                       bats -u $(pwd)/$bats_suite
                  elif [ X$OUTPUT_FORMAT == 'Xtap' ]; then
                       bats -t $(pwd)/$bats_suite
                   else
                       bats $(pwd)/$bats_suite
                   fi
              fi
         done
     fi

     if [[ $# -eq 2 && $1 == 'cases' ]]; then
          if [[ $2 == '-l' ]]; then
              echo "The supported cases were: "
              find ./suites -name *.bats | grep -v $ignor_version | awk -F '/' '{print $4}' | awk -F . '{print $1}'
          else
              pre-run
              data=$2
              oldIFS=$IFS
              IFS=","
              for i in $data
                  do
                      IFS=$oldIFS
                      for bats_file in $(find . -name ${i}*.bats | grep -v $ignor_version); do
                          if [ -e $(pwd)/$bats_file ]; then
                              if [ X$OUTPUT_FORMAT == 'Xjunit' ]; then
                                  bats -u $(pwd)/$bats_file
                              elif [ X$OUTPUT_FORMAT == 'Xtap' ]; then
                                  bats -t $(pwd)/$bats_file
                              else
                                  bats $(pwd)/$bats_file
                              fi
                          fi
                    done
              IFS=$oldIFS
          done
          fi
      fi
      if [[ $# -eq 2 && $1 == 'uicases' ]]; then
          if [[ $2 == '-l' ]]; then
              echo "The supported ui cases were: "
              find ./suites/testui -name *.bats | awk -F '/' '{print $4}' | awk -F . '{print $1}'
          else
              pre-run
              data=$2
              oldIFS=$IFS
              IFS=","
              for i in $data
                  do
                      IFS=$oldIFS
                      for bats_file in $(find . -name ${i}*.bats | grep -v $ignor_version); do
                          if [ -e $(pwd)/$bats_file ]; then
                              if [ X$OUTPUT_FORMAT == 'Xjunit' ]; then
                                  bats -u $(pwd)/$bats_file
                              elif [ X$OUTPUT_FORMAT == 'Xtap' ]; then
                                  bats -t $(pwd)/$bats_file
                              else
                                  bats $(pwd)/$bats_file
                              fi
                          fi
                    done
              IFS=$oldIFS
           done
          fi
    fi

}

export INPUT_ARGUMENTS="${@}"

[[ "X$ARCH" == "X" ]] && ARCH=$(uname -m)
export ARCH

prepare_kubectl
mkdir -p $(pwd)/report

EXECUTE_DATE=$(date "+%Y-%m-%d")
get_version
get_accessip
cat << EOF > $(pwd)/report/environment.properties
icp.url=https://$ACCESS_IP:$ROUTER_HTTPS_PORT
icp.version=$VERSION
execute.date=$EXECUTE_DATE
EOF

if [[ $# -eq 0 ]]; then
  run_bats
else
  case $1 in
    '--groups'|-g)
       run_bats 'groups' $2
       ;;
    '--cases'|-c)
       run_bats 'cases' $2
        ;;
    '--uicases'|-ui)
        run_bats 'uicases' $2
        ;;
    '--ignore_groups'|-ng)
        run_bats 'ignore_groups' $2
        ;;
    '--ignore_cases'|-nc)
        run_bats 'ignore_cases' $2
        ;;
    '--help'|-h)
      help
      exit 0
       ;;
    *)
      help
      exit 1
       ;;
  esac
fi

exit ${EXIT_STATUS}
