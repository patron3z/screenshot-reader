# screenshot-reader

An Agent Skill that lets a coding agent (Claude Code, Codex, OpenCode) read screenshots **without keeping the image in the conversation**.

An image costs tokens when it is sent, and then stays in the context and is re-read on every following action. This skill gets the information out and keeps the picture out:

1. **A web page:** use the browser's page-text tool, not a screenshot.
2. **A screenshot where only the words matter:** turn it into text with the OCR built into Windows (`scripts/shot.ps1`).
3. **Layout or colours matter:** crop and shrink first (`-Mode shrink`), then look at the small file.
4. **Many images:** give them to a sub-agent and ask for a short written answer.

Everything runs on your computer. No image is uploaded and nothing is installed: the script uses Windows' own OCR engine.

## Use the script

```powershell
powershell -NoProfile -File scripts\shot.ps1 -Path C:\path\shot.png                    # text found in the image
powershell -NoProfile -File scripts\shot.ps1 -Path C:\path\shot.png -Scale 2           # small text
powershell -NoProfile -File scripts\shot.ps1 -Path C:\path\shot.png -Crop 0,90,900,100 # x,y,width,height
powershell -NoProfile -File scripts\shot.ps1 -Path C:\path\shot.png -Mode shrink -MaxWidth 800   # writes a small PNG, prints its path
```

## Install the skill

Copy this folder to your agent's skills folder (and adjust the path in `SKILL.md` if it is not under `~/.claude/skills`):

| Agent | Folder |
|---|---|
| Claude Code | `~/.claude/skills/screenshot-reader` |
| Codex | `~/.agents/skills/screenshot-reader` |
| OpenCode | `~/.config/opencode/skills/screenshot-reader` |

## Limits (read this)

- **Windows only** (it uses the Windows 10/11 OCR engine). On Mac or Linux the shrink idea and the guidance still apply, but the script does not.
- The OCR reads **printed text**. It does not understand pictures, charts, colours or handwriting, and it can miss small or low-contrast text.
- It reads only the languages installed in Windows. Add one in Settings > Time & language > Language, otherwise accents may come out wrong.
- Check numbers read by OCR (amounts, dates, phone numbers) when they matter.
- Status: tested on Windows 10 with Claude Code, on a generated test image (reading, crop, scale, shrink, error cases). Not yet tried on real screenshots, nor inside Codex or OpenCode.

## License

MIT, see `LICENSE`.
