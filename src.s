section .data
section .text
global _start
_start:
    jmp _end
_end:
    mov eax, 60
	mov	edi, 0
	syscall
