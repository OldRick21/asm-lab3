### Полное описание кода программы шифрования Цезаря

---

#### **Секция `.data`**
```asm
buffer times 10 db 0       ; Буфер для ввода (10 байт)
b_size equ $ - buffer      ; Размер buffer (10)
buffer2 times 10 db 0      ; Буфер для обработки пробелов
b2_size equ $ - buffer2    ; Размер buffer2 (10)
filename_ptr dq 0          ; 64-битный указатель на имя файла
offset db 33               ; Смещение для шифра (33 → 7 после модуля 26)

prompt db "Enter filename: "   ; Приглашение для ввода
prompt_len equ $ - prompt
filename_buffer times 256 db 0 ; Буфер для имени файла

; Сообщения об ошибках
error_open_msg db "Error: Failed to open file", 0xA
error_open_len equ $ - error_open_msg
error_write_msg db "Error: Failed to write to file", 0xA
error_write_len equ $ - error_write_msg
error_char_msg db "Error: Invalid character detected", 0xA
error_char_len equ $ - error_char_msg
```

- **Назначение переменных**:
  - `buffer`, `buffer2`: Буферы для чтения данных и промежуточной обработки.
  - `filename_ptr`: Хранит 64-битный адрес имени файла.
  - `offset`: Исходное смещение шифра (после нормализации: `33 % 26 = 7`).
  - `filename_buffer`: Буфер для ввода имени файла (макс. 255 символов + `\0`).

---

#### **Секция `.text`**

---

### **1. Инициализация программы (`_start`)**
```asm
_start:
    ; Вывод приглашения
    mov rax, 1              ; sys_write
    mov rdi, 1              ; stdout
    mov rsi, prompt         ; текст приглашения
    mov rdx, prompt_len     ; длина сообщения
    syscall

    ; Чтение имени файла
    mov rax, 0              ; sys_read
    mov rdi, 0              ; stdin
    mov rsi, filename_buffer ; буфер для имени
    mov rdx, 256            ; макс. длина (255 символов + \n)
    syscall

    ; Обработка символа новой строки
    mov rdi, filename_buffer ; начало буфера
.process_filename_loop:
    cmp byte [rdi], 0x0A    ; поиск \n
    je .replace_newline
    inc rdi
    cmp rdi, filename_buffer + 256
    jb .process_filename_loop
    jmp .end_process
.replace_newline:
    mov byte [rdi], 0       ; замена \n на \0
.end_process:
    mov qword [filename_ptr], filename_buffer ; сохранение адреса
    mov r14, 2              ; Инициализация флага пробелов
    jmp sys_read
```

- **Логика**:
  1. Вывод приглашения `Enter filename:` через `sys_write`.
  2. Чтение имени файла в `filename_buffer` через `sys_read`.
  3. Замена символа `\n` на нуль-терминатор (`\0`).
  4. Сохранение адреса имени файла в `filename_ptr`.
  5. Инициализация регистра `r14` (флаг состояния пробелов: 2 = начало строки).

---

### **2. Чтение данных (`sys_read`)**
```asm
sys_read:
    mov rax, 0              ; sys_read
    mov rdi, 0              ; stdin
    mov rsi, buffer         ; целевой буфер
    mov rdx, b_size         ; размер буфера
    syscall

    mov r9, rax             ; Сохранение количества прочитанных байтов
    cmp rax, 0              ; Проверка на EOF (Ctrl+D)
    je _end                 ; Завершение если конец ввода

    ; Подготовка к шифрованию
    mov r10, 0              ; Индекс символа в буфере
    mov r11, r9             ; Лимит обработки

    ; Нормализация смещения (offset mod 26)
    movzx rax, byte [offset]
    xor rdx, rdx
    mov rbx, 26
    div rbx
    mov rax, rdx            ; Действительное смещение (0-25)
```

