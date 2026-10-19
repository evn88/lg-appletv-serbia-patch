"""Реальные функции shell с локальными файлами и синтетическими /proc и владельцами."""
from pathlib import Path
import hashlib, json, shutil, subprocess, tempfile, sys
ROOT = Path(__file__).resolve().parent
DATA = {(name, kind): ("synthetic-" + name + "-" + kind + "\n").encode()
        for name in ("main", "app") for kind in ("original", "candidate")}
WORKER_BYTES = b"synthetic worker fixture\n"
TEXT = (ROOT / "transaction.sh").read_text()
DEFS = TEXT[:TEXT.index('case "${1:-}" in')].replace('/proc/self/mountinfo', '"$MOUNTINFO"')
DEFS = DEFS.replace('for D in /var /var/lib /var/lib/lg-oled48a1-webos /var/lib/lg-oled48a1-webos/persistence "$STATE";do', 'for D in "$STATE";do')
# Test the real transaction functions with tiny synthetic files, never vendor data.
for known, payload in {
    "d9c95106c263090df8b893d34f8c8f261b52d722bf7fd63923e9ed38b31be9c8": DATA[("main", "original")],
    "a4071bd6f36d3be07093d9dabd05b28d69713d74ceb09743e9a0340578b605f8": DATA[("app", "original")],
    "2f406936ba4c05b43d7709b33f7fe6f7fdc5f454eff741a1ffea023f9b6433c5": DATA[("main", "candidate")],
    "b20ce8baa307fad236629c177ae83a1271287cc87df7f3fc9fd292762680f1cc": DATA[("app", "candidate")],
    "76e1dc38a90b31f28f90b5b00b49a8e6ba17cc4dba47acbb6f361b079a5840ce": WORKER_BYTES,
}.items():
    DEFS = DEFS.replace(known, hashlib.sha256(payload).hexdigest())
MOCK = r'''
LAB=$1;CASE=$2
STATE=$LAB/permanent;OLD=$LAB/old
APP=$LAB/app;JAIL=$LAB/jail;LOW=$LAB/lower;IMAGE=$LAB/image;PACKAGE=$LAB/packageinfo
MOUNTINFO=$LAB/mountinfo
export LAB CASE STATE OLD APP JAIL LOW IMAGE PACKAGE MOUNTINFO
privileged() { :; }
sha256sum() { command shasum -a 256 "$@"; }
hash() {
 case "$1" in
 "$IMAGE")if test -f "$LAB/new-version";then echo changed;else echo 1f9ca721219bfb26745365e314d7e0cdd07272a37c02c40e166cdc32f4c98979;fi;;
 */appinfo.json|*/appinfo.before.json)echo 0417a0e1235e205cc5310020ca3f3fcc6b7deffe62ec3390bdfe3ddbd550eb1f;;
 */AppleTV)echo e3faf61cccfa9ef07d80bef1333f187b4726d817f3fae1d3f8ec30368ca316dc;;
 */bootstrap.js|*/bootstrap.before.js)echo 02d1a02706d2c0792b764b667b201d0682e4c144ad97e59984bf0fd4ad4e8797;;
 "$JAIL"*)
  N=${1##*/};if test -f "$LAB/binds";then command shasum -a 256 "$OLD/candidate-$N"|command awk '{print $1}';else command shasum -a 256 "$APP/res/$N"|command awk '{print $1}';fi;;
 *)command shasum -a 256 "$1"|command awk '{print $1}';;
 esac
}
stat() {
 F=$2;P=$3
 case "$F" in
 %u)echo 0;;
 %a:%u:%g)case "$P" in "$STATE"|"$OLD"|"$OLD/attempt.fixture")echo 700:0:0;;*/lock|*/disabled)echo 600:0:0;;*)echo 644:0:5000;;esac;;
 %s)if test "$P" = "$IMAGE";then echo 24944640;else command stat -f %z "$P";fi;;
 %d:%i)case "$P" in "$JAIL"*)N=${P##*/};if test -f "$LAB/binds";then P=$OLD/candidate-$N;else P=$APP/res/$N;fi;;esac;command stat -f '%d:%i' "$P";;
 %d:%i:%s:%Y:%Z:%a:%u:%g)command stat -f '%d:%i:%z:%m:0:%Lp:%u:%g' "$P";;
 *)command stat -f '%N %Lp:%u:%g %z %d:%i' "$P";;
 esac
}
readlink() { case "$1" in /proc/*/ns/mnt)echo 'mnt:[fixture]' ;;*)command readlink "$1";;esac; }
cat() { case "$1" in /proc/sys/kernel/random/uuid)echo aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee;;/proc/sys/kernel/random/boot_id)echo fixture-boot;;*)command cat "$@";;esac; }
pidof() { if test -f "$LAB/running";then echo 6019;fi; }
flock() { :; }
sync() { :; }
chown() { :; }
mv() {
 LAST=;for ARG in "$@";do LAST=$ARG;done
 case "$LAST" in "$APP/res/"*)
  if test -f "$LAB/fail-second" && test "$LAST" = "$APP/res/app.js";then rm "$LAB/fail-second";return 1;fi
  printf '%s\n' "$LAST" >> "$LAB/renames"
  command mv "$@" || return
  if test "$LAST" = "$APP/res/main.js";then
   if test -f "$LAB/kill-first";then rm "$LAB/kill-first";kill -KILL $$;fi
   if test -f "$LAB/term-first";then rm "$LAB/term-first";kill -TERM $$;fi
   if test -f "$LAB/update-first";then rm "$LAB/update-first";touch "$LAB/new-version";fi
  fi;;
 *)command mv "$@";;esac
}
sh() {
 test "$1" = "$OLD/worker.sh" || return 90
 case "$2" in
 --verify)owned_pair;;
 --disable)printf 'DISABLE\n' >> "$LAB/worker-calls";: > "$OLD/disabled";;
 --remove)printf 'REMOVE\n' >> "$LAB/worker-calls";rm "$LAB/binds";command awk -v a="$APP" -v j="$JAIL$APP" '$5=="/media"||$5==a||$5==j' "$MOUNTINFO" > "$LAB/mount-new";command mv "$LAB/mount-new" "$MOUNTINFO";;
 *)return 91;;esac
}
'''

