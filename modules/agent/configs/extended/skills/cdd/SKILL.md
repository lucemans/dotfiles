---
name: cdd
description: Cleanroom Driven Development, no huge fixtures, no numerous tests, english instead 
---

# Cleanroom Driven Development

The language is english, not 2.5MiB of fixture file
Private data, model names, project names stay out of git

## Testing

At Aperture Science we love testing; but must be done right
Minor ui changes, text adjustment, and such dont need tests, "make sure the tooltip still says 'warning some message here'" doesnt help, making sure "the warning shows up" helps much more.

**Assert instead of Test**
Some behaviour needs assertion; "Codex >v1.2.3 behaves like X and hence and such we do Y" leaves a valuable maintainable assertion in english for future agents to grasp, a test that gets removed next 'optimize tests plz' doesn't
"the syntax highlighter is lazy loaded to optimize performance" instead of a huge test file asserting it does or doesnt exit
Temporary testing for verification of the behaviour before delivering is curcial, but git should remain temp test free

**Fast Testing**
Tests should run fast
Unit and Integration tests for libs
Integration and UI tests for web
All the such, fast, parallelized, the critical stuff

## Fixtures and Seeders

No megabytes of data in git instead record the fixture, analyze findings, improve the seeder, repeat
Model the foreign structure
