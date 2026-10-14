# 08 · Crickets chirping

*October 14, 2026*

A silent recording could get pasted as the words `[BLANK_AUDIO]`. Not a
blank, the actual text, square brackets and all, and then saved in my last
5 recordings like it was something I said.

## How it got through

Leak Flow already skipped a recording when Whisper gave back nothing. The
problem is that Whisper almost never gives back nothing. In
[entry 04](04-the-app-that-only-heard-you.md) it was "you". This time it
was a label.

Whisper learned to listen from subtitles, so when there are no words it
does what subtitles do and describes the room. I fed the Small English
model a few kinds of nothing to see what it would say:

| What I gave it | What it wrote |
|---|---|
| 3 seconds of silence | `[BLANK_AUDIO]` |
| 10 seconds of silence | `[BLANK_AUDIO]` |
| A very faint hiss | `(crickets chirping)` |
| A steady beep | `(electronic beeping)` |
| The Mac's `say` voice, then 10 seconds of silence | Just the sentence |

There are no crickets in my apartment. I checked. 🦗

None of these come from whisper.cpp itself. I looked: there's no list of
labels in it anywhere. They're plain words the model chose, which is why
the app has to catch them.

## The fix

One small filter in the recording pipeline, right before anything gets
pasted:

- **Square brackets go wherever they are.** Whisper only uses them for
  these labels, and I never dictate brackets.
- **Parentheses only go when they're the whole result.** They can be real
  punctuation, so `The notes (see below) are done.` stays as it is.

If what's left is empty, nothing gets pasted, copied or saved.

whisper.cpp does have a switch for this (`suppress_nst`, "suppress
non-speech tokens"). I left it off. It works by banning the characters
these labels start with, and that list includes quotes, colons and
parentheses, which I actually use when I talk to my computer.

## Did it work?

I ran the real model through the pipeline with three clips:

```text
silence3: pasted 0 times
noise: pasted 0 times
speech+silence: pasted 1 times <Okay, this is a quick test of the talk key.>
```

Silence and hiss paste nothing now, and real talking still comes through.

## What I learned

- "Nothing" is never empty with Whisper. It's "you", a label, or crickets.
- Check the library before blaming it. The labels came from the model, so
  no setting in whisper.cpp was going to fix them cleanly.

## What's next

- The "you" from entry 04 still gets through. I can't filter that one,
  since "you" is also a real word. That still needs a real silence check
  on the audio itself.
