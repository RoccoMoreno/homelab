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

## Level 8 -> 9
Password was the only line in data.txt appearing exactly once.
grep proved useless because we didn't know any patterns.
| is a pipe: it feeds the left command's output into the right command as input.
uniq only compares adjacent lines, so sort has to run first to group identical
lines together.sort data.txt | uniq -u
The right side of a pipe takes no filename

## Level 9 -> 10
Password in data.txt was binary. grep = data.txt returned binary file matches.
strings data.txt| grep =====, strings pulls the readable text out of the binary file and piping grep filters the clean text macthing the several =.

## Level 10 -> 11
data.txt was base64-encoded text. Running base64 data.txt encodes it
again default direction is encode.
base64 -d data.txt
Base64 is encoding for transport, not encryption. Output grows ~33% when
encoding, shrinks when decoding

## Level 11 -> 12
data.txt was ROT13 — each letter shifted 13 places, wrapping at the end of
the alphabet.
cat data.txt | tr a-zA-Z n-za-mN-ZA-M
tr maps set 1 to set 2 position by position, and reads only from stdin
no filename argument, hence the cat and pipe.
Non-letters pass through untouched.
ROT13 is its own inverse: 13 + 13 = 26, a full lap.

## Level 12 -> 13 
data.txt was a hexdump of a file compressed through ~9 layers. Home directory
is read-only, so: mkdir /tmp/rocco12, cd there, cp ~/data.txt .
xxd -r data.txt > rocco14 reversed the hexdump back to binary. > redirects 
output into a file instead of the screen — needed because binary would 
garble the terminal.
Then a loop: file to identify, decompress, file again. Three tools:
mv x x.gz then gzip -d x.gz
mv x x.bz2 then bzip2 -d x.bz2
tar xf x (no rename needed; extracts to a name stored inside the archive)
zip and bzip2 refuse to run without the right extension. tar doesn't care.
Mistakes: renamed a tar archive to .gz and ran gzip on it after file had 
already told me it was tar. Also ran two commands on one line and gzip treated
the extra words as filenames. 
Read file output before choosing the tool, one command per line.

## Level 13 -> 14 
Home directory held sshkey.private, an RSA private key, instead of a password.
Authenticate with ssh -i <keyfile> bandit14@bandit.labs.overthewire.org -p 2220
— -i specifies the identity file.
Couldn't run it from inside the Bandit server: the hostname resolves 
to 127.0.0.1 from in there, and localhost connections are blocked.
Had to cat the key, paste it into a file on my Mac, and connect from there.
SSH then refused the key: permissions were 0644, meaning group and others
could read it. chmod 600 fixed it. Verbose mode (ssh -v) showed the
server accepting the key and my own client rejecting it — the refusal
was local, protecting me from using a key others could read.
