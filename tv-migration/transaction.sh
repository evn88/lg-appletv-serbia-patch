#!/bin/sh
# Приложение закрывает внешний проверенный LS2-клиент; здесь нет запуска или перезагрузки.
set -eu
PATH=/usr/bin:/bin:/usr/sbin:/sbin
export PATH
umask 077
STATE=/var/lib/lg-oled48a1-webos/persistence/appletv-permanent-v1
OLD=/var/lib/lg-oled48a1-webos/persistence/appletv17-v3
APP=/media/cryptofs/apps/usr/palm/applications/com.apple.appletv
JAIL=/var/palm/jail/com.apple.appletv
LOW=/media/squashfs/apps/com.apple.appletv/usr/palm/applications/com.apple.appletv
IMAGE=/media/cryptofs/apps/usr/palm/data/images/com.apple.appletv/data.img
PACKAGE=/media/cryptofs/apps/usr/palm/packages/com.apple.appletv/packageinfo.json
WORKER_SHA=76e1dc38a90b31f28f90b5b00b49a8e6ba17cc4dba47acbb6f361b079a5840ce
TEMP_MAIN=; TEMP_APP=; ID_MAIN=; ID_APP=
fail() { printf 'STOP:%s\n' "$*" >&2; exit 1; }
hash() { sha256sum "$1" | awk '{print $1}'; }
regular() { test -f "$1" && test ! -L "$1" || fail "E_FILE:$1"; }
attrs() { stat -c '%a:%u:%g' "$1"; }
identity() { stat -c '%d:%i' "$1"; }
select_file() {
 NAME=$1
 case "$NAME" in
 main) ORIGINAL=d9c95106c263090df8b893d34f8c8f261b52d722bf7fd63923e9ed38b31be9c8; CANDIDATE=2f406936ba4c05b43d7709b33f7fe6f7fdc5f454eff741a1ffea023f9b6433c5;;
 app) ORIGINAL=a4071bd6f36d3be07093d9dabd05b28d69713d74ceb09743e9a0340578b605f8; CANDIDATE=b20ce8baa307fad236629c177ae83a1271287cc87df7f3fc9fd292762680f1cc;;
 *) fail E_NAME;; esac
 TARGET=$APP/res/$NAME.js
}
path_safe() {
 P=$1
 while test "$P" != /;do test ! -L "$P" || fail "E_SYMLINK:$P";P=${P%/*};test -n "$P" || P=/;done
}
privileged() {
 test "$(id -u)" = 0 || fail E_NOT_ROOT
 test "$(readlink /proc/self/root)" = / || fail E_CHROOT
 test "$(readlink /proc/self/ns/mnt)" = "$(readlink /proc/1/ns/mnt)" || fail E_HOST_NAMESPACE
}
stopped() { test -z "$(pidof AppleTV || true)" || fail E_APP_RUNNING; }
parents() { awk -v a="$APP" -v j="$JAIL$APP" '$5==a || $5==j {print}' /proc/self/mountinfo; }
file_mounts() { awk -v a="$APP" -v j="$JAIL$APP" 'index($5,a"/")==1 || index($5,j"/")==1 {print}' /proc/self/mountinfo; }
no_file_mounts() { test -z "$(file_mounts)" || fail E_FILE_MOUNT; }
layout() {
 privileged
 path_safe "$APP/res";path_safe "$LOW/res";path_safe "$IMAGE";path_safe "$PACKAGE"
 awk -v a="$APP" -v j="$JAIL$APP" -v l="$LOW" '
 $5=="/media" {if($3!="179:53" || $4!="/" || $6!~/^rw(,|$)/)exit 1; for(i=7;i<=NF;i++)if($i=="-"){if($(i+1)!="ext4"||$(i+2)!="/dev/mmcblk0p53")exit 1;media++}}
 $5==a || $5==j {if($4!="/"||$6!~/^rw(,|$)/)exit 1;for(i=7;i<=NF;i++)if($i=="-"){if($(i+1)!="overlay"||$(i+2)!="overlay"||$(i+3)!="rw,lowerdir="l",upperdir="a",workdir=/media/squashfs/work/com.apple.appletv")exit 1;if($5==a){host++;dev=$3}else{jail++;jdev=$3}}}
 END{if(media!=1||host!=1||jail>1||(jail==1&&dev!=jdev))exit 1}' /proc/self/mountinfo || fail E_LAYOUT
}
static_pins() {
 regular "$IMAGE";test "$(hash "$IMAGE")" = 1f9ca721219bfb26745365e314d7e0cdd07272a37c02c40e166cdc32f4c98979 || fail E_IMAGE
 test "$(stat -c '%s' "$IMAGE")" = 24944640 || fail E_IMAGE_SIZE
 for BASE in "$APP";do
  for F in appinfo.json AppleTV res/bootstrap.js;do path_safe "$BASE/$F";regular "$BASE/$F";done
  test "$(hash "$BASE/appinfo.json")" = 0417a0e1235e205cc5310020ca3f3fcc6b7deffe62ec3390bdfe3ddbd550eb1f || fail E_APPINFO
  test "$(hash "$BASE/AppleTV")" = e3faf61cccfa9ef07d80bef1333f187b4726d817f3fae1d3f8ec30368ca316dc || fail E_BINARY
  test "$(hash "$BASE/res/bootstrap.js")" = 02d1a02706d2c0792b764b667b201d0682e4c144ad97e59984bf0fd4ad4e8797 || fail E_BOOTSTRAP
 done
 for F in AppleTV res/bootstrap.js;do path_safe "$LOW/$F";regular "$LOW/$F";done
 test "$(hash "$LOW/AppleTV")" = e3faf61cccfa9ef07d80bef1333f187b4726d817f3fae1d3f8ec30368ca316dc || fail E_LOWER_BINARY
 test "$(hash "$LOW/res/bootstrap.js")" = 02d1a02706d2c0792b764b667b201d0682e4c144ad97e59984bf0fd4ad4e8797 || fail E_LOWER_BOOTSTRAP
 regular "$PACKAGE"
 test "$(tr -d ' \r\n' < "$PACKAGE")" = '{"app":"com.apple.appletv","id":"com.apple.appletv","version":"17.0.3"}' || fail E_PACKAGE
 for FILE in main app;do select_file "$FILE";regular "$LOW/res/$NAME.js";test "$(hash "$LOW/res/$NAME.js")" = "$ORIGINAL" || fail E_LOWER_JS;done
}
pair() {
 MODE=$1
 layout;static_pins
 for FILE in main app;do
  select_file "$FILE";path_safe "$TARGET";regular "$TARGET"
  test "$(attrs "$TARGET")" = 644:0:5000 || fail E_TARGET_ATTRS
  NOW=$(hash "$TARGET")
  case "$MODE" in original)test "$NOW" = "$ORIGINAL" || fail E_HOST_ORIGINAL;;candidate)test "$NOW" = "$CANDIDATE" || fail E_HOST_CANDIDATE;;mixed)test "$NOW" = "$ORIGINAL" || test "$NOW" = "$CANDIDATE" || fail E_UNKNOWN_JS;;*)fail E_MODE;;esac
 done
}
state_secure() {
 path_safe "$STATE"
 for D in /var /var/lib /var/lib/lg-oled48a1-webos /var/lib/lg-oled48a1-webos/persistence "$STATE";do test -d "$D" && test "$(stat -c '%u' "$D")" = 0 || fail E_STATE_PARENT;done
 test "$(attrs "$STATE")" = 700:0:0 || fail E_STATE_MODE
}
worker_ready() {
 path_safe "$OLD";regular "$OLD/worker.sh"
 test "$(hash "$OLD/worker.sh")" = "$WORKER_SHA" || fail E_WORKER
 test "$(attrs "$OLD")" = 700:0:0 || fail E_OLD_STATE
 for FILE in main app;do
  select_file "$FILE"
  for F in "$OLD/candidate-$NAME.js" "$OLD/original-$NAME.js";do path_safe "$F";regular "$F";test "$(attrs "$F")" = 644:0:5000 || fail E_OLD_SOURCE_ATTRS;done
  test "$(hash "$OLD/candidate-$NAME.js")" = "$CANDIDATE" || fail E_OLD_CANDIDATE
  test "$(hash "$OLD/original-$NAME.js")" = "$ORIGINAL" || fail E_OLD_ORIGINAL
 done
}
owned_pair() {
 worker_ready
 test "$(parents | awk 'NF{n++}END{print n+0}')" = 2 || fail E_JAIL_REQUIRED
 test "$(file_mounts | awk 'NF{n++}END{print n+0}')" = 2 || fail E_EXPECT_TWO_BINDS
 for FILE in main app;do
  select_file "$FILE";JT=$JAIL$TARGET;path_safe "$JT"
  LINE=$(awk -v p="$JT" '$5==p{print}' /proc/self/mountinfo)
  test "$(printf '%s\n' "$LINE" | awk 'NF{n++}END{print n+0}')" = 1 || fail E_BIND_COUNT
  test "$(printf '%s\n' "$LINE" | awk '{print $4}')" = "$OLD/candidate-$NAME.js" || fail E_BIND_SOURCE
  test "$(identity "$JT")" = "$(identity "$OLD/candidate-$NAME.js")" || fail E_BIND_ID
  test "$(hash "$JT")" = "$CANDIDATE" || fail E_BIND_BYTES
 done
}
same_context() {
 test "$(readlink /proc/self/ns/mnt)" = "$(cat "$STATE/namespace.before")" || fail E_NAMESPACE_CHANGED
 test "$(parents)" = "$(cat "$STATE/parents.before")" || fail E_PARENTS_CHANGED
}
worker_flags_unchanged() {
 case "$(cat "$STATE/disabled-state.before")" in
 absent)test ! -e "$OLD/disabled" && test ! -L "$OLD/disabled" || fail E_DISABLED_CHANGED;;
 present)regular "$OLD/disabled";test "$(attrs "$OLD/disabled")" = 600:0:0 && test "$(hash "$OLD/disabled")" = "$(hash "$STATE/disabled.before")" || fail E_DISABLED_CHANGED;;
 *)fail E_DISABLED_SNAPSHOT;;esac
 test "$(cat "$OLD/current")" = "$(cat "$STATE/worker-current.before")" || fail E_WORKER_CURRENT_CHANGED
}
stable_copy() {
 SRC=$1;DST=$2
 path_safe "$SRC";regular "$SRC";test ! -e "$DST" && test ! -L "$DST" || fail E_BACKUP_EXISTS
 BEFORE=$(stat -c '%d:%i:%s:%Y:%Z:%a:%u:%g' "$SRC");HASH_BEFORE=$(hash "$SRC")
 cp -p "$SRC" "$DST" || fail E_COPY
 test "$(stat -c '%d:%i:%s:%Y:%Z:%a:%u:%g' "$SRC")" = "$BEFORE" && test "$(hash "$SRC")" = "$HASH_BEFORE" && test "$(hash "$DST")" = "$HASH_BEFORE" || fail "E_COPY_RACE:$SRC"
 test "$(attrs "$SRC")" = "$(attrs "$DST")" || fail E_COPY_ATTRS
}
prepare() {
 privileged;pair original;owned_pair
 path_safe "$STATE";test ! -e "$STATE" && test ! -L "$STATE" || fail E_PREP_EXISTS
 PARENT=${STATE%/*};test -d "$PARENT" && test "$(stat -c '%u' "$PARENT")" = 0 || fail E_PREP_PARENT
 mkdir -m 700 "$STATE" || fail E_MKDIR;state_secure
 : > "$STATE/lock";chmod 600 "$STATE/lock" || fail E_LOCK_CREATE
 cat /proc/sys/kernel/random/uuid > "$STATE/token" || fail E_TOKEN_WRITE
 readlink /proc/self/ns/mnt > "$STATE/namespace.before"
 parents > "$STATE/parents.before";cat /proc/self/mountinfo > "$STATE/mountinfo.before"
 cat /proc/sys/kernel/random/boot_id > "$STATE/boot.before"
 file_mounts > "$STATE/binds.before"
 if test -e "$OLD/disabled" || test -L "$OLD/disabled";then regular "$OLD/disabled";test "$(attrs "$OLD/disabled")" = 600:0:0 || fail E_DISABLED_ATTRS;stable_copy "$OLD/disabled" "$STATE/disabled.before";echo present > "$STATE/disabled-state.before";else echo absent > "$STATE/disabled-state.before";fi
 stable_copy "$OLD/worker.sh" "$STATE/worker.before.sh"
 regular "$OLD/current";TX=$(cat "$OLD/current");case "$TX" in "$OLD"/attempt.*) ;;*)fail E_WORKER_CONTEXT;;esac
 SUFFIX=${TX#"$OLD"/attempt.};case "$SUFFIX" in ''|*[!A-Za-z0-9]*)fail E_WORKER_CONTEXT;;esac
 path_safe "$TX";test -d "$TX" && test "$(attrs "$TX")" = 700:0:0 || fail E_WORKER_CONTEXT
 stable_copy "$OLD/current" "$STATE/worker-current.before"
 for F in namespace.before parents.before source-main.identity source-app.identity intent-main intent-app mounted-main mounted-app;do stable_copy "$TX/$F" "$STATE/worker-$F";done
 for FILE in main app;do
  select_file "$FILE";stable_copy "$TARGET" "$STATE/original-$NAME.js";stable_copy "$JAIL$TARGET" "$STATE/jail-$NAME.before.js";stable_copy "$OLD/candidate-$NAME.js" "$STATE/candidate-$NAME.js"
  identity "$TARGET" > "$STATE/host-$NAME.identity"
  stat -c '%n %a:%u:%g %s %d:%i' "$TARGET" "$JAIL$TARGET" "$OLD/candidate-$NAME.js" > "$STATE/attrs-$NAME.before"
 done
 stable_copy "$APP/appinfo.json" "$STATE/appinfo.before.json";stable_copy "$APP/res/bootstrap.js" "$STATE/bootstrap.before.js";stable_copy "$PACKAGE" "$STATE/packageinfo.before.json"
 sha256sum "$IMAGE" "$APP/AppleTV" > "$STATE/large-files.before.sha256"
 if test -e "$LOW/appinfo.json" || test -L "$LOW/appinfo.json";then fail E_UNEXPECTED_LOWER_APPINFO;else echo ABSENT > "$STATE/lower-appinfo.before";fi
 PIDS=$(pidof AppleTV || true);printf '%s\n' "$PIDS" > "$STATE/apple-pids.before"
 case "$PIDS" in ''|*' '*|*[!0-9]*) ;;*)cat "/proc/$PIDS/stat" > "$STATE/apple-stat.before";readlink "/proc/$PIDS/exe" > "$STATE/apple-exe.before";;esac
 pair original;owned_pair;same_context
 test "$(file_mounts)" = "$(cat "$STATE/binds.before")" || fail E_BINDS_CHANGED
 (cd "$STATE" && find . -maxdepth 1 -type f ! -name receipt.sha256 -print | LC_ALL=C sort | while IFS= read -r F;do sha256sum "$F" || exit 1;done) > "$STATE/receipt.sha256" || fail E_RECEIPT
 sync -f "$STATE" || fail E_PREP_SYNC
 printf 'PREPARED_TOKEN=%s\nRECEIPT_SHA256=%s\nSTATE=%s\n' "$(cat "$STATE/token")" "$(hash "$STATE/receipt.sha256")" "$STATE"
}
receipt_ready() {
 state_secure
 for F in token receipt.sha256 mac-verified;do regular "$STATE/$F";done
 test "$TOKEN" = "$(cat "$STATE/token")" || fail E_TOKEN
 test "$(cat "$STATE/mac-verified")" = "$(hash "$STATE/receipt.sha256")" || fail E_MAC_ACK
 (cd "$STATE" && sha256sum -c receipt.sha256) >/dev/null || fail E_RECEIPT_CHANGED
 for FILE in main app;do select_file "$FILE";test "$(hash "$STATE/original-$NAME.js")" = "$ORIGINAL" && test "$(hash "$STATE/candidate-$NAME.js")" = "$CANDIDATE" || fail E_BACKUP_PINS;done
}
lock_transaction() {
 regular "$STATE/lock";test "$(attrs "$STATE/lock")" = 600:0:0 || fail E_LOCK_ATTRS
 exec 9<"$STATE/lock";flock -n 9 || fail E_LOCKED
}
status() {
 STATUS_TEMP=$(mktemp "$STATE/status.XXXXXX") || fail E_STATUS_TEMP
 printf '%s\n' "$1" > "$STATUS_TEMP" || fail E_STATUS_WRITE
 mv "$STATUS_TEMP" "$STATE/status" || fail E_STATUS_RENAME
 sync -f "$STATE" || fail E_STATUS_SYNC
}
check_stopped_pair() { stopped;receipt_ready;pair "$1";no_file_mounts; }
cleanup_temps() {
 for N in MAIN APP;do
  if test "$N" = MAIN;then T=$TEMP_MAIN;I=$ID_MAIN;else T=$TEMP_APP;I=$ID_APP;fi
  if test -n "$T" && { test -e "$T" || test -L "$T"; };then
   path_safe "$T";regular "$T";test "$(identity "$T")" = "$I" || fail E_TEMP_ID
   rm "$T" || fail E_TEMP_REMOVE
  fi
 done
 TEMP_MAIN=;TEMP_APP=;ID_MAIN=;ID_APP=
}
load_temps() {
 for N in main app;do
  if test -e "$STATE/temp-$N.path" || test -L "$STATE/temp-$N.path";then
   regular "$STATE/temp-$N.path";regular "$STATE/temp-$N.identity"
   T=$(cat "$STATE/temp-$N.path");I=$(cat "$STATE/temp-$N.identity")
   case "$T" in "$APP/res/.apple-permanent-$TOKEN-$N."*) ;;*)fail E_TEMP_PATH;;esac
   SUFFIX=${T#"$APP/res/.apple-permanent-$TOKEN-$N."};case "$SUFFIX" in ''|*[!A-Za-z0-9]*)fail E_TEMP_SUFFIX;;esac
   if test "$N" = main;then TEMP_MAIN=$T;ID_MAIN=$I;else TEMP_APP=$T;ID_APP=$I;fi
  fi
 done
}
stage() {
 STAGE_NAME=$1;SRC=$2
 select_file "$STAGE_NAME";regular "$SRC"
 STAGE_HASH=$(hash "$SRC");case "$STAGE_HASH" in "$ORIGINAL"|"$CANDIDATE");;*)fail E_STAGE_SOURCE;;esac
 T=$(mktemp "$APP/res/.apple-permanent-$TOKEN-$STAGE_NAME.XXXXXX") || fail E_STAGE_TEMP
 I=$(identity "$T")
 if test "$STAGE_NAME" = main;then TEMP_MAIN=$T;ID_MAIN=$I;else TEMP_APP=$T;ID_APP=$I;fi
 printf '%s\n' "$T" > "$STATE/temp-$STAGE_NAME.path" || fail E_TEMP_RECORD
 printf '%s\n' "$I" > "$STATE/temp-$STAGE_NAME.identity" || fail E_TEMP_RECORD
 sync -f "$STATE" || fail E_TEMP_RECORD_SYNC
 cat "$SRC" > "$T" || fail E_STAGE_COPY
 chown 0:5000 "$T" || fail E_STAGE_OWNER;chmod 644 "$T" || fail E_STAGE_MODE
 test "$(attrs "$T")" = 644:0:5000 && test "$(identity "$T")" = "$I" && test "$(hash "$T")" = "$STAGE_HASH" || fail E_STAGE_CHECK
 sync -f "$T" || fail E_STAGE_SYNC
}
commit_stage() {
 COMMIT_NAME=$1;EXPECTED=$2
 select_file "$COMMIT_NAME"
 if test "$NAME" = main;then T=$TEMP_MAIN;I=$ID_MAIN;else T=$TEMP_APP;I=$ID_APP;fi
 regular "$T";test "$(identity "$T")" = "$I" && test "$(attrs "$T")" = 644:0:5000 && test "$(hash "$T")" = "$EXPECTED" || fail E_COMMIT_STAGE
 BEFORE_ID=$(identity "$TARGET")
 status "INTENT_$COMMIT_NAME:$BEFORE_ID:$EXPECTED"
 stopped;pair mixed;no_file_mounts
 select_file "$COMMIT_NAME"
 test "$(identity "$TARGET")" = "$BEFORE_ID" || fail E_COMMIT_TARGET_ID
 mv -f "$T" "$TARGET" || fail E_COMMIT_RENAME
 if test "$NAME" = main;then TEMP_MAIN=;ID_MAIN=;else TEMP_APP=;ID_APP=;fi
 sync -f "$APP/res" || fail E_COMMIT_SYNC
 test "$(identity "$TARGET")" = "$I" && test "$(hash "$TARGET")" = "$EXPECTED" && test "$(attrs "$TARGET")" = 644:0:5000 || fail E_COMMIT_RESULT
 status "DONE_$COMMIT_NAME:$I:$EXPECTED"
}
rollback_core() {
 check_stopped_pair mixed
 load_temps
 cleanup_temps
 for RESTORE in main app;do
  select_file "$RESTORE"
  if test "$(hash "$TARGET")" = "$CANDIDATE";then
   stage "$RESTORE" "$STATE/original-$RESTORE.js"
   check_stopped_pair mixed
   select_file "$RESTORE";commit_stage "$RESTORE" "$ORIGINAL"
  fi
 done
 check_stopped_pair original;status ROLLED_BACK
}
apply() {
 receipt_ready;lock_transaction;stopped;pair original;owned_pair;same_context
 worker_flags_unchanged
 test "$(file_mounts)" = "$(cat "$STATE/binds.before")" || fail E_BINDS_CHANGED
 for FILE in main app;do select_file "$FILE";test "$(identity "$TARGET")" = "$(cat "$STATE/host-$NAME.identity")" || fail E_PREP_TARGET_ID;done
 worker_ready;regular "$OLD/lock";test "$(attrs "$OLD/lock")" = 600:0:0 || fail E_WORKER_LOCK
 exec 8<"$OLD/lock";flock -n 8 || fail E_WORKER_BUSY
 sh "$OLD/worker.sh" --verify || fail E_WORKER_VERIFY
 stopped;pair original;owned_pair;same_context
 worker_flags_unchanged
 status WORKER_DISABLE_INTENT
 sh "$OLD/worker.sh" --disable || fail E_WORKER_DISABLE
 stopped;sh "$OLD/worker.sh" --remove || fail E_WORKER_REMOVE
 check_stopped_pair original;same_context
 trap 'RC=$?;trap - 0 HUP INT TERM;if (rollback_core);then echo AUTO_ROLLBACK_PASS >&2;else echo E_AUTO_ROLLBACK_PENDING >&2;fi;exit "$RC"' 0
 trap 'exit 143' HUP INT TERM
 status APPLYING
 stage main "$STATE/candidate-main.js";stage app "$STATE/candidate-app.js"
 check_stopped_pair original;same_context
 select_file main;commit_stage main "$CANDIDATE"
 check_stopped_pair mixed;same_context
 select_file app;commit_stage app "$CANDIDATE"
 check_stopped_pair candidate;same_context
 if test -d "$JAIL$APP/res";then for FILE in main app;do select_file "$FILE";test "$(hash "$JAIL$TARGET")" = "$CANDIDATE" || fail E_JAIL_VISIBLE;done;fi
 status APPLIED
 trap - 0 HUP INT TERM
 echo PERSISTENT_PAIR_APPLIED
}
case "${1:-}" in
 --prepare) test "$#" = 1 || fail E_ARGS;prepare;;
 --apply|--verify|--rollback)
  test "$#" = 2 || fail E_ARGS;TOKEN=$2;case "$TOKEN" in ''|*[!0-9a-f-]*)fail E_TOKEN_FORMAT;;esac
  case "$1" in
  --apply)apply;;
  --verify)receipt_ready;pair candidate;no_file_mounts;echo PERSISTENT_PAIR_VERIFIED;;
  --rollback)receipt_ready;lock_transaction;rollback_core;echo ORIGINAL_PAIR_RESTORED;;
  esac;;
 *)fail 'Usage: --prepare | --apply TOKEN | --verify TOKEN | --rollback TOKEN';;
esac
