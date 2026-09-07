# Galei Ivrit Jr Local Song Factory

This branch adds a simplified local Hebrew educational song workflow on top of ACE-Step 1.5.

## Fastest Windows setup

1. Clone this branch:
   `git clone --branch galei-junior-local https://github.com/rjayherman-create/ACE-Step-1.5.git`
2. Open the folder in VS Code.
3. Run `powershell -ExecutionPolicy Bypass -File galei\setup_galei_windows.ps1` once.
4. Double-click `START_GALEI_SONG_FACTORY.bat`.
5. Your browser opens to `http://127.0.0.1:8765`.

The setup script detects CPU, system RAM, NVIDIA GPU/VRAM, and free disk space. It selects a conservative local profile and writes it to `galei/computer-profile.json`.

## What the Galei screen does

- Choose a Junior module.
- Edit or replace the supplied Hebrew lyrics.
- Edit the production/style description.
- Choose duration and number of variations.
- Generate complete audio songs through the local ACE-Step API.
- Audition generated variations in the browser.
- Save the selected module song to `galei/output/<module>.mp3` with matching metadata JSON.

## Current curriculum presets

- At Home: בית, דלת, ספר
- Animal Friends: כלב, חתול, דג
- My Classroom: ילד, ילדה, מורה
- Colors Everywhere: כחול, אדום, ירוק

## Audio standard

This workflow creates rendered audio with vocals and instrumentation. It is not a MIDI sequencer. The default model is `acestep-v15-turbo` to remain practical on older hardware. Higher-end profiles can be enabled later after we verify the actual computer profile.

## First-run note

ACE-Step models download on first use, so the first startup/generation requires internet access and sufficient free disk space. Later generations can run locally with the downloaded models.