def run(lab, body, case="valid"):
    return subprocess.run(["/bin/sh", "-s", "--", str(lab), case], input=DEFS+MOCK+"\n"+body, text=True, capture_output=True, timeout=45)

def fixture(lab):
    app=lab/"app";old=lab/"old";low=lab/"lower";jail=Path(str(lab/"jail")+str(app))
    for d in (app/"res",low/"res",jail/"res",old/"attempt.fixture"):
        d.mkdir(parents=True)
    for n in ("main","app"):
        for dest in (app/"res"/f"{n}.js",low/"res"/f"{n}.js",old/f"original-{n}.js"):
            dest.write_bytes(DATA[(n, "original")])
        for dest in (jail/"res"/f"{n}.js",old/f"candidate-{n}.js"):
            dest.write_bytes(DATA[(n, "candidate")])
    for d in (app,low):
        (d/"AppleTV").write_text("binary fixture")
        (d/"res/bootstrap.js").write_text("bootstrap fixture")
    (app/"appinfo.json").write_text("appinfo fixture")
    (lab/"image").write_text("image fixture")
    (lab/"packageinfo").write_text('{"app":"com.apple.appletv","id":"com.apple.appletv","version":"17.0.3"}')
    (old/"worker.sh").write_bytes(WORKER_BYTES)
    (old/"current").write_text(str(old/"attempt.fixture")+"\n")
    (old/"lock").write_text("")
    for name in ("namespace.before","parents.before","source-main.identity","source-app.identity","intent-main","intent-app","mounted-main","mounted-app"):
        (old/"attempt.fixture"/name).write_text("fixture")
    lines=["71 16 179:53 / /media rw,relatime - ext4 /dev/mmcblk0p53 rw,data=ordered"]
    opts=f"rw,lowerdir={low},upperdir={app},workdir=/media/squashfs/work/com.apple.appletv"
    for i,p in enumerate((app,jail)):
        lines.append(f"{338+i} 71 0:46 / {p} rw,relatime - overlay overlay {opts}")
    for i,n in enumerate(("main","app")):
        lines.append(f"{440+i} 339 179:52 {old}/candidate-{n}.js {jail}/res/{n}.js rw - ext4 /dev/mmcblk0p52 rw")
    (lab/"mountinfo").write_text("\n".join(lines)+"\n")
    (lab/"binds").write_text("")

