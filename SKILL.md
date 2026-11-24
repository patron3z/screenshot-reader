---
name: screenshot-reader
description: Read screenshots and web pages while spending as few tokens as possible. Use before looking at any screenshot or image file, and whenever a task would read a web page by screenshot. Turns a screenshot into text with Windows OCR on this PC, or shrinks and crops it, so the full image never sits in the conversation.
---

# Reading screenshots cheaply

An image in the conversation costs tokens when it is sent (roughly width x height / 750 according to Anthropic's documentation; check it for the current model), and then it stays in the context and is re-read on every following action. The expensive part is the staying. So: get the information out, keep the picture out.

## Pick the cheapest way that answers the question

1. **A web page?** Do not take a screenshot. Use the page-text or accessibility-tree tool of the browser (`get_page_text`, `read_page`, `find`). It is exact and far smaller.
2. **A screenshot file where only the words matter** (an error message, a quote, a table, an invoice, a chat): turn it into text, never open the image.
   ```powershell
   powershell -NoProfile -File "$HOME\.claude\skills\screenshot-reader\scripts\shot.ps1" -Path C:\path\shot.png
   ```
   Small text? add `-Scale 2`. Only one area? add `-Crop x,y,width,height`.
3. **The layout, colours or a drawing matter:** shrink or crop first, then look at the small file.
   ```powershell
   powershell -NoProfile -File "$HOME\.claude\skills\screenshot-reader\scripts\shot.ps1" -Path C:\path\shot.png -Mode shrink -MaxWidth 800 [-Crop x,y,w,h]
   ```
   It prints the path of the small PNG. Look at that one, never the original.
4. **Many images, or a long visual check:** give the job to a sub-agent and ask for a short written answer, so the pictures never enter the main conversation.

## Know the limits

- Windows OCR reads **printed text**. It does not understand pictures, charts, colours or handwriting, and it can miss small or low-contrast text. If the result is empty or looks wrong, say so and fall back to a cropped, shrunk image.
- Only the languages installed in Windows are read. Check with the script's error message; on this PC only English was found, so French accents may come out wrong. Add French in Windows Settings > Time & language > Language.
- Check numbers from OCR (amounts, dates, phone numbers) against the image when they matter: 1 and l, 0 and O are easy to confuse.
- Everything runs locally. No image leaves the computer.

## Report

Give the user the text or the answer, and say which method was used and whether the OCR looked reliable.
