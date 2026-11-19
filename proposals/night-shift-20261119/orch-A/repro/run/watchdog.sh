#!/bin/zsh
# W-repro watchdog (CPU rule, 2026-11-19 resume 2): a HOL child of this reproduction is HUNG only when its process tree
# gains no CPU time for 600 s of real time. Samples every 30 s; the 600 s window counts only samples taken while the
# process tree exists. The runner's own CPU/wall limits still apply.
RUN=${0:A:h}; LOG=$RUN/repro-driver.log
cpu_of() { ps -A -o pid=,ppid=,time= | awk -v root=$1 '
  {pid[NR]=$1; pp[NR]=$2; t=$3; n=split(t,a,"[:.]"); s=0; if(n==4){s=a[1]*60+a[2]+a[3]/100+0}else if(n==3){s=a[1]*60+a[2]}else{s=a[1]}; if(t ~ /-/){s=0} c[NR]=s}
  END{inc[root]=1; ch=1; while(ch){ch=0; for(i=1;i<=NR;i++) if(inc[pp[i]] && !inc[pid[i]]){inc[pid[i]]=1; ch=1}} tot=0; for(i=1;i<=NR;i++) if(inc[pid[i]]) tot+=c[i]; printf "%d\n", tot}'; }
last_cpu=-1; still=0; lastpid=
while true; do
  tail -1 $LOG 2>/dev/null | grep -qE 'ALL_DONE|STOP' && { echo "watchdog end: $(tail -1 $LOG)"; exit 0; }
  pid=$(pgrep -f "$RUN/.*proof.sml" | head -1)
  if [[ -n $pid ]]; then
    [[ $pid != $lastpid ]] && { lastpid=$pid; last_cpu=-1; still=0; }
    cpu=$(cpu_of $pid)
    if [[ $cpu -gt $last_cpu ]]; then last_cpu=$cpu; still=0; else still=$((still+30)); fi
    if [[ $still -ge 600 ]]; then echo "$(date -u +%FT%TZ) HUNG pid=$pid cpu_s=$cpu no CPU growth for $still s" | tee -a $LOG; pkill -f "$RUN/.*proof.sml"; echo "kill sent"; exit 3; fi
  fi
  sleep 30
done
