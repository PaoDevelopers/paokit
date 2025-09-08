# PaoPrint

[YK Pao School](https://ykpaoschool.cn) (Songjiang Campus) has a student
printing service. However, the IT department only provides drivers for macOS.

I dislike the design of CUPS and I've found very little documentation on how to
write CUPS drivers. This is a simple program that accepts a PostScript file and
sends it to the printer using the strange LPD-PJL-PDL-whatever protocol.

## Build

This program is written in [Hare](https://harelang.org) and only requires
the standard library. Just use `hare build .`.

## Usage

```
paoprint: LPD print client                                                       
                                                                                   
Usage: paoprint [-h] [-f <file>] [-u <user>] [-p <pass>]                         
                                                                                   
-h: print this help text                                                           
-f <file>: file to print                                                           
-u <user>: username                                                                
-p <pass>: password       
```
