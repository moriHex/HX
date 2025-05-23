
;*** handle int 2f, ax=1684h

	.386
	include hdpmi.inc

if ?ENHANCED

	include external.inc
	include vxd.inc

?CLRI2F1684	= 1	;int 2f,ax=1684: set ES:E/DI to 0:0 
;?LOG		= 2+4;log switches (unsupported int 2f,ah=1684 calls)
?LOG		= 0	;log switches (unsupported int 2f,ah=1684 calls)
?DBGSTOP	= 0 ;

PR_PRIVATE	equ 80000400h
PR_SHARED	equ 80060000h
PR_SYSTEM	equ 80080000h

@dbgbreak macro
if ?DBGSTOP
 if 1
	or byte ptr [esp+4].IRETS.rFL+1,1	;set trace flag
 else
	int 3
 endif
endif
endm

_DATA16 segment
dwSharedHeap dd (0C0000000h shr 12)
dwSystemHeap dd (0C0000000h shr 12)
_DATA16 ends

_TEXT32 segment

vxdtab label word
if ?SUPI2F16840001	;VMM
	dw 0001h, _I2F1684_0001_
endif
if ?SUPI2F16840009	;reboot
	dw 0009h, _I2F1684_0009_
endif
if ?SUPI2F16840017	;shell
	dw 0017h, _I2F1684_0017_
endif
if ?SUPI2F16840021	;pagefile
	dw 0021h, _I2F1684_0021_
endif
if ?SUPI2F1684002A	;vwin32
	dw 002Ah, _I2F1684_002A_
endif
if ?SUPI2F16840442	;vtdapi
	dw 0442h, _I2F1684_0442_
endif
endvxdtab label word

;--- check if vxd in BX is known
;--- return with a near RET!

checkvxd proc public
	push esi
	mov esi,offset vxdtab
nextitem:
	cmp esi,offset endvxdtab
	jz notfound
	cmp cs:[esi],bx
	jz found
	add esi,4
	jmp nextitem
notfound:
	pop esi
if ?LOG and 1
	push 2Fh
	call unsupp
endif
if ?CLRI2F1684
  if ?32BIT
	xor edi,edi
  else
	xor di,di
  endif
	mov es,edi
endif
	stc
	ret
found:
if ?32BIT
	movzx edi,word ptr cs:[esi+2]
else
	mov di,cs:[esi+2]
endif
	pop esi
	push _INTSEL_
	pop es
	clc
	ret
checkvxd endp

;*** callback vxd 0001 (vmm) ***

if ?SUPI2F16840001

	@ResetTrace

_vxd_0001 proc public
	push offset iret_with_CF_mod
	cmp ah,01
	jz registry
	cmp ah,02
	jz getdebugoptions
if ?LOG and 2
	@printf <"vmm: ">
	call unsuppcallx
	@dbgbreak
endif
	xor ax,ax
	stc
	ret
registry:
	@dprintf "vmm registry: ax=%X",ax
	cmp al,2
	jnb @F
;	add [esp+sizeof PUSHADS].IRETS.rSP,3*4	;RegOpenKey+RegCreateKey
	add [esp+sizeof PUSHADS].IRET32.rSP,3*4	;RegOpenKey+RegCreateKey
@@:
	mov ax,5		;ERROR_ACCESS_DENIED
	xor dx,dx
	@dbgbreak
	ret
getdebugoptions:
	@dprintf "vmm getdebugoption: ax=%X",ax
	@dbgbreak
	mov al,00
	ret
_vxd_0001 endp
endif

;*** callback vxd 0009 (reboot) ***

if ?SUPI2F16840009

	@ResetTrace

_vxd_0009 proc public
	push offset iret_with_CF_mod
if ?LOG and 4
	@printf <"reboot: ">
	call unsuppcallx
	@dbgbreak
endif
	xor ax,ax
	stc
	ret
_vxd_0009 endp
endif

;*** callback vxd 0017 (shell) ***

if ?SUPI2F16840017

_vxd_0017 proc public
	push offset iret_with_CF_mod
if ?LOG and 4
	@printf <"shell: ">
	call unsuppcallx
endif
	xor ax,ax
	stc
	ret
_vxd_0017 endp
endif

;*** callback vxd 0021 (pagefile) ***

if ?SUPI2F16840021

_vxd_0021 proc public
	push offset iret_with_CF_mod
if ?LOG and 4
	@printf <"pagefile: ">
	call unsuppcallx
