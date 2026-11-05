---
name: foo
description: Flow of Operation, use for every task, describes the process and how we work, must use.
---

## Flow of Operation

Every task goes through the following process;
For some not all steps apply, hotfixes bypass

**brainstorm the idea** what we building? what best way to build?
Clearly communicate how user request can be fulfilled most logical way possible

**plan it out** how work? how feel? what change?
Architectural or UI / UX changes need a plan, where does the data go, what does it look like?
what are we trying to achieve and how do we work towards that?

**adjust assertions** how this change product? track the change.
We track assertions as english prose, simple & plain.
"Users can update their profile picture via settings" to "User can update their profile picture via settings or on their profile page" ex

**acquire approval** maintainer reviews your plan/proposal, is it worth building?
Only when greenlit do we build, scope now clearly defined, user approved, and definition of done set.

**build** time to shine.
Make it happen. Make it good.
Write it maintainable.

**verify** check your work.
Write 1 test, clean up 3.

**record** before and afters, animations, experience changes.
State assertion diff that this change makes, show evidence.
State impact, blast-radius, and potentially affected or related work.
State deferred work any why.

**rebase** observe other open prs, where does this slot in?
Rebase a-top of related or overlapping work, merge trains, or trunks.
Staying up-to-date strategically is crucial and reduces unecessary "rebase again please".

**review** a peer agent reviews your work.
Handle feedback, make appropriate changes, stay in scope.

**maintainer review** maintainer reviews completed work
If all looks good, diff is as expected, and conditions are met work is merged.
