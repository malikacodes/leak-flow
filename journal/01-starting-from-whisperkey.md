# 01 · Starting from WhisperKey

*September 28, 2026*

**What I wanted:** a Mac app where I hold a key, talk, let go, and my
words show up wherever I was typing. No account, no cloud, nothing leaving
my computer. Like dictation, but it works in every app and my voice
never goes anywhere.

## Not starting from zero

I didn't build this from scratch. I started from
[WhisperKey](https://github.com/mark-software/WhisperKey) by Mark Miller,
which already did the hard part. It's shared under the MIT license, which
means I'm allowed to copy it, change it and make it mine, as long as his
copyright notice stays in the `LICENSE` file. It does.

Then I renamed everything. WhisperKey became **Leak Flow** on screen and
`LeakFlow` in the code, with the bundle ID `com.malikapixels.leakflow` (a
bundle ID is the app's unique name tag, the way macOS tells it apart from
every other app). The folder on my Mac is still called `whisperkey`.
Only the app changed its name.

I also gave it a fresh git history, so the first commit is mine:
`Leak Flow: talk instead of type, all on your own Mac (started from
WhisperKey by Mark Miller)`. The credit is right there in the title.

## How it works

Four parts, each with one job:

```text
hold key → HotkeyManager → AudioRecorder → WhisperTranscriber → TextOutputManager → words appear
```

- **HotkeyManager** notices the key going down and coming back up, in any app.
- **AudioRecorder** records my voice in the format the speech model wants.
- **WhisperTranscriber** turns the recording into text, on my Mac, using
  whisper.cpp.
- **TextOutputManager** copies the text and pastes it where my cursor is.

It's basically a relay race where the baton is my voice.

## Keeping the original close (but not too close)

I kept Mark's project as a second remote called `upstream`, so I can see
what changes over there. But it's fetch only: pushing to it is turned
off, so none of my pink experiments can end up in his project by accident.

```bash
# on the MAC, inside the whisperkey folder
git remote -v                         # lists both remotes: origin (mine) and upstream (Mark's)
git fetch upstream                    # look at what's new in the original, without changing my code
git remote set-url --push upstream no_push   # one way to make pushing to upstream fail on purpose
```

> Heads up: `origin` is my private repo on GitHub. `upstream` is his.
> Read which one a command is talking to before pressing Enter.

## The build check

The repo came with a GitHub Actions check (a robot on GitHub that builds
the app and runs the tests every time I push). The first run, on my very
first push, passed: build and tests both green. 🎉

Three minutes later I changed it to only run when I start it myself, from
the Actions tab (**CI → Run workflow**). Building a Mac app uses up GitHub
minutes fast, and I don't need it on every push. So the robot's full-time
job lasted three minutes.

## Still to do on my Mac

To build locally I pointed `xcode-select` at Xcode and accepted the
license. One step was still left:

```bash
# on the MAC
sudo xcodebuild -runFirstLaunch   # lets Xcode finish installing the extra pieces it needs the first time
```

## What I learned

- Starting from someone's MIT project is allowed and normal. Keep their
  notice in the license, and say thank you in the README.
- A remote can be fetch only. That's a small safety switch worth having.
- Automatic checks cost minutes. Run them when they're useful, not out of
  habit.
