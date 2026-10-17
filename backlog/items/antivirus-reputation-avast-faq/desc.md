---
title: Antivirus reputation: Avast Whitelisting registration and a FAQ page
type: person-step
status: open
severity: 4
area: build-release
source: leftover:077
who: person
created: 2026-09-17
updated: 2026-10-17
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Antivirus reputation: Avast Whitelisting registration and a FAQ page

## Problem

A user reported that Avast blocked and removed the program; 076 found most likely reputation-based blocking of a brand-new product (six-week-old certificate, Inno Setup 7 loader). The one-time reputation work it recommended is owed: register in the Avast Whitelisting Program and publish an 'antivirus warning?' FAQ page.

## Evidence

Migrated from specs/NEXT-WORK.md §B 'Release and catalogue housekeeping' ('antivirus reputation steps (item 0, point 4)') and §0 point 4 (~line 963) (at 7993914c). Source: specs/076-avast-false-positive-review/review-report.md section 6.

## Expected

The program is registered with the Avast Whitelisting Program; the FAQ page exists on tandemcommander.org or in the manual.

## Approach

An agent can draft the FAQ text; the registration needs the maintainer's account.

## Notes

The per-release parts of the same point - false-positive submission of each release, SHA-256 and VirusTotal link in the release notes, keeping the same certificate at its renewal (2027-08-03) - are release steps in backlog/RELEASE.md.

## Steps

- [ ] Register the product / publisher in the Avast Whitelisting Program
- [ ] Publish an 'antivirus warning?' FAQ page (draft by an agent, published by the maintainer)

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md header and §B (person steps) (feature 242)
