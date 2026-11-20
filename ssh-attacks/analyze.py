import glob
import gzip
import re

import pandas as pd

# Pull the timestamp, username, and IP out of each "Invalid user" line
pattern = re.compile(r"^(\S+) \S+ sshd\[\d+\]: Invalid user (\S*) from (\S+) port")

rows = []
for path in glob.glob("ssh-attacks/logs/auth.log*"):
    opener = gzip.open if path.endswith(".gz") else open
    with opener(path, "rt") as f:
        for line in f:
            match = pattern.search(line)
            if match:
                rows.append(match.groups())

df = pd.DataFrame(rows, columns=["time", "user", "ip"])
df["time"] = pd.to_datetime(df["time"])

print("Total attempts:", len(df))
print(df.head())
print(df["user"].value_counts().head(10))
print(df["ip"].value_counts().head(10))
print("Unique IPs:", df["ip"].nunique())
print(df.groupby(df["time"].dt.date).size())
