# red-view-test-system

Test system for [Red language](https://www.red-lang.org/)'s [View subsystem](https://doc.red-lang.org/en/view.html). Just 'the system' from now on.

## Features and their status

### Core

Most basic analysis features are implemented, should be enough to cover \~80% of the issues. Improvement and extension may require more sophisticated algorithms: image to image comparison, text vs image comparison, etc. RedCV could be leveraged for that if required. In any case these extensions should come from a practical need, so let's wait for it to arise.

Parallel compilation and testing is achieved, but could be improved by a lot.

Input emulation can do only mouse & keyboard right now, no touch input (W7 has no touch input support AFAIK).

*Goal: stay simple but try to cover as much aspects of View as possible*

### Cross-platform support

Only Windows yet. Any volunteers to port it??

*Goal: support of at least Mac and GTK*

### Issues regression tests

A set of 32 issues implemented as PoC and design basis. Hundreds more to come.

*Goal: theoretically, \~95% of the historically raised View issues may be tested using this system*

### Custom tests

A few tests in an experimental state so far.

*Goal: have a set of extensive stress tests where it's applicable*

### Stability & automated testing

Tester thread is very silly right now. It is able to restart workers when those crash though. Some of Red's heisenbugs crash the tester thread sometimes. Log review is shown after each test run and requires an approval (temporary measure until the system is stable).

*Goal: make the system fault tolerant - being able to recover from crashes, kill runaway & forgotten processes, run failing tests multiple times, and otherwise minimize the requirement for user interaction...*

### Nitpicky testing

Not implemented yet (requires more stable system), although results logging is more or less there.

*Goal: when run twice on the same system - detect the slightest of changes in tests output, warn the user and present an overview for analysis*

### Setup

Nothing yet. Ask me if you wish to test it. Basically, `jobs.red` contains the path to console used to start a worker, while `testing.red` should be started with the most reliable (and garbage-collected) build.

*Goal: first a config file; later - automated/interactive setup, compilation and self-check*

### Documentation

Requires porting guide, user's guide.


## Philosophy & Architecture

### Rationale

- In my opinion View subsystem has long crossed the point where a minor change may have dramatic set of regressions, thus became hard to maintain or refactor. It requires a tool to detect such regressions promptly and automatically.
- There's no metric other than number of issues on Github that may compare the status of View support of each major platform (or even it's version, like W7 vs W8+). We usually do not know what will work here or there. This largely lowers portability of visual applications and requires a lot of effort and VM testing to achieve it for each particular app ('diagrammar' being a great but not the only showcase of this).

### Scope

View test system is meant not to replace, but to be used along the test backend, which is perfect for some tasks and completely unacceptable for others.
It is also not a stress testing system (like Monkey), but such system may one day be implemented on top of it.

Main point for now is to be able to run View regression tests *with little to no user interaction.*

Previous experiments on automated testing have shown the limitations of Github CI/CD usage:
- Choice of OS. E.g. many bugs may appear on W7 only and cannot be tested by GH.
- OS settings. E.g. some issues may only be detected with scaling different than 100%, but GH provides only the default setting.
- Lack of interactivity. View tests are much more complex than traditional assertion tests and require an UI to overview each test result to understand it. I find it unlikely that GH can provide it.
- Time span. There are certain limitations to how fast View tests can be run. E.g. Red window may require all the lower windows to finish drawing before it can redraw itself, thus requiring synchronization with the OS and other programs. Another point is single/double click event distinction. Plus a lot of issues will require compilation in release mode.

In the light of this, the system is meant to be run in user space. It's okay for it to be slow and even take an hour for a full run, as long as no user interaction is required during this hour.

### Success score

Traditional test system hunts for every single deviation of expression result. It does not allow a single failure.

With View subsystem being always in development, it is sane to adopt a different strategy.
The system allows any number of tests to fail and is only concerned with the overall success score for each platform.
It should be able to highlight regressions and forgive tests that never succeeded, thus even allowing to write tests for the future.

A success score constitutes the number of successful condition checks (thus it is not advisable to remove checks). Manual tests will probably have some weight coefficient.

### Nitpicky testing

Together with the success score, the system (once matures a bit) will provide an option to compare each image captured during a test run with a corresponding image from a previous test run, thus allowing to detect and flag even the tiniest deviations, which can never be reliably covered by the test logic (due to cross-platform differences). Deviations like the loss of font anti-alias or a shift by one pixel.

The system will display such deviations for an overview and approval, so the user may decide if it qualifies as a regression or an improvement.

### Manual tests

Some tests can be written extensively, like: click with all combinations of all mouse buttons (e.g. lmb+rmb+mmb...) with all combinations of modifiers (shift, control...) on all faces and check all produced events properties. These will cover a lot of ground not available to per-issue tests and even make some of them unnecessary.