- **Логика**:
  1. Чтение данных из `stdin` в `buffer` (макс. 10 байт).
  2. Проверка на конец ввода (`rax = 0`).
  3. Расчет действительного смещения для шифра:  
     `offset = 33 → 33 % 26 = 7`.

---

### **3. Алгоритм шифрования Цезаря**

#### **a. Валидация символов**
```asm
caesar_cipher_start:
    cmp byte [buffer + r10], 0x0A ; \n
    je skip_space
    cmp byte [buffer + r10], 0x09 ; Табуляция
    je caesar_cipher_end
    cmp byte [buffer + r10], 0x20 ; Пробел
    je caesar_cipher_end

    ; Проверка диапазона символов
    cmp byte [buffer + r10], 0x41 ; Ниже 'A'?
    jb invalid_char
    cmp byte [buffer + r10], 0x7A ; Выше 'z'?
    jg invalid_char
    cmp byte [buffer + r10], 0x5A ; <= 'Z'?
    jle upper
    cmp byte [buffer + r10], 0x61 ; < 'a'?
    jl invalid_char
    jmp lower
```

- **Логика**:
  - Пропуск символов `\n`, `\t`, ` ` (пробел).
  - Валидация символов:
    - Допустимы: `A-Z` (0x41-0x5A), `a-z` (0x61-0x7A).
    - Недопустимые символы → ошибка `invalid_char`.

---

#### **b. Обработка верхнего регистра (`A-Z`)**
```asm
upper:
    mov r12b, byte [buffer + r10] ; Загрузка символа
    add r12b, al                  ; Применение смещения
    cmp r12b, 0x5A                ; Переполнение?
    jg upper_overflow
    jmp now_overflow

upper_overflow:
    sub r12b, 0x5A               ; Коррекция переполнения
    mov byte [buffer + r10], 0x40 ; '@' (ASCII перед 'A')
    add byte [buffer + r10], r12b ; Новый символ
    jmp caesar_cipher_end
```

- **Пример**:
  - Символ: `'Z'` (0x5A) + 7 = 0x61 → `'a'` (некорректно для верхнего регистра).
  - Коррекция:  
    `0x61 - 0x5A = 7 → 0x40 ('@') + 7 = 0x47 ('G')`.

---

#### **c. Обработка нижнего регистра (`a-z`)**
```asm
lower:
    movzx r12, byte [buffer + r10]
    add r12, rax                 ; Применение смещения
    cmp r12, 0x7A                ; Переполнение?
    jg lower_overflow
    jmp now_overflow

lower_overflow:
    sub r12b, 0x7A               ; Коррекция
    mov byte [buffer + r10], 0x60 ; '`' (перед 'a')
    add byte [buffer + r10], r12b
    jmp caesar_cipher_end

now_overflow:
    add byte [buffer + r10], al  ; Без переполнения
    jmp caesar_cipher_end
```

- **Пример**:
  - Символ: `'z'` (0x7A) + 7 = 0x81 → коррекция:  
    `0x81 - 0x7A = 7 → 0x60 ('`') + 7 = 0x67 ('g')`.

---

#### **d. Переход к следующему символу**
```asm
caesar_cipher_end:
    inc r10
    cmp r10, r11                 ; Все символы обработаны?
    jb caesar_cipher_start       ; Нет → продолжить
    jmp skip_space               ; Да → фильтрация пробелов
```

---

### **4. Фильтрация пробелов (`skip_space`)**
```asm
skip_space:
    mov r15, 0                   ; Индекс для buffer2
    mov r10, 0                   ; Индекс для buffer
    mov rbx, b2_size             ; Макс. размер buffer2

skip_loop:
    cmp r10, r9                  ; Обработаны все символы?
    jge sys_file_write           ; Да → запись в файл

    mov al, byte [buffer + r10]  ; Загрузка символа
    inc r10

    ; Обработка \n
    cmp al, 0x0A
    je n_sign

    ; Обработка пробелов/табуляции
    cmp al, 0x20
    je space_sign
    cmp al, 0x09
    je space_sign

    ; Запись символа
    cmp r14, 1                   ; Предыдущий был пробел?
    je space_write               ; Да → добавить пробел
    jmp write

