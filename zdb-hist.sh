#!/bin/bash
host=$(hostname)
BENCH=bench_results/${host}
case ${host} in
jet*)
    RESULTS=/tftpboot/global/novak5/${BENCH}
    ;;
*)
    RESULTS=$HOME/bench_results/${BENCH}
    ;;
esac
mkdir -P ${RESULTS}
echo "${0##*/}: We are on ${host} and will place results in directory ${RESULTS}"
echo "/bin/time zdb -bbb ${host} |  tee  ${RESULTS}/${host}.dumpbbb.txt"
/bin/time zdb -bbb ${host} |  tee  ${RESULTS}/${host}.dumpbbb.txt
echo "/bin/time zdb -Pbbb ${host} | tee  ${RESULTS}/${host}.dumpPbbb.txt"
/bin/time zdb -Pbbb ${host} | tee  ${RESULTS}/${host}.dumpPbbb.txt
