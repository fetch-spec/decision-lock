. src/rules.sh
echo "1..1"
[ "$(discount 5)" = 5 ] && echo "ok 1 - D002-01 small unchanged" || echo "not ok 1 - D002-01 small unchanged"
