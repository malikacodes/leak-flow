# 03 · The pearl that wouldn't ripple, and version 1.1

*September 28, 2026*

The last stretch of the night: a README that matches the app, a recording
dot that turned into a pearl, a ripple that refused to show up, and
version 1.1 at 8:41 PM.

## 7:27 PM · The README was still talking about WhisperKey

The old screenshots literally still said WhisperKey. New screenshots show
the pink glass dot and the Settings tabs as they are now.

I also added the signing lesson from
[entry 02](02-pink-and-a-working-mic.md): if you build Leak Flow yourself,
pick **your own** Apple account under **Signing & Capabilities → Team**
(the project is set to mine, which you won't have). Then the Microphone
and Accessibility permissions stick after the first time.

And the Privacy section now says out loud that the **text** of the last 5
recordings is saved on the Mac. The audio never is.

## 8:21 PM · The dot becomes a pearl

I wanted the dot to feel like Apple's liquid glass: sleek, see-through, a
little shiny. It became a 14-point pearl in blush `#EFD3CF` and rose
`#9C4A63`, with a frosted blur behind it and three pearl shades on top
(a near-white for where light hits, a cream-pink middle, a dusty pink
bottom edge). It breathes slowly while I talk.

It was also supposed to send out a ripple, like dropping a pebble in water.
Sixteen minutes later I was committing a fix called "Make the pearl's
ripple actually show", which tells you how that went.

## 8:37 PM · Why the ripple never rippled

Three problems, all in `RecordingIndicator.swift`:

**The ripple was borrowing the breathing's timing.** One timer was trying
to drive two different movements, a slow breath in and out and a ring
that spreads and fades. Sharing meant the ring never actually spread out.
Now the ripple has its own view and its own timing. It grows to 1.8 times
the pearl and fades away.

**The screen edge was cutting it off.** The window sat flush against the
left edge of the screen, so the ring got clipped. Now the pearl sits 12
points in from the edge, which is enough room for the whole ring at its
biggest (about 13 points out from the pearl's middle).

**The glow left a faint square.** A blur needs room to fade out. In a
tight box it gets trimmed and leaves a square edge around a round pearl.
The window went from 36 to 56 points, and the glow's box got bigger too.

I also rewrote the comments in that file in plain English. Before, they
said things like "silky champagne-blush nacre". Now they say "a soft
cream-pink, for the middle of the pearl". Future me will thank me.

## 8:39 PM · The README gets the real pearl

A new `recording-dot.png`, ripple and all.

## 8:41 PM · Version 1.1

- The version number now lives in **one place**, `MARKETING_VERSION` in the
  Xcode project. The Status tab in Settings reads it from the app itself,
  so it can't fall out of date after a version bump.
- The README got a short **Why it's cute 🫧** section under the pearl.
- The full story is in the 1.1 release notes on GitHub.

The cute section is where the pink from [entry 02](02-pink-and-a-working-mic.md)
finally got its full explanation, pearl and all.

Nine commits, 5:13 PM to 8:41 PM. One evening, start to cute.

## What I learned

- Two animations that move differently need their own timing. Sharing one
  clock made one of them disappear.
- Leave room around anything blurry or glowing, or the box shows.
- Write the version number down once, and have everything else read it.

## What's next

I'm keeping a list of ideas to send back to WhisperKey, since that's where
this all started. My own fork of it,
[malikacodes/WhisperKey](https://github.com/malikacodes/WhisperKey), is
where those will go.
