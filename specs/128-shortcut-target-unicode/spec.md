# Feature Specification: A shortcut opens its target, whatever letters the path has

**Feature Branch**: `128-shortcut-target-unicode`
**Created**: 2026-10-13
**Status**: Draft
**Input**: GitHub issue #8 (`issues/issue_8.md`, in Czech): "I have various shortcuts; when I click one in the program I only get an error message. The same shortcut clicked in Windows Explorer works and goes to the target folder." The attached picture shows `ARCHIV.lnk` and a box *Chyba*: `(123) Název souboru či adresáře nebo jmenovka svazku je nesprávná.` Target release 0.1.10.

## What was measured before this specification was written

The report gives no path, so the cause had to be found. Probe `probe/lnk_probe.ps1` on the
released 0.1.9 (hidden desktop; shortcuts written by Windows' own link interface;
`probe/lnk_result_before_v019.txt`):

| Shortcut to | Enter on it in 0.1.9 |
|---|---|
| a folder with a plain ASCII path | opens the folder |
| a folder with Czech letters in its path (`...\t_Účetnictví`) | **the box of the report, exactly**: `(123) Název souboru či adresáře nebo jmenovka svazku je nesprávná.` |
| a folder with Greek letters | the same box |
| a deeper folder with both | the same box |
| a network path (`\\localhost\C$\...\t_Účetnictví`) | the same box |
| an ASCII folder, the shortcut itself named with accents | opens the folder |
| *Go to Shortcut Target* on the accented, the Greek and a file shortcut | *Cannot obtain shortcut target or target path is not accessible.* |

So: **every shortcut whose target path holds a letter outside plain ASCII fails** - for a Czech
user that is any folder with a háček or čárka anywhere in its path. The shortcut's own name does
not matter. The report is valid.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Enter on a shortcut opens the folder it points to (Priority: P1)

A user keeps shortcuts to folders (on the desktop, in a "shortcuts" folder). Pressing Enter on
one - or double-clicking it - in the panel opens the target folder, exactly as Windows Explorer
does, whatever language the folder names are in.

**Why this priority**: it is the report; shortcuts to folders are a daily tool and today they
fail for most real paths of non-English users.

**Independent Test**: shortcuts to folders with Czech, Greek and mixed names; Enter on each; the
panel shows the target folder.

**Acceptance Scenarios**:

1. **Given** a shortcut to `D:\Účetnictví\Archiv`, **When** the user presses Enter on it, **Then** the panel shows that folder and no message appears.
2. **Given** a shortcut to a folder whose name has letters outside the Windows code page (Greek, Chinese, an emoji), **When** Enter is pressed, **Then** the panel shows that folder.
3. **Given** a shortcut to a folder on a network share with accented names, **When** Enter is pressed, **Then** the panel shows that folder.
4. **Given** a shortcut to a plain ASCII path, **When** Enter is pressed, **Then** the behaviour is unchanged.
5. **Given** a shortcut whose target no longer exists, **When** Enter is pressed, **Then** the behaviour is unchanged (Windows' own "missing shortcut" search or the existing message).

---

### User Story 2 - "Go to Shortcut Target" works for the same shortcuts (Priority: P1)

The command that jumps to a shortcut's target works for folders and files with any letters in
their paths.

**Why this priority**: the same defect in the sibling command.

**Independent Test**: the command on shortcuts to an accented folder, a Greek folder and a file
in an accented folder.

**Acceptance Scenarios**:

1. **Given** a shortcut to an accented folder, **When** the command is used, **Then** the panel shows the target and no message appears.
2. **Given** a shortcut to a file in an accented folder, **When** the command is used, **Then** the panel shows the folder that holds the file.

---

### Edge Cases

- A target path longer than the classic 260 characters, or long in bytes because of its script: opened when the program can hold it; otherwise refused with the existing message - never cut to another path.
- A shortcut to a file (a document, a program, an archive): Enter keeps doing what it did (open / run / enter the archive); with a non-ASCII path it now gets the right path.
- A shortcut without a file-system target (a server, a control panel item): unchanged.
- The shortcut file itself in a folder with accented names: unchanged (worked before).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Enter (and double-click) on a shortcut to a folder MUST open the target folder for a target path with letters of any script.
- **FR-002**: *Go to Shortcut Target* MUST work for the same shortcuts, for folder and file targets.
- **FR-003**: The target path MUST be used whole; a path the program cannot hold MUST be refused, never shortened.
- **FR-004**: Shortcuts with plain ASCII targets, shortcuts without a file-system target and broken shortcuts MUST behave as before.
- **FR-005**: The rule "the target of a shortcut as a path of the program" MUST exist once and be covered by automated tests with real shortcut files.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: All shortcut rows of the probe pass on the fixed build (18 of 18); on 0.1.9 seven fail.
- **SC-002**: Zero error messages for shortcuts to existing folders, whatever letters their paths hold.
- **SC-003**: The unit tests read back real shortcuts to folders named in Czech, Greek, Chinese and with an emoji, exactly.

## Assumptions

- The reporter's `ARCHIV.lnk` points to a path with a non-ASCII letter somewhere (the report shows only the shortcut's name). The measured failure reproduces the reported box exactly; other causes of error 123 for a shortcut are not known. The answer to the issue asks the reporter to confirm with 0.1.10.
- Real mouse double-click is not driven by the probe (hidden desktop); Enter runs the same code.
- The fix is released in 0.1.10.
