#!/bin/sh
go test ./... 2>&1
echo "TESTS_EXIT:$?"
go vet ./... 2>&1
echo "VET_EXIT:$?"
go build ./... 2>&1
echo "BUILD_EXIT:$?"
