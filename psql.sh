#!/bin/sh
# Mở psql vào database lab (container pgidx).
exec docker exec -i pgidx psql -U lab -d lab -X "$@"
