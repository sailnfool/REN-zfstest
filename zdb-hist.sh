#!/bin/bash
zdb -bb tank |  tee > /tmp/dumpbbb.txt
zdb -Pbb tank | tee > /tmp/dumpPbbb.txt
