# 02 · Pink, faster, and a microphone that actually works

*September 28, 2026*

**What happened:** an hour after the first push, I started making Leak
Flow look like mine. Somewhere in there I also found out the microphone
wasn't working, which is a big deal for an app whose whole job is
listening.

## Round one: pink (6:12 PM)

- The menu bar icon became a pink dot that pulses while it's recording.
- The recording indicator became a deep rose pill standing up on the
  left edge of the screen.
- The menu now keeps my **last 5 recordings** with their times. Click one
  and it's copied again. That lives in a new file, `TranscriptHistory.swift`,
  which only ever keeps the newest five and drops the rest.

The why behind the pink is in the README, in my own words: so much of tech
feels male coded, and I look at this thing every time I talk to my
computer.

## The permission that kept turning itself off

Leak Flow needs **Accessibility** permission to notice my key from any
app and to paste for me. Every time I rebuilt, macOS acted like it had
never met the app before.

The reason: macOS remembers permissions by **who signed the app** (signing
is the app's ID badge that says who built it). Debug builds were signed
with a throwaway, anonymous signature, so every rebuild looked like a
stranger. I set debug builds to sign with my Apple account, and now the
permission stays on.

## Round two: the microphone (6:55 PM)

This commit is called "the microphone actually works", so yes, before
this, it didn't.

The fix was one setting in `LeakFlow.entitlements` (a list of things the
app is asking macOS permission to do):

```xml
<key>com.apple.security.device.audio-input</key>
<true/>
```

The file already had a microphone line. It needed this one too, or macOS
won't let the app use the microphone. A voice app with no ears.

## Making it fast

Same commit, three speed changes in `WhisperTranscriber.swift`.

**1. Only read what I said.** Whisper (the speech model) was built to
listen in 30-second chunks. If I talk for 5 seconds, it pads the rest with
silence and still reads all 30. That's like reading a whole page when
only the first line has writing on it. Now it stops at the end of what I
said:

```text
16,000 samples = 1 second of audio
the model reads 50 steps per second (30 seconds = 1,500 steps)
4-second recording → 200 steps, plus 128 extra so the last word never gets cut off
```

**2. Flash attention.** A faster way for the graphics chip to do the
model's heaviest math. Same result, less work. The trimming only runs
when flash attention is on, because without it the graphics chip crashes
on some recording lengths.

Together that's about 2 to 4 times faster on the Small English model.
About 7 seconds of talking turns into text in under a second on an M1 Mac.

**3. A warm-up.** The very first time the graphics chip runs the model it
has to get set up, like a car on a cold morning, so the first recording
was slow. Now the app quietly runs the model on one second of silence as
soon as it opens, and I never feel that delay.

## Also in this round

- The pill became a small pink **glass dot**.
- The menu bar dot became the deeper rose, so it shows up on a light
  menu bar.

## What I learned

- macOS ties permissions to the signature. Anonymous rebuilds start over
  every time.
- Entitlements are picky. One microphone line wasn't enough, it needed
  the `audio-input` one as well.
- Whisper reads 30 seconds no matter what, unless you tell it not to.
