#!/usr/bin/env bash

/usr/lib/ballerina/ballerina-0.990.2/bin/ballerina run GovID.bal &

/usr/lib/ballerina/ballerina-0.990.2/bin/ballerina run Holder.bal &

/usr/lib/ballerina/ballerina-0.990.2/bin/ballerina run ChatService.bal &
