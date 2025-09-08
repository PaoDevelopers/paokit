# PaoKit

PaoKit is a collection of scripts, utilities, and other files related to life
at YK Pao School

| Name            | Description                                            | Language | Dependencies                                                                     |
| --------------- | ------------------------------------------------------ | -------- | -------------------------------------------------------------------------------- |
| `chphoto`       | Change Outlook profile photos                          | Go       | [MSAL](https://github.com/AzureAD/microsoft-authentication-library-for-go)       |
| `pdfutils`      | Scripts to manipulate PDFs                             | Shell    | [Ghostscript](https://www.ghostscript.com), [Chromium](https://www.chromium.org) |
| `sjauth`        | Log on to [STUWIRELESS](https://ykps.runxiyu.org/wifi) | Hare     | [hare-http](https://git.sr.ht/~sircmpwn/hare-http)                               |
| `ykpsmuttauth`  | Get Outlook XOAUTH2 tokens for mutt/aerc               | Go       |                                                                                  |
| `paoprint`      | LPD/PDL student printer driver for the SJ Campus       | Hare     |                                                                                  |

Typically, the upstream development branch of [Hare](https://harelang.org) is
required. We do not officially support the macOS/Windows ports, but they may
work.

## Build

There is a Makefile in each subdirectory that builds the relevant program, for
programs written in compiled languages. They should support both BSD Make and
GNU Make.
