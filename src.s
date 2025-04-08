section .data
    buffer times 255 db 0
    b_size equ $ - buffer
    filename db "output.txt", 0
    offset db 33 ;7
section .text
global _start
_start:
    jmp sys_read

sys_read:

    ;Запись строки
    mov rax, 0  
    mov rdi, 0 
    mov rsi, buffer
    mov rdx, b_size
    syscall 

    ;запись количества байт в строке
    mov r9, rax

    ;ПРоверка на переполнение
    cmp rax, b_size
    jge err

    ; Проверка на EOF (rax == 0)
    cmp rax, 0
    je _end

    mov r10, 0
    mov r11, r9
    sub r11, 1

    ;Сохраняет смещение в регистр
    movzx rax, byte [offset]   
    ;Обработка смещения чтобы не превышало 26 
    xor rdx, rdx                
    mov rbx, 26                 
    div rbx                     
    mov rax, rdx  

    jmp caesar_cipher_start

caesar_cipher_start:

    ;Вычисляет регистр буквы
    cmp byte [buffer + r10], 0x5A
    jle upper
    jmp lower

upper:
    ;ПРоверяет выходит ли смещение за пределый алфавита верхнего регистра 
    mov r12b, byte [buffer + r10]
    add r12b, al
    cmp r12b, 0x5A
    jg upper_overflow
    jmp now_overflow

upper_overflow:
    ; Коректно обрабатывает смещение при выходе за пределы
    sub r12b, 0x5A
    mov byte [buffer + r10], 0x40
    add byte [buffer + r10], r12b

    jmp caesar_cipher_end


lower:
    ;ПРоверяет выходит ли смещение за пределый алфавита нижнего регистра 
    movzx r12, byte [buffer + r10]
    add r12, rax
    cmp r12, 0x7A
    jg lower_overflow
    jmp now_overflow

lower_overflow:
    ; Коректно обрабатывает смещение при выходе за пределы
    sub r12b, 0x7A
    mov byte [buffer + r10], 0x60
    add byte [buffer + r10], r12b

    jmp caesar_cipher_end


now_overflow:
    add byte [buffer + r10], al 

    jmp caesar_cipher_end


caesar_cipher_end:
    add r10, 1
    cmp r10, r11
    jb caesar_cipher_start
    jmp sys_file_write


sys_file_write:
    ;Откртыие файла
    mov rax, 2
    mov rdi, filename
    mov rsi, 0x441
    mov rdx, 0755o
    syscall

    ;Сохранения дискриптора
    mov r8, rax

    ;Запись в файл
    mov rax, 1
    mov rdi, r8
    mov rsi, buffer
    mov rdx, r9
    syscall

    ;закртие
    mov rax, 3
    mov rdi, r8
    syscall

    jmp sys_read

err:
    mov eax, 60
	mov	edi, 1
	syscall
_end:
    mov eax, 60
	mov	edi, 0
	syscall
