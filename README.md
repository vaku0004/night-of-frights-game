# Viktoriia's Night of Frights 🎃

> A copy of [nightoffrights.monster](https://nightoffrights.monster/) that opens on GitHub Pages without redirecting: **https://vaku0004.github.io/night-of-frights-game/**. The main project lives in [vaku0004/night-of-frights](https://github.com/vaku0004/night-of-frights); this repository is updated from it.

A Halloween quiz game for office parties, made to be shown on a big screen while one host runs it from a laptop. Teams play in the room and over a video call.

**Play it:** https://nightoffrights.monster/

## What's in the game

- **Two rounds** of 25 questions (100–500, then 200–1,000) in Halloween and Canadian categories, plus a **Midnight** finale with secret wagers.
- **Black Cat in the Bag** — the team that finds the cat must hand the question to another team.
- **Deal with the Witch** — two magic wands pick a random price and a random team that must answer.
- **Spooky narrator** — every question, answer, explanation and announcement is voiced (ElevenLabs, Eleven v4). Lines without audio fall back to the browser's voice.
- Rules slides before the game, before Round Two and before the finale, a 30-second timer, thinking music for the finale, a tiebreaker and a podium.
- A question editor, so the host can change any question, answer or explanation in the browser.

## Running the game

1. Open the link above in Chrome or Edge on the computer connected to the big screen.
2. Press **F11** for full screen.
3. Choose the number of teams, name them, and press **Start the game**.

When sharing the screen in Teams or Zoom, turn on **Include computer sound** so remote players hear the narrator.

**Keyboard:** `Space` shows the answer · `R` reads the question again · `→` / `←` (or a presentation clicker) move through rules slides · `Esc` closes a question.

Opening `index.html` straight from disk works too, but browsers block loading the narrator audio from `file://`, so the browser voice is used. To hear the narrator locally, serve the folder, for example with `npx serve` or `python -m http.server`.

## Voicing new lines (Windows)

The narrator audio lives in `audio/`, with `audio/manifest.json` mapping each spoken line to its MP3.

1. In the game, open **Voice settings → Copy voice lines for the generator** and save the result as `voice-kit/voice-lines.json`.
2. Double-click `voice-kit/start-voice.bat`, paste an ElevenLabs API key, choose the voice and type `YES`.
3. The generator voices only new or changed lines and saves them into `audio/`. Commit the new files.

The API key is typed into the console only and is never saved. Use a key restricted to Text to Speech, Voices (read), Models (read) and User (read), with a credit limit.

## Credits

Game, questions and design by **Viktoriia**. Narration generated with ElevenLabs. Fonts: Pirata One, Alegreya, Alegreya Sans and Oswald from Google Fonts.
