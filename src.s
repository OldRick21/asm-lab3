section .data
    buffer times 6 db 0
    b_size equ $ - buffer
    buffer2 times 6 db 0
    b2_size equ $ - buffer2
    filename_ptr dq 0
    offset db 33

    ; Сообщения об ошибках
    error_args_msg db "Error: Missing filename argument", 0xA
    error_args_len equ $ - error_args_msg
    
    error_open_msg db "Error: Failed to open file", 0xA
    error_open_len equ $ - error_open_msg
    
    error_write_msg db "Error: Failed to write to file", 0xA
    error_write_len equ $ - error_write_msg
    
    error_char_msg db "Error: Invalid character detected", 0xA
    error_char_len equ $ - error_char_msg

section .text
global _start
_start:
    mov rcx, [rsp]          ; argc
    cmp rcx, 2
    jl error_args           ; Проверка аргументов

    mov rsi, [rsp + 16]     ; argv[1]
    mov [filename_ptr], rsi

    mov r14, 2
    jmp sys_read

sys_read:
    ; Чтение из stdin
    mov rax, 0  
    mov rdi, 0 
    mov rsi, buffer
    mov rdx, b_size
    syscall 

    mov r9, rax

    cmp rax, 0
    je _end

    mov r10, 0
    mov r11, r9

    ; Вычисление смещения
    movzx rax, byte [offset]   
    xor rdx, rdx                
    mov rbx, 26                 
    div rbx                     
    mov rax, rdx  

    jmp caesar_cipher_start

caesar_cipher_start:
    cmp byte [buffer + r10], 0x0A
    je skip_space

    cmp byte [buffer + r10], 0x20
    je caesar_cipher_end

    ; Проверка на допустимые символы
    cmp byte [buffer + r10], 0x41
    jb invalid_char
    cmp byte [buffer + r10], 0x7A
    jg invalid_char
    cmp byte [buffer + r10], 0x5A
    jle upper
    cmp byte [buffer + r10], 0x61
    jl invalid_char          ; Проверка на символы между Z и a

    jmp lower

space:
    add r10, 1
    jmp caesar_cipher_start

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
    jmp skip_space    

skip_space:
    mov r15, 0                    ; индекс для buffer2
    mov r10, 0                    ; индекс для buffer
    mov rbx, b2_size         ; Загружаем размер buffer2

skip_loop:
    cmp r10, r9
    jge sys_file_write

    mov al, byte [buffer + r10]
    inc r10

    ; Обработка \n
    cmp al, 0x0A
    je n_sign

    ; Обработка space
    cmp al, 0x20
    je space_sign

    ; Обычный символ
    cmp r14, 1                   
    je space_write
    jmp write

n_sign:
    mov r14, 2
    jmp write_n_sign

write_n_sign:
    cmp r15, rbx
    jae skip_loop          ; Пропустить, если буфер полон
    mov byte [buffer2 + r15], 0x0A
    inc r15
    jmp skip_loop
  
space_sign:
    cmp r14, 2
    je skip_loop
    mov r14, 1
    jmp skip_loop

space_write:
    cmp r15, rbx
    jae write          ; Пропустить, если буфер полон
    mov byte [buffer2 + r15], 0x20
    inc r15
    jmp write 

write: 
    mov r14, 0
    cmp r15, rbx
    jae skip_loop          ; Пропустить, если буфер полон
    mov byte [buffer2 + r15], al
    inc r15
    jmp skip_loop

sys_file_write:
    ; Открытие файла
    mov rax, 2
    mov rdi, [filename_ptr]
    mov rsi, 0x441          ; O_WRONLY | O_CREAT | O_APPEND
    mov rdx, 0755o
    syscall

    cmp rax, 0
    jl open_error           ; Обработка ошибки открытия
    mov r8, rax

    ; Запись в файл
    mov rax, 1
    mov rdi, r8
    mov rsi, buffer2
    mov rdx, r15
    syscall

    cmp rax, 0
    jl write_error          ; Обработка ошибки записи

    ; Закрытие файла
    mov rax, 3
    mov rdi, r8
    syscall

    jmp sys_read

; Обработчики ошибок
error_args:
    mov rax, 1
    mov rdi, 2
    mov rsi, error_args_msg
    mov rdx, error_args_len
    syscall
    jmp exit_error

open_error:
    mov rax, 1
    mov rdi, 2
    mov rsi, error_open_msg
    mov rdx, error_open_len
    syscall
    jmp exit_error

write_error:
    mov rax, 1
    mov rdi, 2
    mov rsi, error_write_msg
    mov rdx, error_write_len
    syscall
    jmp exit_error

invalid_char:
    mov rax, 1
    mov rdi, 2
    mov rsi, error_char_msg
    mov rdx, error_char_len
    syscall
    jmp exit_error

exit_error:
    mov rax, 60
    mov rdi, 1
    syscall

_end:
    mov rax, 60
    mov rdi, 0
    syscall