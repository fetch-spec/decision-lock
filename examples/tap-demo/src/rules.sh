status_ok() { case "$1" in new|paid|shipped) return 0;; *) return 1;; esac; }
discount() { echo $(( $1 > 100 ? $1 - 10 : $1 )); }
