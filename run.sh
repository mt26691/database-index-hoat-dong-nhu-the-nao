#!/bin/sh
# Chạy lab của một chương và lưu kết quả:  ./run.sh 04
set -e
cd "$(dirname "$0")"
f=$(ls chapters/"$1"-*.sql)
./psql.sh -v ON_ERROR_STOP=1 -e < "$f" > results/"$1".txt 2>&1
echo "→ results/$1.txt"
