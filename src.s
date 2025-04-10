section .data
    buffer times 6 db 0
    b_size equ $ - buffer
    buffer2 times 6 db 0
    b2_size equ $ - buffer2
    filename db "output.txt", 0
    offset db 33 

section .text
global _start
_start:
    mov r14, 2                    ; состояние: 0-символ, 1-пробел, 2-начало строки
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

    ; Проверка на EOF (rax == 0)
    cmp rax, 0
    je _end

    mov r10, 0
    mov r11, r9
    ;sub r11, 1

    ;Сохраняет смещение в регистр
    movzx rax, byte [offset]   
    ;Обработка смещения чтобы не превышало 26 
    xor rdx, rdx                
    mov rbx, 26                 
    div rbx                     
    mov rax, rdx  

    jmp caesar_cipher_start

caesar_cipher_start:
    cmp byte [buffer + r10], 0x0A
    je skip_space ; sys_file_write

    cmp byte [buffer + r10], 0x20
    je caesar_cipher_end

    ;Проверка на букву
    cmp byte [buffer + r10], 0x41
    jb err
    cmp byte [buffer + r10], 0x7A
    jg err

    ;Вычисляет регистр буквы
    cmp byte [buffer + r10], 0x5A
    jle upper
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
    cmp r15, rbx
    jae skip_loop          ; Пропустить, если буфер полон
    mov r14, 0
    mov byte [buffer2 + r15], al
    inc r15
    jmp skip_loop

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
    mov rsi, buffer2
    mov rdx, r15
    syscall

    ;закртие
    mov rax, 3
    mov rdi, r8
    syscall

    jmp sys_read

err:
    mov rax, 60
    mov rdi, 1
    syscall

_end:
    mov rax, 60
    mov rdi, 0
    syscall