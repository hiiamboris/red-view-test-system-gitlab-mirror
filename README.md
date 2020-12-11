# red-view-test-system

Test system for [Red language](https://www.red-lang.org/)'s [View subsystem](https://doc.red-lang.org/en/view.html). Just 'the system' from now on.

[**See the improvements timeline**](timeline.md)

## Features and their status

### UI

It won't do any good to just run tests and log their output somewhere. What's equally important is to be able to effortlessly notice any deviations in the tests.

For this reason, I made a UI called 'Perspective', that is able to compile, run everything and compare sets of results to each other - so we can notice regressions and improvements of each particular build.

It's almost complete. Need to add a side-by-side comparison for nitpicky testing and include manual tests into test routine. Needs score display.

*Goal: provide one-click solutions to most testing tasks; focus on extracting and highlighting the features that we're interested in. It should also be self-explanatory and not require any documentation*

### Core

Most basic analysis features are implemented, should be enough to cover \~80% of the issues. Improvement and extension may require more sophisticated algorithms: image to image comparison, text vs image comparison, etc. RedCV could be leveraged for that if required. In any case these extensions should come from a practical need, so let's wait for it to arise.

Parallel compilation and testing is finished.

Input emulation can do only mouse & keyboard right now, no touch input (W7 has no touch input support AFAIK).

*Goal: stay adequately simple but try to cover as much aspects of View as possible*

### Cross-platform support

Only Windows yet. Any volunteers to port it??

*Goal: support of at least Mac and GTK*

### Issues regression tests

A set of 115 issues implemented. Hundreds more to come.

*Goal: theoretically, \~95% of the historically raised View issues may be tested using this system*

### Custom tests

A few tests in an experimental state so far.

*Goal: have a set of extensive stress tests where it's applicable*

### Stability & automated testing

- Tester thread is able to restart workers when those crash/freeze.
- Some of Red's heisenbugs crash the tester thread sometimes, but I got 1-click crash recovery (just click "Load previous" button). You may have to manually kill child `console-..` processes after it crashes.
- Compilation and testing is fully automated.

*Goal: make the system fault tolerant - being able to recover from crashes, kill runaway & forgotten processes, run failing tests multiple times, and otherwise minimize the requirement for user interaction...*

### Nitpicky testing

Implemented. Improvements in comparison UI are still wanted, but since View is rather buggy, it has to wait, or the stability of the whole test system will be at stake.

*Goal: when run twice on the same system - detect the slightest of changes in tests output, warn the user and present an overview for analysis*

### Setup

It requires some mezzanines to work, so a bit of setup is required for now:
- `git clone https://gitlab.com/hiiamboris/red-view-test-system` - this clones the test system itself
- `git clone https://gitlab.com/hiiamboris/red-mezz-warehouse red-view-test-system/common` - clones the mezzaninse
- `cd red-view-test-system & run-w32.bat` - runs the console prebuilt by me for Windows

You can compile this console yourself:
- `git clone https://github.com/hiiamboris/red/tree/view-test-system` - this clones Red version that contains all the necessary patches
- `cd view-test-system` (directory just created)
- `git clone https://gitlab.com/hiiamboris/red-view-test-system` - this clones the test system itself
- `cd red-view-test-system` (subdirectory just created)
- `git clone https://gitlab.com/hiiamboris/red-mezz-warehouse common` - this clones mezz warehouse that contains some required functionality
- `cd ..` get back to Red source tree
- build it: `rebol --do "do/args %red.r {-r -d -o red-view-test-system\view-test-console.exe environment/console/GUI/gui-console.red}"`
- use `run-w32.bat` in `red-view-test-system` to run the GUI, or make your own runner to run it based on this example

By default it uses `red --cli` command for the worker. To test a custom built console, you can edit `config.red` and change `command-to-test` setting (use full path in OS format). 

*Goal: add UI settings to config file, maybe more self-checks on run*

### Documentation

Requires porting guide, user's guide.

## Philosophy & Architecture

### Rationale

- In my opinion View subsystem has long crossed the point where every minor change may bring about a set of regressions, thus became hard to maintain or refactor. It requires a tool to detect such regressions promptly and automatically.
- There's no metric other than number of issues on Github that may compare the status of View support of each major platform (or even it's version, like W7 vs W8+). We usually do not know what will work here or there. This largely hinders portability of visual applications and requires a lot of effort and VM testing to achieve it for each particular app ('diagrammar' being a great but not the only illustration of this point: I opened ~60 new issues during table style experiments).

