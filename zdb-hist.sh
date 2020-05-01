#!/bin/bash
zdb -bbbbb tank | grep -v '^objset.*' > /tmp/dumpbbbbb.txt
zdb -Pbbbbb tank | grep -v '^objset.*' > /tmp/dumpPbbbbb.txt