def hashes(lab):
    return [hashlib.sha256((lab/"app/res"/f"{n}.js").read_bytes()).hexdigest() for n in ("main","app")]

ORIGINAL = [hashlib.sha256(DATA[(n, "original")]).hexdigest() for n in ("main", "app")]
CANDIDATE = [hashlib.sha256(DATA[(n, "candidate")]).hexdigest() for n in ("main", "app")]

results=[]
for case in (sys.argv[1:] or ("valid","second-failure","kill-interrupted","term-interrupted","updated-before","updated-after-first","foreign","foreign-directory","running","unverified","backup-corrupt","unknown-byte")):
    with tempfile.TemporaryDirectory(prefix="shell-fixture-",dir=ROOT) as td:
        lab=Path(td);fixture(lab)
        out=run(lab,'prepare\n')
        assert out.returncode==0,(case,"prepare",out.stdout,out.stderr)
        state=lab/"permanent"
        token=(state/"token").read_text().strip()
        (state/"mac-verified").write_text(hashlib.sha256((state/"receipt.sha256").read_bytes()).hexdigest()+"\n")
        if case=="flag-changed":(lab/"old/disabled").write_text("")
        if case=="current-changed":(lab/"old/current").write_text(str(lab/"old/attempt.other"))
        if case=="unverified":(state/"mac-verified").write_text("wrong")
        if case=="backup-corrupt":(state/"original-main.js").write_text("corrupt")
        if case=="running":(lab/"running").write_text("")
        if case=="foreign":(lab/"mountinfo").write_text((lab/"mountinfo").read_text().replace(str(lab/"old/candidate-main.js"),"/foreign",1))
        if case=="foreign-directory":
            with (lab/"mountinfo").open("a") as stream:stream.write(f"999 338 0:9 / {lab}/app/res rw - tmpfs tmpfs rw\n")
        if case=="updated-before":(lab/"new-version").write_text("")
        if case=="unknown-byte":(lab/"app/res/app.js").write_text("unknown")
        for name,marker in (("second-failure","fail-second"),("kill-interrupted","kill-first"),("term-interrupted","term-first"),("updated-after-first","update-first")):
            if case==name:(lab/marker).write_text("")
        out=run(lab,f'TOKEN={token};apply\n')
        if case=="valid":
            assert out.returncode==0,(case,out.stdout,out.stderr)
            assert hashes(lab)==CANDIDATE,(case,hashes(lab),out.stderr)
            restored=run(lab,f'TOKEN={token};receipt_ready;lock_transaction;rollback_core\n')
            assert restored.returncode==0,(case,"rollback",restored.stdout,restored.stderr)
            assert hashes(lab)==ORIGINAL
        elif case=="kill-interrupted":
            assert out.returncode==-9,(case,out.returncode,out.stderr)
            assert hashes(lab)==[CANDIDATE[0],ORIGINAL[1]]
            restored=run(lab,f'TOKEN={token};receipt_ready;lock_transaction;rollback_core\n')
            assert restored.returncode==0,(case,"rollback",restored.stdout,restored.stderr)
            assert hashes(lab)==ORIGINAL
        elif case=="updated-after-first":
            assert out.returncode!=0
            assert hashes(lab)==[CANDIDATE[0],ORIGINAL[1]],(case,hashes(lab),out.stderr)
            assert "E_AUTO_ROLLBACK_PENDING" in out.stderr
        else:
            assert out.returncode!=0,(case,out.stdout,out.stderr)
            if case not in ("unknown-byte",):assert hashes(lab)==ORIGINAL,(case,hashes(lab),out.stderr)
        if case in ("second-failure","term-interrupted","kill-interrupted","valid"):
            assert not list((lab/"app/res").glob(".apple-permanent-*")),case
        if case in ("running","unverified","backup-corrupt","updated-before","foreign","foreign-directory","unknown-byte","flag-changed","current-changed"):
            assert not (lab/"worker-calls").exists(),(case,"worker side effect before refusal")
        results.append({"case":case,"pass":True,"exit":out.returncode})
        print(json.dumps(results[-1]), flush=True)
print(json.dumps(results,indent=2))
