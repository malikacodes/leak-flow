# 06 · The missing endings

*October 13, 2026*

Writing this one late. The fix went in on October 8, the same day as
[entry 04](04-the-app-that-only-heard-you.md), and never got its story.
It's also the day I took back a speed-up from the first evening.

## What I saw

After fixing three ways Leak Flow could lose words, it was still losing
some. Not whole sentences this time. Just the ending:

```text
what I said:   ...gonna pull up the next app
what I got:    ...chrome browsers going to pull
```

That recording was 12.5 seconds long. The one right before it was 18.2
seconds.

## I blamed the wrong thing first

In [entry 02](02-pink-and-a-working-mic.md) I made Whisper faster by
shrinking its 30-second window to the length of what I said. That was my
first suspect, so I played recordings back through it, one at a time.
Every one came back whole. Trim cleared. Case closed.

Except Leak Flow doesn't run recordings one at a time on a fresh model.
It loads the model once and keeps it, and the window size was changing
with every recording. So I played them back the way the app really does
it:

| How I replayed the 12.5 second recording | What came back |
|---|---|
| Alone, on a fresh model | All of it |
| After the 18.2 second one, same loaded model, trim on | Ending cut off |
| After the 18.2 second one, same loaded model, trim off | All of it |

So it was the trim after all. I'd tested it in a way the app never
actually runs.

## The fix

The trim is gone. Whisper reads its full 30 seconds every time, which is
what it was built to do.

> Heads up: I proved this on one recording, and I still don't know *why*
> a longer recording leaves something behind for the next one. I know
> what stops it, not what causes it.

## What it cost

Almost nothing. Timed today
on my M1 with the Small English model and the Mac's `say` voice reading
to it, five runs each:

| How long the voice talked | How long the words took |
|---|---|
| 1.5 seconds | 0.5 seconds |
| 6.7 seconds | 0.75 seconds |
| 24.7 seconds | 1.55 seconds |

The README says about 7 seconds of talking turns into text in under a
second. Still true, so that line stays. The other two speed-ups from
entry 02 (flash attention and the warm-up) are still on.

## The recordings I kept

To replay anything I needed the audio, and Leak Flow's whole promise is
that audio is never saved. So for a few days my own test build quietly
kept the last 10 recordings in a cache folder. That code never went into
a commit. Today I took it out, deleted the files, and rebuilt the app.

It also had a bug. The files were named by time of day with no date, so
"keep the newest 10" was really "keep the 10 latest clock times". A fair
reminder that temporary code doesn't get the same care, and shouldn't get
to stay.

## What I learned

- Test it the way the app runs it. One recording on a fresh model isn't
  how Leak Flow works.
- A third of a second wasn't worth a single lost word.
- Temporary means it has a day it comes out. This one overstayed.
