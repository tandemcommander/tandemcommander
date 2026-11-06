state: not-sent

Thank you for the report and the recording - it showed exactly what happens.

When you click another tab and switching away from the FTP tab first asks what to do with the connection, the question took the mouse button's release. The tab strip did not notice that and kept waiting for a tab drag: the insert mark then followed the mouse, and the next press could move the tab.

This is fixed in feature 405 (it will be in the next release): after a tab switch that showed a question, the strip no longer starts a drag when the button is no longer held, and it does not keep the mouse to itself, so the next click goes where you click. A tab moves only while you hold the button from the press to the release; dragging tabs works as before.

The same applies to any question or error message that appears while switching tabs (other plug-in file systems, an archive asking whether to update, a folder that no longer exists).
