@echo off
c:\masm32\bin\ml /c /Zd /coff dir.asm
c:\\masm32\bin\Link /SUBSYSTEM:CONSOLE dir.obj
pause
