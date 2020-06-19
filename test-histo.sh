#!/bin/bash
set -x
cd ~/github/zfs
testpath=tests/functional/cli_root/zdb
# ./scripts/zfs-tests.sh -T misc
./scripts/zfs-tests.sh -t ${testpath}/zdb_display_block
./scripts/zfs-tests.sh -t ${testpath}/zdb_block_histogram
