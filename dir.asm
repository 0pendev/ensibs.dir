.386
.model flat,stdcall
option casemap:none

include c:\masm32\include\windows.inc
include c:\masm32\include\gdi32.inc
include c:\masm32\include\gdiplus.inc
include c:\masm32\include\user32.inc
include c:\masm32\include\kernel32.inc
include c:\masm32\include\msvcrt.inc

includelib c:\masm32\lib\gdi32.lib
includelib c:\masm32\lib\kernel32.lib
includelib c:\masm32\lib\user32.lib
includelib c:\masm32\lib\msvcrt.lib

.DATA
;;; variables initialisees
dot		db	".",0
dotdot		db	"..",0
formatpath	db	"\*",0
defaultpath	db	"C:\*",0,0
defaultprint	db	"%s",10,0
rawprint	db	"%s",0
errorprint	db	"Error message : %d !",10,0
endCommand	db	"Pause",13,10,0
depthprint	db	"	",0
depth		dword	0	
debug		db 	"%d",10,0

.DATA?
;;; variables non-initialisees (bss)
filedata		WIN32_FIND_DATA <>

.CODE
canbeexplored PROC
;;; int canbeexplored(char* file)
	push ebp
	mov ebp, esp

	;; if (strcmp(file, dot) == 0)
	push offset dot
	push dword ptr[ebp+8]
	call crt_strcmp
	add esp, 8
	cmp eax, 0
	jne endifisdot

	;; return 0
	mov eax,0
	jmp endcanbeexplored
endifisdot:

	;; if (strcmp(file, dotdot) == 0)
	push  offset dotdot
	push dword ptr[ebp+8]
	call crt_strcmp
	add esp, 8
	cmp eax, 0
	jne endifisdotdot

	;; return 0
	mov eax,0
	jmp endcanbeexplored
endifisdotdot:

	;; return 1
	mov eax,1
endcanbeexplored:
	mov esp, ebp
	pop ebp
	ret
canbeexplored ENDP

dispLastError PROC
;;; void dispLastError()
	push ebp
	mov ebp, esp

	call GetLastError
	push eax

	cmp eax, 18
	je enddisplasterror
	
	push offset errorprint
	call crt_printf
	add esp,8

enddisplasterror:	
	
	mov esp, ebp
	pop ebp
	ret
dispLastError ENDP

printdepth PROC
	push ebp
	mov ebp, esp

	mov ebx, depth
whiledepth:
	cmp ebx,0
	je endwhiledepth
	push offset depthprint
	push offset rawprint
	call crt_printf
	add esp, 8
	dec ebx
	jmp whiledepth
endwhiledepth:	
	
	mov esp, ebp
	pop ebp
	ret
printdepth ENDP	
	
dir PROC
;;; void dir(char* path)
	push ebp
	mov ebp, esp

	;; HANDLE filehandle
	sub esp, 4

	;; findhandle = FindFirstFile(path, filedata)
	push offset filedata
	push dword ptr [ebp+8]
	call FindFirstFile
	mov [ebp-4], eax

	;; if (findhandle == INVALID_HANDLE_VALUE)
	cmp dword ptr [ebp-4], INVALID_HANDLE_VALUE
	jne iffindfirstnoerror
	;; dispLastError(findhandle)
	push dword ptr [ebp-4]
	call dispLastError
	add esp,4
	;; return
	jmp enddir
iffindfirstnoerror:

	;; int pathlen, bufferlen
	;; char* buffer
	sub esp, 12

	;; do {...} while (FindNextFile(findhandle, filedata) != 0)
whilethereisanextfile:
	;; printdepth
	call printdepth
	;; printf(defaultprint, filedata.cFileName)
	push offset filedata.cFileName
	push offset defaultprint
	call crt_printf
	add esp,8

	;; if (filedata.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY == FILE_ATTRIBUTE_DIRECTORY
	;; && canbeexplored(filedata.cFilename))
	mov eax, filedata.dwFileAttributes
	and eax, FILE_ATTRIBUTE_DIRECTORY
	cmp eax, FILE_ATTRIBUTE_DIRECTORY	
	je ifisadirectory
	jmp continuewhile
ifisadirectory:
	push offset filedata.cFileName
	call canbeexplored
	add esp, 4
	cmp eax, 1
	je ifcanbeexplored
	jmp continuewhile
ifcanbeexplored:
	
	;; pathlen = strlen(path)
	push dword ptr[ebp+8]
	call crt_strlen
	add esp,4
	mov [ebp-8], eax

	;; bufferlen = pathlen
	mov eax, [ebp-8]
	mov [ebp-12], eax

	;; bufferlen += strlen(filedata.cFileName)
	push offset filedata.cFileName
	call crt_strlen
	add esp,4
	add [ebp-12], eax

	;; bufferlen += 3
	mov eax, 3
	add [ebp-12], eax

	;; buffer = malloc(8 * (bufferlen + (4 - (bufferlen % 4))))
	mov edx, 0
	mov eax, [ebp-12]
	mov ebx, 4
	div ebx
	mov eax, 4
	sub eax, edx
	add eax, [ebp-12]
	sub esp, eax

	mov [ebp-16], ebp
	sub [ebp-16], eax
	mov eax, 16
	sub [ebp-16], eax

	;; strncpy(buffer, path, pathlen-1)
	mov eax, [ebp-8]
	sub eax, 1
	push eax
	push dword ptr[ebp+8]
	push [ebp-16]
	call crt_strncpy
	add esp,12

	;; buffer[pathlen] = \0
	mov eax, [ebp-16]
	add eax, [ebp-8]
	sub eax, 1
	mov [eax], DWORD PTR 0

	;; strcat(buffer, filedata.cFileName)
	push offset filedata.cFileName
	push [ebp-16]
	call crt_strcat
	add esp,8
	
	;; strcat(buffer, formatpath)
	push offset formatpath
	push [ebp-16]
	call crt_strcat
	add esp,8

	;; depth++
	inc depth
	
	;; dir(buffer)
	push [ebp-16]
	call dir
	add esp,4

	;; depth--
	dec depth

	;; free(buffer)
	mov edx, 0
	mov eax, [ebp-12]
	mov ebx, 4
	div ebx
	mov eax, 4
	sub eax, edx
	add eax, [ebp-12]
	add esp, eax
continuewhile:
	
	;; if (FindNextFile(findhandle, filedata) == 0)
	push offset filedata
	push [ebp-4]
	call FindNextFile
	cmp eax, 0
	jne iffindnextnoerror
	;; dispLastError(findhandle)
	push dword ptr [ebp-4]
	call dispLastError
	add esp,4
	;; return
	jmp enddir
iffindnextnoerror:

	jmp whilethereisanextfile

enddir:
	;; return void
	mov esp, ebp
	pop ebp
	ret
dir ENDP

start:
;;; void entrypoint()
	;; dir(defaultpath)
	push offset defaultpath
	call dir
	add esp, 4

	;; Ending the program nicely
	invoke crt_system, offset endCommand
	mov eax, 0
	invoke	ExitProcess,eax
end start
