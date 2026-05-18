# Changelog

All notable changes to this project will be documented here.

## v1.1.0.0

### Added

- Added `/MT` support for multi-threaded Robocopy copy operations
- Added configurable `/MT` thread count
- Added MIR safety threshold for mirror jobs
- Added automatic activation of MIR safety threshold when MIRROR mode is enabled
- Added warning when MIR safety threshold is disabled while MIRROR mode is active
- Added improved German and English help layout
- Added clearer help explanations for `/MT` and MIR safety threshold
- Updated PS2EXE description metadata for version `1.1.0.0`

### Changed

- MIR safety threshold controls are now linked to MIRROR mode
- Safety threshold input is only active when MIRROR and the safety threshold are enabled
- Help content is now structured more clearly for German and English users

### Notes

- `/MT` enables Robocopy to copy multiple files in parallel
- MIR safety threshold helps protect against accidental mass deletions or unwanted mirror operations
- MIRROR and MOVE can permanently delete data
- Test carefully before productive use

## v1.0.0.0

- Initial GitHub project setup
- Added README
- Added docs folder
- Added screenshots folder
- Added source code
- Added license
- Added project screenshots
