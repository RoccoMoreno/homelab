# OverTheWire Bandit

## Level 0 → 1
Password was in a file called `readme` in the home directory.
`ls` to see it, `cat readme` to read it.

## Level 1 → 2
Password was in file '-' in the home directory, because '-' is a known to most
Unix tools to use as a standard input, I had to make sure to make it known that
I wanted a pathway to '-' instead, so I used './' so make it known.

## Level 2 -> 3
The filename had both leading dashes and internal spaces. Quotes stop the shell
splitting on space. -- stops cat reading the dashes as options.

## Level 3 -> 4
Password was in a subdirectory. cd inhere to move in, ls -la to list contents,
cat to read.

## Level 4 -> 5 
Password was in subdirectory again, cd inhere to move in,ls -la to list the
the name and contents, file -- * to identify what kind of file each one is 
without printing contents. Nine came back "data" (binary),
one came back ASCII text — that's the one to read.
cat -- '-file07' for the password.
-- was needed twice: * expanded to names starting with dashes,
and both file and cat read leading dashes as their own options. 

## Level 5 -> 6
File was somewhere in 20 subdirectories under inhere. file * only looks one
level deep — it just reported "directory" 20 times. find walks the whole tree,
so find -size 1033c located it: ./maybehere07/.file2. The c suffix means
bytes; default unit is 512-byte blocks. File was hidden (leading dot),
so plain ls wouldn't have shown it either.

## Level  6 -> 7
Password was somewhere on the server, not in home directory.
find with / as the starting path searches from root of the system.
find / -user bandit7 -group bandit6 -size 33c gives us the file, cat it to reveal the password to the next level. Using 3 of the criterias narrowed it
down to 1 choice. Also instead of searching through hundreds of Permission
denied lines, push them ti stderr a seperate output channel adding 2>/dev/null
at the end of the find command discards them.
 
## Level 7 -> 8 
Password was in data.txt, thousands of lines long, on the line containing the
word millionth. cat would just scroll past it.
grep millionth data.txt — pattern first, then the file. grep prints whole
 matching lines, so "next to the word" needs no special flag.
Typo'd the pattern first try and grep returned nothing silently — no error.
 Empty output means no match, and it can't tell you whether the pattern or the
data is at fault.
