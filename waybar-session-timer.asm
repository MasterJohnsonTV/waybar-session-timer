; waybar-session-timer.asm
; x86-64 Linux — counts up from 00:00:00 since process start, JSON output
;
; Build:
;   nasm -f elf64 waybar-session-timer.asm -o waybar-session-timer.o
;   ld waybar-session-timer.o -o waybar-session-timer
;
; Waybar config:
;   "custom/session-timer": { "exec": "/path/to/waybar-session-timer", "interval": 0, "return-type": "json" }
;
; Output per tick (20 bytes):
;   {"text":"HH:MM:SS"}\n
;
; fmt layout (20 bytes):
;   [0..8]   {"text":"   — 9 bytes
;   [9..10]  HH
;   [11]     ':'
;   [12..13] MM
;   [14]     ':'
;   [15..16] SS
;   [17..19] "}\n        — 3 bytes

section .bss
    start_sec resq 1

section .data

fmt:
    db '{"text":"'             ; 9 bytes  [0..8]
    db '0', '0', ':'          ; HH:      [9..11]
    db '0', '0', ':'          ; MM:      [12..14]
    db '0', '0'               ; SS       [15..16]
    db '"}'                   ;          [17..18]
    db 0x0A                   ; \n       [19]
fmt_len equ $ - fmt           ; 20

ts:
    dq 1                      ; nanosleep tv_sec
    dq 0                      ; nanosleep tv_nsec

%macro encode_pair 2
    xor  rdx, rdx
    mov  rcx, 10
    div  rcx
    add  al, '0'
    add  dl, '0'
    mov  byte [rel fmt + %1], al
    mov  byte [rel fmt + %2], dl
%endmacro

section .text
    global _start

_start:
    ; record start time (CLOCK_MONOTONIC = 1)
    sub  rsp, 16
    mov  eax, 228
    mov  edi, 1
    mov  rsi, rsp
    syscall
    mov  rax, [rsp]
    add  rsp, 16
    mov  [rel start_sec], rax

.loop:
    ; get current monotonic time
    sub  rsp, 16
    mov  eax, 228
    mov  edi, 1
    mov  rsi, rsp
    syscall
    mov  rax, [rsp]
    add  rsp, 16

    ; elapsed seconds
    sub  rax, [rel start_sec]

    ; HH
    xor  rdx, rdx
    mov  rcx, 3600
    div  rcx
    mov  r8, rdx
    encode_pair 9, 10

    ; MM
    mov  rax, r8
    xor  rdx, rdx
    mov  rcx, 60
    div  rcx
    mov  r9, rdx
    encode_pair 12, 13

    ; SS
    mov  rax, r9
    encode_pair 15, 16

    ; write(1, fmt, 20)
    mov  eax, 1
    mov  edi, 1
    lea  rsi, [rel fmt]
    mov  edx, fmt_len
    syscall

    ; nanosleep(1s)
    mov  eax, 35
    lea  rdi, [rel ts]
    xor  esi, esi
    syscall

    jmp  .loop
