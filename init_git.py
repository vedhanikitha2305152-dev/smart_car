import subprocess
import os

env = os.environ.copy()
env["PATH"] = r"D:\tools\git\cmd;" + env.get("PATH", "")

def run(cmd):
    print("Running:", " ".join(cmd))
    res = subprocess.run(cmd, cwd=r"D:\smart_car", env=env, capture_output=True, text=True)
    if res.stdout:
        print(res.stdout)
    if res.stderr:
        print(res.stderr)
    return res.returncode

# 1. Set local git user if not set
run(["git", "config", "user.name", "Godwin"])
run(["git", "config", "user.email", "godwin@users.noreply.github.com"])

# 2. Add and commit
run(["git", "add", "."])
run(["git", "commit", "-m", "feat: initial commit for Smart Car companion app and Pi server"])

# 3. Branch main
run(["git", "branch", "-M", "main"])

# 4. Check log
run(["git", "log", "-n", "1"])
