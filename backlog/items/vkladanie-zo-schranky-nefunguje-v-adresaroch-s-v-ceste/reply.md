state: not-sent

Thank you for the report and the screenshot – the screenshot is what showed us the cause.

**What happened:** the exclamation mark in the path is not the cause. The screenshot shows a file pasted into **the same folder** it was copied from, so the program gives the copy a new name, `zsu-1191327 - Kópia.zip`. In version 0.1.9 the word "Kópia" from the Slovak translation was put into the file name in the wrong encoding (the code page instead of UTF-8). Windows refused that name, hence the message *(123) The filename, directory name, or volume label syntax is incorrect*. The same would have happened in any folder with a Slovak (or Czech, Hungarian, …) user interface – in the folders with "!" you most likely just happened to paste into the same folder.

**Fix:** version **0.1.10** contains it (feature 127 – translated texts are now put into file names and messages as UTF-8). We checked that copying within a folder named `!!temp` under a name containing "ó" works.

Please try it again after updating to 0.1.10. If pasting still fails – for example when pasting from **another** folder into a folder with "!" – please tell us where the files were copied from (a Tandem Commander panel or Explorer) and which message appears.
