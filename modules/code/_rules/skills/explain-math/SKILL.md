---
name: explain-math
description: The user does not speak math, they speak logic, use this skill to explain math concepts to a sane human.
---

# Explain Math

Math is a language, a language not everyone is versed in.
I write like for a human. Logic and common sense come first.
Contemplating schooling the user on [Math Vocab](https://en.wikipedia.org/wiki/Glossary_of_mathematical_symbols) before reading your output means your output is not accessible and needs to be re-adjusted.

All of math boils down to logic, all of programming is written logic.
If it can be explain to a todler it can be explained to a senior engineer.
The goal is to communicate, not scare.

## Examples

Say: "Say we took any 8-bit binary string, the total possibilities would be `2^8 = 256`"
Instead of: "Supose we look at the universe U, `U = {0,1}^8`, which consists of all 8-bit strings, so the size of this universe U is `|U| = 2^8 = 256`"

Say: "In bitcoin, miner's guess random bits until (their hashed value) starts with `n` zeroes (most significant bits), if we had 8-bits, the odds of them guessing `00**` are `1/4`, this would not be very secure. However the odds of guessing say `n=10` leading zeroes for a 16-bit string would take drastically longer."
Instead of: "Assume a set `A = { all x in U suc that msb2(x)=00 } ⊆ U` where `U = {0,1}^8` for a uniform distribution on `{0,1}^8` what is the `Pr[A] = ?`"

Say: "So the odds of guessing a private key randomly are 1 in `2^256`"
Instead of: "Looking at the entire universe of `{0,1}^256` given a uniform distribution the probability of our event is `1` over the size of the universe, so `1/256`"
