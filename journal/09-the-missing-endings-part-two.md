# 09 · The missing endings, part two

*October 15, 2026*

Leak Flow started dropping words again. Endings, mostly, and the words
it did keep weren't always the ones I said. I thought
[entry 06](06-the-missing-endings.md) had put this to bed. It had not.

## First I blamed the mic

The log line from entry 04 showed short recordings coming back with
almost nothing:

```text
recorded 3.2 seconds, got 0 words
recorded 5.9 seconds, got 0 words
```

My mic is a little USB one, and its input was already at 100%, so a
too-quiet mic sounded right. Then I opened Wispr Flow, talked into the
same mic, and it got every word. So much for that theory.

## Then I took my voice out of it

To find out whether the problem was me or the app, I needed audio with
nothing wrong with it. The Mac's `say` voice is perfect for that: clear,
steady, and it never mumbles. I had it read a sentence and ran that
straight through `WhisperTranscriber` with the Small English model, same
as the app does.

```text
what it said:  ...and they've done a great job.
what I got:    ...and they've done
```

"A great job", gone. Every time I ran it. Clean audio, a fresh model,
the full 30-second window from entry 06 still on. So this wasn't the old
bug coming back. It was a second one that had been hiding behind it.

## Why the end goes missing

`say` stops the moment the last word ends. No breath, no pause. And
that's exactly what my recordings look like when I let go of the key
right as I finish talking, which, with tap-to-stop, is most of the time.

My best guess at why: Whisper learned from recordings where speech
fades out into a pause. When the sound cuts off right on the last word,
it decides that word isn't finished yet and leaves it out. It's like
someone hanging up the phone on your last word: the other person waits
for the rest of the sentence instead of writing that word down.

## The fix: half a second of quiet

Before Whisper reads a recording, Leak Flow now adds half a second of
silence to the end of it. That gives the last word room to finish.

I tried it on the same clip:

| End of the clip | What came back |
|---|---|
| Nothing added | ...and they've done |
| Half a second of quiet | ...and they've done a great job. |
| A full second of quiet | ...and they've done a great job. |

Half a second was enough, so that's what went in. It's 8,000 more
samples (16,000 is one second), which is nothing next to the 30-second
window Whisper reads anyway. All 74 tests still pass.

## What I learned

- The same symptom can have two causes. Entry 06 fixed one and even
  said it was only proven on one recording. That sentence aged well.
- Take the mic out of it before blaming the mic. A `say` clip answers
  "is it the audio or the app?" in about a minute.

## What's next

- Dictate for a day with my own voice and see if the wrong words go
  away too. A cut-off word can come out as a different word, so some of
  them might, but I've only proven the missing endings so far.
- Teach it `whisper flow -> Wispr Flow` under Fixes. It keeps hearing
  the other app's name as a sentence about whispering.
