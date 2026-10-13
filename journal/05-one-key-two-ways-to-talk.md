# 05 · One key, two ways to talk

*October 8, 2026*

Holding a key is fine for a sentence. For a whole rambling thought, my
finger gets bored before I do. So the afternoon started with one question:

> Does Leak Flow have a button that I can press and let go?

It didn't. It only knew one thing: key down means record, key up means
stop.

## Try 1: a switch in Settings

The first version was a switch under Behavior, "Press once to start, again
to stop". Off meant hold to talk. On meant the key worked like a light
switch.

I went to Settings to turn it on and it wasn't there.

> How do I get the press once feature? I went to behaviors, I didn't see it

Then I decided it had been there all along, because I was looking at
"Play sounds on record start/stop". Different switch. That one only does
the little sounds.

The real reason was simpler. The app in my menu bar was still the old
build. Changing the code doesn't change the app that's already running.
It has to be built again and reopened. (Future me: if a new thing is
missing, check that first.)

## Try 2: I wanted both

Once the switch showed up, I didn't want it. A switch means picking one
way to talk, and I wanted both on the same key.

So the switch came out, and now the key decides by how long it was down:

```text
down less than 0.35 seconds  →  a tap. Keep recording until the next press.
down longer than that        →  a hold. Stop when I let go.
```

About a third of a second is longer than a quick tap and shorter than
holding the key to say even one word. Hold to talk is the walkie-talkie.
Tap is the light switch.

## Then the Stream Deck said no

The whole point of press and let go was a Stream Deck button, and I
couldn't get it on there. My talk key is **Right Command by itself**, and
a Stream Deck hotkey can't be just a Command key. It wants a regular key,
or Command plus something.

I didn't want to give up Right Command on the keyboard. So Leak Flow got
a second talk key, only for the deck: **F20**. My keyboard doesn't have
one, so nothing else will ever press it.

On the Stream Deck: a **Hotkey** action, with F20 picked from the little
dropdown next to the hotkey box.

## It worked, but I had to hold the button

Pushing the deck button started the recording, and letting go stopped it.
The opposite of what I wanted.

At first F20 followed the same tap or hold rule as the keyboard. My guess
is that a deck button stays down longer than a keyboard tap, so my push
counted as a hold. I didn't measure it. Instead F20 stopped caring about
time at all: every push flips the recording on or off, and letting go
means nothing.

Now I push once, talk, push again. 🎉

## Quick scan

| What I saw | What it was | Fix |
|---|---|---|
| New switch missing from Settings | The running app was the old build | Build again and reopen |
| Had to choose tap or hold | One switch, one way to talk | No switch. The key times itself |
| Couldn't put the talk key on the Stream Deck | Right Command alone isn't a hotkey the deck can send | A second key, F20 |
| Had to hold the deck button | Deck pushes were being timed like keyboard taps | F20 is a plain on and off |

## What I'm not sure about

- 0.35 seconds is a first guess that felt right today. If quick words start
  getting stuck on, that number is the one to change.
- Why the deck push counted as a hold. I fixed it without proving it.
- F20 is typed into the code. It isn't in Settings.

## What I learned

- Ask for the thing I actually want. I asked for a switch and wanted no
  switch.
- A button and a key aren't the same thing just because they send the
  same letter.
- New feature not showing up? It's probably the old app still running.