### Scope

View test system is meant not to replace, but to be used along the [test backend](https://github.com/red/red/tree/master/modules/view/backends/test), which is perfect for some tasks and completely unacceptable for others.
It is also not a stress testing system (like Monkey), but such system may one day be implemented on top of it.

Main point for now is to be able to run View regression tests *with little to no user interaction.*

Previous experiments on automated testing have shown the limitations of Github CI/CD usage:
- Choice of OS. E.g. many bugs may appear on W7 only and cannot be tested by GH.
- OS settings. E.g. some issues may only be detected with scaling different than 100%, but GH provides only the default setting.
- Lack of interactivity. View tests are much more complex than traditional assertion tests and require an UI to overview each test result to understand it. I find it unlikely that GH can adequately provide it.
- Time span. There are certain limitations to how fast View tests can be run. E.g. Red window may require all the lower windows to finish drawing before it can redraw itself, thus requiring synchronization with the OS and other programs; single/double click event distinction; a lot of issues will require compilation in release mode; some issues will hang and require a timeout. Some of the image analysis functions are time consuming too.

In this light, the system is meant to be run in user space. It's okay for it to be slow and even take an hour for a full run, as long as no user interaction is required during the run.

### Success score

Traditional test system hunts for every single deviation of expression result. It does not allow a single failure.

With View subsystem being always in development, it is sane to adopt a different strategy.
The system allows any number of tests to fail and is only concerned with the overall success score for each platform.
It should be able to highlight regressions and forgive tests that never succeeded, thus even allowing to write tests for the future.

A success score constitutes the number of successful condition checks (thus it is not advisable to remove checks). Manual tests will probably have some weight coefficient.

### Nitpicky testing

It should be obvious that the cross-platform and cross-user reproducibility of test results is much lower than on the same machine and same OS. If we only apply (quite forgiving) cross-platform success criteria, we risk a lot of minor changes (possible regressions) on a single platform to go unnoticed.

So, together with the success score, the system detects slightest deviations in test results between consecutive test runs and highlights that. Deviations like the loss of font anti-alias or a shift by one pixel.

Future: Ideally I want it to evolve from side-by-side comparison of 2 result sets into a timeline-aware analysis tool where it will be able to pinpoint an exact commit where a regression (or improvement) happened.

### Manual tests

Some tests can be written extensively, like: click all combinations of all mouse buttons (e.g. lmb+rmb+mmb...) with all combinations of modifiers (shift, control...) on faces of all types and check all produced events properties. These will cover a lot of ground not available to per-issue tests and even make some of them unnecessary.

### How it works

Key things to understand:

#### 1. There is a 'clicker' process and there are one or more 'worker' processes.

I call it 'clicker' because it's able to simulate clicks ;) But also any other input. It is the central process that runs and manages workers. Workers' role is to run tests code, clicker's role is to oversee that and analyze the outputs.

One worker (called `main-worker`) process runs the majority of the tests code. The other ones are only started when it's necessary to compile something.

#### 2. There are two consoles (or more generally Red builds)!

One console runs the workers. Is the one the system is testing: it should better stay unmodified.

Another console runs the clicker and allows it to do it's magick. It is heavily modified: it includes input simulation, image analysis routines (may even include RedCV one day), and it is required to be as stable as possible.

#### Some reasons for this design:

- Eliminate the test system environment influence on test results. Both may run View code and should not affect each other's event processing pipeline.
- Bugs in clicker console should not be taken for bugs in test console, and bugs in test console should not stop clicker from working or even interrupt it.
- Parallelize compilation, as it will only slow down during foreseeable future.

