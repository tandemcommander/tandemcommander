state: draft

(draft of the reply to GitHub issue #13 - the maintainer posts it, translated to Czech if wanted)

Thanks for the report. Fixed in feature 248; it will be in the next release (0.1.11).

The column headers of the Desktop view (the Folders plug-in, `fld:`) come from Windows. Since an
early change (feature 004) the plug-in handed them over as UTF-8, while the panel header draws
column names in the Windows code page - so "Typ položky" showed as "Typ poloĹľky" and "Datum
změny" as "Datum zmÄ›ny". The plug-in now hands them over in the code page; on Czech Windows the
headers read "Typ položky" and "Datum změny" (checked on a Czech Windows; the file names and
types in the rows were already right and stay so).

Limits: the panel header can show only the characters of the Windows code page. A letter that
the code page does not have (for example on a Windows with a Czech display language but a
Western code page) shows as "?" - not as a different letter. A column name too long for the
header is shortened at a whole character.

Found along the way and recorded separately: switching the Desktop view to another view mode and
back to Detailed shows the columns twice.
