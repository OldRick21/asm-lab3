# Документация к ассемблерной программе Цезаря

## Секция `.data`

### Буферы ввода/вывода
```asm
buffer times 255 db 0
b_size equ $ - buffer
buffer2 times 255 db 0
b2_size equ $ - buffer2
```
- **Назначение**: 
  - `buffer` - хранение исходных данных
  - `buffer2` - хранение обработанных данных после фильтрации пробелов
- **Детали**:
  - Оба буфера имеют фиксированный размер 255 байт
  - `b_size` и `b2_size` вычисляются автоматически через разность адресов

### Конфигурационные параметры
```asm
filename db "output.txt", 0
offset db 33
```
- **filename**: 
  - Имя выходного файла с нуль-терминатором
  - Формат: ASCIIZ-строка
- **offset**: 
  - Смещение для шифра Цезаря (фактически 7 после нормализации)
  - Автоматически приводится к диапазону 0-25

## Секция `.text`

### Инициализация программы
```asm
global _start
_start:
    mov r14, 2
    jmp sys_read
```
- **r14**: Регистр состояния:
  - 0: обычный символ
  - 1: пробел
  - 2: начало строки
- **Логика**: Немедленный переход к чтению данных

### Подсистема чтения
```asm
sys_read:
    mov rax, 0
    mov rdi, 0
    mov rsi, buffer
    mov rdx, b_size
    syscall
```
- **Параметры**:
  - Чтение из stdin (fd=0)
  - Максимальный размер: 255 байт
- **Обработка**:
  - Сохранение длины ввода в r9
  - Проверка на EOF (rax=0)
  - Защита от переполнения через проверку rax >= b_size

### Подготовка к шифрованию
```asm
    movzx rax, byte [offset]
    xor rdx, rdx
    mov rbx, 26
    div rbx
    mov rax, rdx
```
- **Нормализация смещения**:
  - Приведение значения к диапазону 0-25 через деление по модулю
  - Пример: 33 → 33 mod 26 = 7

### Алгоритм шифрования
```asm
caesar_cipher_start:
    cmp byte [buffer + r10], 0x0A
    je skip_space
    cmp byte [buffer + r10], 0x20
    je caesar_cipher_end
```
- **Особенности**:
  - Пропуск символа новой строки (0x0A)
  - Немедленная обработка пробелов (0x20)

#### Обработка регистров
```asm
upper:
    add r12b, al
    cmp r12b, 0x5A
    jg upper_overflow

lower:
    add r12, rax
    cmp r12, 0x7A
    jg lower_overflow
```
- **Логика**:
  - Верхний регистр (A-Z): 0x41-0x5A
  - Нижний регистр (a-z): 0x61-0x7A
  - Корректировка переполнения через циклический сдвиг

#### Примеры преобразований
- **Верхний регистр**: 
  - 'Z' (0x5A) + 7 → 0x61 ('a') → коррекция до 'G' (0x47)
- **Нижний регистр**: 
  - 'z' (0x7A) + 7 → 0x81 → коррекция до 'g' (0x67)

### Фильтрация пробелов
```asm
skip_space:
    mov r15, 0
    mov r10, 0
```
- **Алгоритм**:
  1. Пропуск ведущих пробелов (состояние r14=2)
  2. Замена последовательных пробелов на один
  3. Сохранение результата в buffer2
- **Особенности**:
  - Сохранение перевода строки (0x0A)
  - Ограничение на размер buffer2 через rbx

### Запись в файл
```asm
sys_file_write:
    mov rax, 2
    mov rdi, filename
    mov rsi, 0x441
    mov rdx, 0755o
    syscall
```
- **Параметры открытия**:
  - O_WRONLY|O_CREAT|O_APPEND (0x441)
  - Права доступа: rwxr-xr-x (0755)
- **Особенности**:
  - Дозапись в конец файла
  - Автоматическое создание при отсутствии

### Завершение работы
```asm
err:
    mov rax, 60
    mov rdi, 1
    syscall

_end:
    mov rax, 60
    mov rdi, 0
    syscall
```
- **Коды возврата**:
  - 1: Ошибка (некорректный символ или переполнение)
  - 0: Успешное завершение

## Особенности реализации
1. **Циклическое смещение**: Корректная обработка краев алфавита
2. **Оптимизация пробелов**: Гарантия единичного пробела между словами
3. **Состояние автомата**: Трехрежимная работа (старт строки/пробел/символ)
4. **Безопасность**: Проверка границ буферов при операциях записи
5. **Кросс-платформенность**: Использование Linux-специфичных системных вызовов
