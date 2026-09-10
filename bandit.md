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
