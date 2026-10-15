# 07 · Teaching it my words

*October 14, 2026*

Leak Flow kept writing "leak flow" and "stream deck" in lowercase, in an
app literally called Leak Flow. So I went to see how Wispr Flow gets
names right, and came back with a word list.

## Peeking inside Wispr Flow

Wispr Flow is an Electron app (a website dressed up as a Mac app), so
most of how it works is plain JavaScript packed into one archive file,
`Contents/Resources/app.asar`. I unpacked it and searched through the
code.

> Does it run the speech model on my Mac, like Leak Flow does?

No. It streams my voice to its own servers while I'm still talking:

```text
mic → 40 ms slices → squished with Opus → wss://api.wisprflow.ai → text back
```

Along with the audio, it sends a lot of context: my personal dictionary,
"replace this with that" rules, the app I'm in, the text around my
cursor, words it reads off my screen, and even a screenshot. On the
server, one model turns speech into words and a second one rewrites them
before they come back.

Most of that I don't want. Leak Flow's whole promise is that my voice
never leaves the Mac, and it already turns 7 seconds of talking into text
in under a second, so streaming wouldn't buy much. But the dictionary
part? That I could do locally.

## How the hint works

Whisper has a setting called `initial_prompt`. Whatever text goes in
there, Whisper treats as "what was said just before this", and it leans
toward matching it.

It's like telling a friend "it's Malika, with an i" before they take
notes for you.

So My Words is two boxes in a new Settings tab:

- **Words**, one per line. They go to Whisper as a sentence:
  `Malika, Leak Flow, MCIT, Stream Deck.`
- **Fixes**, like `sims four -> Sims 4`. These run on the text after
  Whisper is done, for when the hint isn't enough.

Fixes ignore upper and lower case and only match whole words, so a fix
for "sim" leaves "simulation" alone. The arrow works as `->` or `→`,
because macOS likes to turn one into the other while I type.

> Heads up: Whisper only reads about 224 tokens (word pieces) of the
> hint. That's roughly 150 words, which is plenty for a personal list.

## Did it work?

I had the Mac's `say` voice read a sentence full of my words, then ran
it through Small English with and without the list:

| | What came back | Time |
|---|---|---|
| No words | ...and I build leak flow for my stream deck... | 0.87 s |
| With my words | ...and I build Leak Flow for my Stream Deck... | 0.86 s |

Same speed, right spelling. 🎉

I also ran three seconds of silence through it both ways, since
[entry 04](04-the-app-that-only-heard-you.md) taught me Whisper likes to
invent words when nobody's talking. I was worried it would invent *my*
words now. It didn't.

What it did do, list or no list, is return this:

```text
[BLANK_AUDIO]
```

That's Whisper's way of saying "nothing here", and Leak Flow would paste
it as if I'd said it. That bug was already there before My Words, so it
gets its own fix.

## What I learned

- The hint has to stay alive while Whisper runs. whisper.cpp only
  borrows the text, so in Swift it has to happen inside `withCString`.
  Outside that block, the text is already gone.
- A big cloud app and my little local one can want the same thing. The
  trick is picking the part that doesn't need the cloud.

## What's next

- Stop pasting `[BLANK_AUDIO]`.
- Maybe read words near my cursor too, the way Wispr does, so names in
  the email I'm answering get spelled right without me adding them. Only
  if I catch myself adding names to the list all the time.
