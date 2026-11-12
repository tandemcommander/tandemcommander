state: not-sent

Thank you for the report and the screenshot, and for the kind words!

The cause: both viewers draw their page with Microsoft's WebView2 engine, which runs as a separate
process. Tandem Commander scales its windows for the display scaling that was in effect when it
started, and so did that engine process, but only from the moment *it* started, which is the
first F3 of a session. If the display scaling changed in between (in Settings, by docking or
undocking a laptop, or through a remote-desktop session), the two worked with different scalings.
The page then came out larger, shifted right and down, and cut off at the edges, as on your
screenshot.

The next version should fix it (feature 424). The Code Viewer and the Markdown Viewer, and the
engine process behind them, now follow the scaling of the monitor they are on, so their scaling no
longer depends on when either process started. This should also help on a second monitor with
another scaling and when you move a viewer between monitors. The rest of Tandem Commander keeps its
current behaviour. Our test machine runs at 100 %, so the change was checked there and the scaling
cases are being checked by hand before the release. Please tell us whether the next version works
for you.

Until then, a workaround: close Tandem Commander completely and start it again after the scaling
changed (or sign out and back in). Then both processes start at the same scaling.

If you still see the shift with the next version, please tell us your display scaling, how many
monitors you use and whether the scaling was changed while Tandem Commander was running. One more
thing to know: while an older version of Tandem Commander is running, the viewers of the new one
cannot start their engine (and the other way round). Close the older one first.
