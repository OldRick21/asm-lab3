section .data
    buffer times 255 db 0
    b_size equ $ - buffer
    filename db "output.txt", 0
section .text
global _start
_start:
    ;Запись строки
    mov rax, 0  
    mov rdi, 0 
    mov rsi, buffer
    mov rdx, b_size
    syscall 

    ;ПРоверка на переполнение
    cmp rax, b_size
    jge err

    ;Откртыие файла
    mov rax, 2
    mov rdi, filename
    mov rsi, 0x41
    mov rdx, 0755o
    syscall

    ;Сохранения дискриптора
    mov r8, rax

    ;Запись в файл
    mov rax, 1
    mov rdi, r8
    mov rsi, buffer
    mov rdx, b_size
    syscall

    ;закртие
    mov rax, 3
    mov rdi, r8
    syscall





    jmp _end
err:
    mov eax, 60
	mov	edi, 1
	syscall
_end:
    mov eax, 60
	mov	edi, 0
	syscall
