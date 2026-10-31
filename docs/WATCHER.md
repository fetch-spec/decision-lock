# Watcher: check every 30 minutes

Pipelines run for hours. A watcher looks at them every 30 minutes so a stuck or stopped slice is noticed and restarted, and so a human only hears about a slice when the loops have run out.

## What the watcher checks, per slice

1. **Is the pipeline process alive?** (`pgrep -f pipeline.sh` or `Get-Process` for the PowerShell host.)
2. **What was the last line of its log?** The pipeline prints one timestamped line per step (`14:05 CERT2 exit=0`, `14:31 CERTIFIED on round 2`, `RESULT: ...`, `STOPPED: ...`).
3. **Decide:**

| Last line | Meaning | Action |
|---|---|---|
| `RESULT: REPRODUCED ...` (exit 0) | done | tell the human once, stop watching the slice |
| `STOPPED: ...` (exit 3) | a tool error (rate limit, CLI crash, no report written). There is no evidence either way. | read the `*.receipt.txt` named in the line; retry the same step with `--skip-build` and `--start N`, or `--fix-first` if you need to re-run a brief. Do NOT send it to the builder as a test failure. |
| `STILL NOT CERTIFIED` (exit 4) or `STILL NOT REPRODUCED` (exit 5) | the loops are exhausted | investigate root cause (read the last cert or independent report, run the failing test yourself), then tell the human WITH the cause. |
| process dead, no `RESULT`/`STOPPED` line, log older than 45 minutes | the host or terminal died | restart with `--skip-build` and `--start N` for the round it was on |
| log updated in the last 30 minutes | working | do nothing |

4. **Containers.** `docker ps --filter label=decision-lock=1` should list one container per running slice. Remove containers of finished slices with `scripts/db.sh stop`.

Never report a single failed run to the human (lesson 6). Loop first, find the cause, then report.

## Example: cron (macOS/Linux)

Run the pipeline with its output in a log, then add a crontab entry for the checker:

```bash
nohup scripts/pipeline.sh --slice D021-D030 --dir ../slice-D021-D030 >> ../slice-D021-D030/pipeline.log 2>&1 &
```

```
*/30 * * * * /path/to/watch.sh /path/to/slice-D021-D030 >> /path/to/watch.log 2>&1
```

`watch.sh` (sketch):

```bash
#!/usr/bin/env bash
dir=$1; log="$dir/pipeline.log"
last=$(grep -E 'RESULT:|STOPPED:|CERTIFIED on|exit=' "$log" | tail -1)
case "$last" in
  *"RESULT: REPRODUCED"*) echo "DONE $dir: $last" ;;
  *STOPPED*|*"STILL NOT"*) echo "ATTENTION $dir: $last" ;;
  *) [ -n "$(find "$log" -mmin -45)" ] || echo "STALE $dir: $last" ;;
esac
```

Pipe the `DONE`/`ATTENTION`/`STALE` lines to whatever notifies you (mail, a chat webhook).

## Example: Task Scheduler (Windows)

```powershell
$action  = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-NoProfile -File C:\work\watch.ps1 -Dir C:\work\slice-D021-D030'
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 30)
Register-ScheduledTask -TaskName 'decision-lock-watch' -Action $action -Trigger $trigger
```

`watch.ps1` does the same as the shell sketch: read the last timestamped line of `pipeline.log` and the age of the file.

## Example: an AI routine

Any agent scheduler (a Claude Code routine, a cron-driven agent) can be the watcher. Give it this brief, by file pointer:

> For each slice working copy listed below: read the last 20 lines of `pipeline.log`. If it ended in `RESULT: REPRODUCED`, report it as done once. If it ended in `STOPPED`, read the named receipt file, say what the tool error was, and restart the pipeline with `--skip-build --start <round>`. If it ended in `STILL NOT CERTIFIED` or `STILL NOT REPRODUCED`, read the last cert or independent report, run the failing test yourself on a fresh throwaway database, and report the root cause. If the log is older than 45 minutes with no result line, restart it. Never touch a live database and never edit tests or mutants yourself.

Keep the watcher read-only except for restarting the pipeline. It must not fix tests: that is the builder's job, inside the loop.
