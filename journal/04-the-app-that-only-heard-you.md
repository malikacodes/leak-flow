# 04 · The app that only heard "you"

*October 8, 2026*

Leak Flow had been dropping words on me. I'd hold the key, say a whole
paragraph, and get back a sentence. Sometimes less. This is the morning I
finally went looking for where the rest of it was going.

> Is this a bug, or has it always been able to do this?

Both. It's a bug, and it's been there since the first commit.

## Three suspects

Reading the code, I found three places where the app could lose speech
while still looking like it was recording:

1. **Whisper quitting early.** I had timestamps turned off. Timestamps
   are Whisper's bookmark, how it knows how far into its 30-second window
   it has read. Without them, if it decides I'm done after a pause, it
   skips the rest of the window.
2. **The pearl lying.** If I pressed the key while the last recording was
   still being transcribed, the app showed the pearl, played the sound,
   and recorded nothing.
3. **The sound setup changing mid-recording.** No proof yet, so I parked
   this one.

I fixed 1 and 2, and added a note-taker so I'd stop guessing. One line per
recording, with the seconds and the word count, never the words:

```bash
# on the MAC: read the last hour of Leak Flow's notes
log show --last 1h --predicate 'subsystem == "com.malikapixels.leakflow"'
```

Short seconds means the recording itself stopped early. Plenty of seconds
and few words means Whisper dropped them.

## Then it got worse

Right after, I talked for almost a minute and got this back:

```text
you you
```

That wasn't any of my three suspects. The Mac's own audio log showed the
recording ran the full 58 seconds, from the **MacBook Pro Microphone**. My
laptop lid was closed, and Apple switches that microphone off when the lid
is shut. So Whisper got a minute of silence, and "you" is what it makes
up when it hears nothing. One per 30-second window.

The mic had changed at 9:21:53. I had opened FineTune for the first time
at 9:21:49. It has a "lock input device" setting that starts out switched
on and pointed at the built-in mic, which makes sense on an open laptop.
On mine it was a lock on a dead microphone. Every time I picked the USB
mic in Sound settings, it got flipped back in a tenth of a second. I kept
the lock and pointed it at the USB mic.

So that one wasn't Leak Flow's fault at all. I'd spent the morning
interrogating the wrong app.

## Suspect 3, caught in the act

With the right mic back, it happened again, and this time the note-taker
was running:

```text
recorded 13.6 seconds, got 33 words
```

I had held the key for about 26 seconds. Halfway through, my sound output
hopped to the headphone jack and back, and the Mac's log said this about
the recorder:

```text
iounit configuration changed > stopping the engine
```

macOS stops a recording whenever the sound setup changes, even when it's
the output that changed and not the mic. Leak Flow never noticed. The
pearl kept pulsing over a recording that had already ended.

Now the recorder listens for that change and picks the mic straight back
up, keeping everything it already had. I tested it by talking while
switching between external and internal sound on purpose:

```text
sound setup changed mid-recording, picked the mic back up
recorded 16.1 seconds, got 36 words
```

All 36 words. 🎉

## One more: no space

Each recording gets trimmed down to just its words before it's pasted. So
letting go of the key and talking again glued the two together, like
`working now.Okay`. Every paste now ends with one space. The space only
goes into the paste. The clipboard and the last 5 recordings keep the
clean text.

## Quick scan

| What I saw | What it was | Fix |
|---|---|---|
| A minute of talking became "you you" | Recording from a mic that's off when the lid is closed | Pointed FineTune's input lock at the USB mic |
| Half a recording missing | macOS stopped the engine when the sound output changed | The recorder restarts itself and keeps what it had |
| Two recordings glued together | Trimmed text pasted with nothing after it | A space after every paste |
| Pearl showing, nothing recorded | Key pressed while the last one was still transcribing | The pearl only shows when recording really started |

## What I'm not sure about

Suspects 1 and 2 are fixed in the code, but I haven't caught either one
actually happening. The note-taker will tell me if they do.

## What I learned

- Measure before fixing. I had three guesses and the first real answer was
  none of them.
- A recording can end without anyone pressing stop. Anything that touches
  the sound setup can do it.
- Whisper never says "I heard nothing". It says "you".

## What's next

- A silence check, so a dead mic gets a warning instead of a pasted "you".
- Maybe a mic picker in Settings, so Leak Flow uses the mic I chose no
  matter what the system default is.