n_sign:
    mov r14, 2                   ; Флаг "начало строки"
    jmp write_n_sign

write_n_sign:
    cmp r15, rbx                 ; Проверка переполнения
    jae skip_loop
    mov byte [buffer2 + r15], 0x0A ; Запись \n
    inc r15
    jmp skip_loop

space_sign:
    cmp r14, 2                   ; Начало строки?
    je skip_loop                 ; Пропустить ведущие пробелы
    mov r14, 1                   ; Флаг "пробел"
    jmp skip_loop

space_write:
    cmp r15, rbx
    jae write
    mov byte [buffer2 + r15], 0x20 ; Запись пробела
    inc r15
    jmp write

write:
    mov r14, 0                   ; Сброс флага пробелов
    cmp r15, rbx
    jae skip_loop
    mov byte [buffer2 + r15], al ; Запись символа
    inc r15
    jmp skip_loop
```

- **Логика**:
  1. **Регистр `r14`**:
    - `2`: Начало строки (пропуск ведущих пробелов).
    - `1`: Предыдущий символ — пробел (замена на один пробел).
    - `0`: Обычный символ.
  2. **Правила фильтрации**:
    - Сохраняется один пробел между словами.
    - Удаляются ведущие пробелы.
    - Сохраняются переводы строк (`\n`).

---

### **5. Запись в файл (`sys_file_write`)**
```asm
sys_file_write:
    ; Открытие файла
    mov rax, 2              ; sys_open
    mov rdi, [filename_ptr] ; имя файла
    mov rsi, 0x441          ; флаги: O_WRONLY|O_CREAT|O_APPEND
    mov rdx, 0755o          ; права: rwxr-xr-x
    syscall

    cmp rax, 0              ; Проверка ошибки
    jl open_error
    mov r8, rax             ; Сохранение дескриптора

    ; Запись данных
    mov rax, 1              ; sys_write
    mov rdi, r8             ; дескриптор файла
    mov rsi, buffer2        ; данные для записи
    mov rdx, r15            ; количество байт
    syscall

    cmp rax, 0              ; Проверка ошибки
    jl write_error

    ; Закрытие файла
    mov rax, 3              ; sys_close
    mov rdi, r8
    syscall

    jmp sys_read            ; Цикл чтения
```

- **Флаги открытия файла**:
  - `O_WRONLY`: Только запись.
  - `O_CREAT`: Создать файл, если не существует.
  - `O_APPEND`: Дозапись в конец файла.
- **Права доступа**: `0755o` (rwxr-xr-x).

---

### **6. Обработка ошибок**
```asm
open_error:
    mov rax, 1              ; sys_write
    mov rdi, 2              ; stderr
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
    mov rax, 60             ; sys_exit
    mov rdi, 1              ; код ошибки
    syscall

_end:
    mov rax, 60             ; sys_exit
    mov rdi, 0              ; код успеха
    syscall
```

- **Коды завершения**:
  - `0`: Успешное выполнение.
  - `1`: Ошибка (некорректный символ, ошибка файла).

---

### **Пример работы**
1. **Ввод**:
   ```
   Enter filename: output.txt
   Hello World!
   ```

2. **Шифрование** (смещение 7):
   - `H → O`, `e → l`, `l → s`, `o → v`, `W → D`, `r → y`, `d → k`, `! → ошибка`.

3. **Результат в файле**:
   ```
   Olssv Dvysk!
   ```

---

### **Особенности реализации**
- **Циклический буфер**: Чтение данных блоками по 10 байт.
- **Эффективное использование регистров**: `r14` (флаг пробелов), `r15` (индекс записи).
- **Защита от переполнения**: Проверка размеров `buffer` и `buffer2`.
- **Кроссплатформенность**: Использует системные вызовы Linux (не совместимо с Windows).