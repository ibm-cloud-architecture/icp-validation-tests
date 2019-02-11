#!/usr/bin/env bats

# This will load the helpers.
load ../../helpers

@test "management-ingress | Check the unified-router nodedetails api by ingress" {
    # Check the unified-router nodedetails api by ingress
    token_id=$($KUBECTL config view -o jsonpath='{.users[?(@.name == "admin")].user.token}')

    request_code=$(curl --connect-timeout 5 -s -w "%{http_code}" -k -H "Authorization: Bearer $token_id" https://$ACCESS_IP:$ROUTER_HTTPS_PORT/unified-router/api/v1/nodedetail -o /dev/null)

    [[ $request_code == '200' ]]
}
