. src/rules.sh
echo "1..3"
status_ok new && echo "ok 1 - D001-01 new allowed" || echo "not ok 1 - D001-01 new allowed"
status_ok refunded && echo "not ok 2 - D001-02 refunded rejected" || echo "ok 2 - D001-02 refunded rejected"
status_ok NEW && echo "not ok 3 - D001-03 case sensitive" || echo "ok 3 - D001-03 case sensitive"
