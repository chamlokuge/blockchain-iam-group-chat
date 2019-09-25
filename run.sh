#!/usr/bin/env bash

/usr/bin/ballerina run GovID.bal &

/usr/bin/ballerina run Holder.bal &

/usr/bin/ballerina run ChatService.bal &
