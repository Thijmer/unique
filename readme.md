# Unique
Filter out duplicate lines from an input, printing only the first occurence of each line.
Written completely in x86-64 assembly, without using the C standard library!
(so it does basically the same as `sort | uniq`, but without sorting and a little bit faster)

Under the hood, it's just a very simple separate-chaining, non-resizing hash table.

# Usage
```
Usage: unique [INPUT FILE] [OUTPUT FILE]
Filter out duplicate lines from the input, printing only the first occurence of each line.

With no output file, output is written to standard output.
With no input file, input is taken from standard input.

Examples:
  unique                Reads lines from standard input until an EOF, printing every line the first time it occurs.
  unique a.txt          Reads lines from a.txt, printing out unique lines in the order in which they first occur.
  unique a.txt b.txt    Reads lines from a.txt, writing out unique lines to b.txt in the order in which they first occur.

Written by Thijmen Voskuilen
```

# Why
I wanted to really understand how computer software works at the lowest level,
and programming in Assembly is part of that. This is also why I decided against
using the standard library for this project.
I'm still learning, so if you see ways to improve it, please let me know!

# License
I don't mind if you take this code and expand on it,
but I would like to see what you make and be able to use your modifications if I like them.
Because of this, I decided to license it under GPLv3.
See the `license.txt` file also included in this repo for the terms of this license.
