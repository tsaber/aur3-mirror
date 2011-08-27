#!/bin/bash

. /etc/rc.conf
. /etc/rc.d/functions

source /etc/profile

RUNNING=`pgrep -f "wuala -nogui" | wc --lines`
case "$1" in
  start)
    stat_busy "Starting wuala"
    [ $RUNNING -eq 0 ] && su --command "~/wuala/wuala -nogui login WualaLoginName WualaPassword &" LinuxLoginName &> /dev/null;
    if [ $? -gt 0 ]; then
      stat_fail
    else
      add_daemon wualad
      stat_done
    fi
    ;;
  stop)
    stat_busy "Stopping wuala"
    [ $RUNNING -gt 0 ] && su --command "~/wuala/wuala exit &" LinuxLoginName &> /dev/null;
    if [ $? -gt 0 ]; then
      stat_fail
    else
      rm_daemon wualad
      stat_done
    fi
    ;;
  restart)
    $0 stop
    sleep 3
    $0 start
    ;;
  *)
    echo "usage: $0 {start|stop|restart}"
esac
exit 0

