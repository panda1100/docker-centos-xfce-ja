#!/bin/bash

unset PORT
unset PASSWORD
/usr/bin/code-server --verbose --bind-addr 127.0.0.1:8055 --disable-telemetry $CODE_OPTS
