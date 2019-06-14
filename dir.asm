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
;;; variables globales initialisees
dot		db	".",0
dotdot		db	"..",0
formatpath	db	"\*",0
formatpathunix	db	"/*",0	
defaultprint	db	"%s",10,0
errorprint	db	"Error message : %d !",10,0
accessdenied	db	"Access Denied !",10,0
endCommand	db	"Pause",13,10,0
depthprint	db	"  | ",0
depth		dword	0
debug		db	"%d",10,0
getpath		db	"%255s"
welcome		db	"Please enter a valid path (less than 255 characters and ends with '\*' or '/*').",10,"--> ",0
	
.DATA?
;;; variables globales non-initialisees (bss)
filedata	WIN32_FIND_DATA <>
path		db		256 dup (?)
	
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

isavalidsearch PROC
;;; void isavalidsearch(char* path)
	push ebp
	mov ebp, esp

	;; int end
	sub esp, 4
	
	;; end = strlen(path) - 2
	push [ebp+8]
	call crt_strlen
	add esp, 4
	sub eax, 2
	mov [ebp-4], eax
	
	;; if (strcmp(path[end], formatpath)==0)
	add eax, [ebp+8]
	push eax
	push offset formatpath
	call crt_strcmp
	add esp, 8
	cmp eax, 0
	jne isnotthegoodformat
	;; return 1
	mov eax, 1
	jmp endisavalidsearch
isnotthegoodformat:

	;; if (strcmp(path[end], formatpathunix)==0)
	mov eax, [ebp-4]
	add eax, [ebp+8]
	push eax
	push offset formatpathunix
	call crt_strcmp
	add esp, 8
	cmp eax, 0
	jne isnotthegoodformatunix
	;; return 1
	mov eax, 1
	jmp endisavalidsearch
isnotthegoodformatunix:
	
	;; return 0
	mov eax, 0
endisavalidsearch:
	mov esp, ebp
	pop ebp
	ret
isavalidsearch ENDP

	
displasterror PROC
;;; void displasterror()
	push ebp
	mov ebp, esp
	
	;; int i = GetLastError()
	;; if( i == 18)
	call GetLastError
	cmp eax, 18
	;; return
	je enddisplasterror

	;; printdepth()
	call printdepth
	
	;; if (i == 5)
	;; printf (accessdenied)
	push offset accessdenied
	call crt_printf
	add esp, 4
	;; return
	je enddisplasterror

	;; printf(errorprint, i)
	push eax
	push offset errorprint
	call crt_printf
	add esp,8

enddisplasterror:
	mov esp, ebp
	pop ebp
	ret
displasterror ENDP

printdepth PROC
;;; void printdepth()
	push ebp
	mov ebp, esp

	;; int i = depth
	mov ebx, depth

	;; while (i != 0)
whiledepth:
	cmp ebx,0
	je endwhiledepth

	;; printf(depthprint)
	push offset depthprint
	call crt_printf
	add esp, 4

	;; i--
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
	;; displasterror(findhandle)
	push dword ptr [ebp-4]
	call displasterror
	add esp,4
	;; return
	jmp enddir
iffindfirstnoerror:

	;; int pathlen, bufferlen
	;; char* buffer
	sub esp, 12

	;; do {...}
whilethereisanextfile:
	;; printdepth()
	call printdepth
	;; printf(defaultprint, filedata.cFileName)
	push offset filedata.cFileName
	push offset defaultprint
	call crt_printf
	add esp,8

	;; if (filedata.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY != FILE_ATTRIBUTE_DIRECTORY
	;; || !canbeexplored(filedata.cFilename))
	;; continue
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

	;; {...} while (FindNextFile(findhandle, filedata) != 0)
	push offset filedata
	push [ebp-4]
	call FindNextFile
	cmp eax, 0
	jne whilethereisanextfile

	;; displasterror(findhandle)
	push dword ptr [ebp-4]
	call displasterror
	add esp,4

enddir:
	mov esp, ebp
	pop ebp
	ret
dir ENDP

start:
;;; void entrypoint()

	;; printf(welcome)
	push offset welcome
	call crt_printf
	add esp,4
	
	;; scanf(getpath, path)
	push offset path
	push offset getpath
	call crt_scanf
	add esp, 8

	;; if( isavalidsearch(path) )
	push offset path
	call isavalidsearch
	add esp, 4
	cmp eax, 0
	je isnotavalidpath
	
	;; dir(path)
	push offset path
	call dir
	add esp, 4

isnotavalidpath:	
	
	;; Ending the program nicely
	invoke crt_system, offset endCommand
	mov eax, 0
	invoke	ExitProcess,eax
end start