endif
	xor ax,ax
	stc
	ret
_vxd_0021 endp
endif

;*** callback vxd 002A (vwin32) ***

if ?SUPI2F1684002A

_vxd_002A proc public
	push offset iret_with_CF_mod
	@dprintf "vwin32: ax=%X, es:di=%X:%X",ax,es,di
	cmp ah,0
	jz getversion
	cmp ah,8
	jz getpdb
	cmp ah,3
	jz mmgr
if ?LOG and 4
	@printf <"vwin32: ">
	call unsuppcallx
	@dbgbreak
endif
	xor ax,ax
	stc
	ret
getversion:
	mov eax,400h	;version
	mov edx,1		;vmid
	@dbgbreak
	ret
getpdb:
	xor eax,eax
	@dbgbreak
	ret
mmgr:
	push ds
	pushad
if 1;?32BIT
	lds ebx,[esp+4+sizeof PUSHADS].IRET32.rSSSP
	add [esp+4+sizeof PUSHADS].IRET32.rSP,ecx
	mov ecx,[ebx+1*4]
	mov edx,[ebx+0*4]
	@dprintf "vwin32 mmgr [esp]=%lX %lX %lX",edx, ecx, dword ptr [ebx+2*4]
else
	lds bx,[esp+4+sizeof PUSHADS].IRETS.rSSSP
	add [esp+4+sizeof PUSHADS].IRETS.rSP,cx
	mov ecx,[bx+1*4]
	mov edx,[bx+0*4]
	@dprintf "vwin32 mmgr [esp]=%lX %lX %lX",edx, ecx, dword ptr [bx+2*4]
endif
	push ss
	pop ds
	assume ds:GROUP16
	.if (al == 0)			;_PageReserve
		.if (edx == PR_PRIVATE)
			xor ebx,ebx			;no specific address
		.elseif (edx == PR_SHARED)
			mov ebx, dwSharedHeap
			sub ebx, ecx
			mov dwSharedHeap, ebx
		.elseif (edx == PR_SYSTEM)
			mov ebx, dwSystemHeap
			mov edx, ebx
			add edx, ecx
			mov dwSystemHeap, edx
		.else
			mov ebx, edx
		.endif
		shl ebx, 12
		mov dl,0			;dont commit
		shl ecx,12			;size in bytes
		@dprintf "vwin32 mmgr: ebx=%lX ecx=%lX", ebx, ecx
		call allocmemx
		mov eax, ebx
		.if (CARRY?)
			mov eax,-1
		.endif
	.elseif (al == 1)		;_PageCommit(page, nPages, x, x, flags)
		mov eax,edx
		shl eax,12
		mov dl,?PF_PRESENT or ?PF_WRITEABLE or ?PF_USER
		call pm_CommitRegionZeroFill ;ecx pages at eax
		.if (CARRY?)
			xor eax,eax
		.else
			mov eax,1
		.endif
	.elseif (al == 2)		;_PageDecommit
		mov eax,edx
		shl eax,12
		call pm_UncommitRegion;ecx pages at eax
		.if (CARRY?)
			xor eax,eax
		.else
			mov eax,1
		.endif
	.else
		xor eax,eax
	.endif
	mov [esp].PUSHADS.rEAX,eax
	popad
	pop ds
	@dprintf "vwin32 mmgr ret: eax=%lX",eax
	@dbgbreak
	ret
	assume ds:nothing
_vxd_002A endp

endif

;*** callback vxd 0442 (vtdapi) ***

if ?SUPI2F16840442

	@ResetTrace

_vxd_0442 proc public
	push offset iret_with_CF_mod
	cmp ax,0
	jz exit0
	cmp ax,3
;	jb error61
	jz exit3
	cmp ax,4
	jz exit4
error61:
	mov ax,61h
	stc
	ret
exit0:
	mov ax,1
if ?32BIT
	mov word ptr es:[ebx],3
else
	mov word ptr es:[bx],3
endif
	ret
exit3:
	mov ax,55
	xor dx,dx
	ret
exit4:				;get system time in ms
	push ds
	push 40h
	pop ds
	pushad
	mov eax,ds:[6Ch]
	mov ecx,55
	mul ecx
	mov [esp].PUSHADS.rAX,ax
	shr eax,16
	mov [esp].PUSHADS.rDX,ax
	popad
	pop ds
	clc
	ret
_vxd_0442 endp
endif

_TEXT32  ends

endif	;?ENHANCED

	end
